import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/digests/md5.dart';

import '../gmis/gmis_exception.dart';
import '../gmis/gmis_transport.dart';
import 'webvpn_session.dart';
import 'webvpn_url.dart';

/// 统一身份认证返回的短信二次认证挑战。
class WebVpnSmsChallenge {
  const WebVpnSmsChallenge({
    required this.userId,
    required this.phoneNumber,
    required this.execution,
  });

  final String userId;
  final String phoneNumber;
  final String execution;

  String get maskedPhone {
    if (phoneNumber.length <= 7) return phoneNumber;
    return '${phoneNumber.substring(0, 3)}****${phoneNumber.substring(phoneNumber.length - 4)}';
  }
}

/// 一次统一身份认证的中间结果：要么拿到 WebVPN 会话，要么需要短信验证码。
class WebVpnLoginResult {
  const WebVpnLoginResult.session(this.session) : challenge = null;
  const WebVpnLoginResult.smsRequired(this.challenge) : session = null;

  final WebVpnSession? session;
  final WebVpnSmsChallenge? challenge;

  bool get needsSms => challenge != null;
}

/// 学校统一身份认证的网页登录协议。
///
/// 密码只用于本次登录，不会写入存储或日志。流程：
/// 1. GET 登录页拿 croypto / flowkey；
/// 2. AES-128-ECB 加密密码并 POST；
/// 3. 若返回短信二次认证页，发送短信并再次提交验证码；
/// 4. 用 CAS ticket 换取 WebVPN Cookie。
class WebVpnAuthClient {
  WebVpnAuthClient({
    GmisTransport? ssoTransport,
    GmisTransport? webVpnTransport,
  }) : _ssoTransport =
           ssoTransport ??
           DioGmisTransport(baseUrl: 'https://sidportal.buct.edu.cn'),
       _webVpnTransport =
           webVpnTransport ??
           DioGmisTransport(baseUrl: 'https://${WebVpnUrls.host}');

  static const String ssoBase = 'https://sidportal.buct.edu.cn';
  static const String service = 'https://w.buct.edu.cn/login?cas_login=true';

  final GmisTransport _ssoTransport;
  final GmisTransport _webVpnTransport;
  final Map<String, String> _ssoCookies = {};
  WebVpnSmsChallenge? _pendingSms;

  Future<WebVpnLoginResult> login({
    required String userId,
    required String password,
  }) async {
    final id = userId.trim();
    if (id.isEmpty || password.isEmpty) {
      throw const GmisAuthException('请填写学号和密码');
    }
    _ssoCookies.clear();
    _pendingSms = null;
    final page = await _ssoTransport.send(
      GmisRequest(
        method: 'GET',
        path: '/login',
        query: const {'service': service},
        headers: const {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$ssoBase/login',
        },
        followRedirects: true,
      ),
    );
    _absorbCookies(_ssoCookies, page);
    if (page.statusCode != 200) {
      throw GmisApiException(
        '统一身份认证页面加载失败（HTTP ${page.statusCode}）',
        statusCode: page.statusCode,
      );
    }
    final croypto = _field(page.body, 'login-croypto');
    final flowKey = _field(page.body, 'login-page-flowkey');
    if (croypto == null || flowKey == null) {
      throw const GmisFormatException('统一身份认证页面结构已变化，请稍后重试');
    }

    final response = await _ssoTransport.send(
      GmisRequest(
        method: 'POST',
        path: '/login',
        query: const {'service': service},
        form: {
          'type': 'UsernamePassword',
          '_eventId': 'submit',
          'geolocation': '',
          'execution': flowKey,
          'croypto': croypto,
          'username': id,
          'password': encryptSsoPassword(croypto, password),
        },
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$ssoBase/login?service=${Uri.encodeComponent(service)}',
          'Cookie': _cookieHeader(_ssoCookies),
        },
        followRedirects: false,
      ),
    );
    _absorbCookies(_ssoCookies, response);

    final location = response.header('location');
    if (response.statusCode >= 300 &&
        response.statusCode < 400 &&
        location != null &&
        location.isNotEmpty) {
      return WebVpnLoginResult.session(await _exchangeTicket(location));
    }

    final loginType = _field(response.body, 'current-login-type');
    final second = _field(response.body, 'sso-second');
    if (loginType == 'smsLogin' || second == 'true') {
      final phone = _field(response.body, 'phone-number') ?? '';
      final smsUserId = _field(response.body, 'second-auth-user-id') ?? id;
      final execution = _field(response.body, 'login-page-flowkey') ?? '';
      if (phone.isEmpty || execution.isEmpty) {
        throw const GmisFormatException('短信验证页面结构已变化，请稍后再试');
      }
      final challenge = WebVpnSmsChallenge(
        userId: smsUserId,
        phoneNumber: phone,
        execution: execution,
      );
      _pendingSms = challenge;
      return WebVpnLoginResult.smsRequired(challenge);
    }

    final code = _field(response.body, 'login-error-msg');
    if (code != null && code.isNotEmpty) {
      throw GmisAuthException(switch (code) {
        '1030028' => '学号或密码不正确',
        _ => '统一身份认证失败（$code）',
      });
    }
    if (response.statusCode == 401) {
      throw const GmisAuthException('学号或密码不正确');
    }
    throw GmisApiException(
      '统一身份认证没有返回跳转（HTTP ${response.statusCode}）',
      statusCode: response.statusCode,
    );
  }

  /// 向当前短信挑战的手机号发送验证码。
  Future<void> sendSmsCode() async {
    final challenge = _requireSmsChallenge();
    final response = await _ssoTransport.send(
      GmisRequest(
        method: 'POST',
        path: '/api/protected/sms/publicNoToken/sendSmsCode',
        json: {'phone': challenge.phoneNumber, 'businessNo': '0008'},
        headers: _jsonHeaders(),
        followRedirects: false,
      ),
    );
    _absorbCookies(_ssoCookies, response);
    final data = _decodeMap(response.body);
    final code = _intOf(data['code']);
    if (response.statusCode != 200 || (code != null && code != 200)) {
      final message = data['message']?.toString();
      if (code == 412) {
        throw GmisAuthException(
          message?.isNotEmpty == true ? message! : '验证码还在有效期内，请稍后再试',
        );
      }
      throw GmisApiException(
        message?.isNotEmpty == true
            ? message!
            : '验证码发送失败（HTTP ${response.statusCode}）',
        statusCode: response.statusCode,
      );
    }
  }

  /// 提交短信验证码，成功后返回 WebVPN 会话。
  Future<WebVpnSession> verifySmsCode(String code) async {
    final challenge = _requireSmsChallenge();
    final token = code.trim();
    if (token.isEmpty) {
      throw const GmisAuthException('请输入短信验证码');
    }
    final check = await _ssoTransport.send(
      GmisRequest(
        method: 'POST',
        path: '/api/protected/sms/checkToken',
        json: {
          'phone': challenge.phoneNumber,
          'token': token,
          'delete': false,
          'trustDevice': false,
        },
        headers: _jsonHeaders(),
        followRedirects: false,
      ),
    );
    _absorbCookies(_ssoCookies, check);
    final checkData = _decodeMap(check.body);
    final checkCode = _intOf(checkData['code']);
    if (check.statusCode != 200 || (checkCode != null && checkCode != 200)) {
      throw const GmisAuthException('短信验证码不正确');
    }

    final response = await _ssoTransport.send(
      GmisRequest(
        method: 'POST',
        path: '/login',
        query: const {'service': service},
        form: {
          'username': challenge.userId,
          'password': token,
          'type': 'smsLogin',
          '_eventId': 'submit',
          'geolocation': '',
          'execution': challenge.execution,
        },
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '$ssoBase/login',
          'Cookie': _cookieHeader(_ssoCookies),
        },
        followRedirects: false,
      ),
    );
    _absorbCookies(_ssoCookies, response);
    final location = response.header('location');
    if (response.statusCode >= 300 &&
        response.statusCode < 400 &&
        location != null &&
        location.isNotEmpty) {
      _pendingSms = null;
      return _exchangeTicket(location);
    }
    final errorCode =
        _field(response.body, 'login-error-msg') ??
        _field(response.body, 'login-error-code');
    if (errorCode != null && errorCode.isNotEmpty) {
      throw const GmisAuthException('短信验证码不正确');
    }
    if (response.body.contains('验证码有误')) {
      throw const GmisAuthException('短信验证码不正确');
    }
    throw GmisApiException(
      '短信验证没有返回跳转（HTTP ${response.statusCode}）',
      statusCode: response.statusCode,
    );
  }

  Future<WebVpnSession> _exchangeTicket(String location) async {
    var uri = Uri.parse(location);
    if (!uri.hasScheme) {
      uri = Uri.parse('https://${WebVpnUrls.host}').resolveUri(uri);
    }
    final cookies = <String, String>{};
    for (var hop = 0; hop < 6; hop++) {
      final response = await _webVpnTransport.send(
        GmisRequest(
          method: 'GET',
          path: uri.path.isEmpty ? '/' : uri.path,
          query: uri.queryParameters.isEmpty ? null : uri.queryParameters,
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            if (cookies.isNotEmpty) 'Cookie': _cookieHeader(cookies),
          },
          followRedirects: false,
        ),
      );
      _absorbCookies(cookies, response);
      final next = response.header('location');
      if (response.statusCode >= 300 &&
          response.statusCode < 400 &&
          next != null &&
          next.isNotEmpty) {
        var target = Uri.parse(next);
        if (!target.hasScheme) {
          target = uri.resolveUri(target);
        }
        uri = target;
        continue;
      }
      break;
    }
    final session = WebVpnSession(
      baseUrl: WebVpnUrls.gmisBase,
      cookies: cookies,
    );
    if (!session.hasTicket) {
      throw const GmisAuthException('统一身份认证成功，但没有拿到网页版 VPN 凭证');
    }
    return session;
  }

  WebVpnSmsChallenge _requireSmsChallenge() {
    final challenge = _pendingSms;
    if (challenge == null) {
      throw const GmisAuthException('请先完成学号和密码验证');
    }
    return challenge;
  }

  static String encryptSsoPassword(String croypto, String password) {
    final key = base64Decode(croypto);
    final input = utf8.encode(password);
    final pad = 16 - (input.length % 16);
    final padded = Uint8List(input.length + pad)
      ..setRange(0, input.length, input)
      ..fillRange(input.length, input.length + pad, pad);
    final engine = AESEngine()
      ..init(true, KeyParameter(Uint8List.fromList(key)));
    final output = Uint8List(padded.length);
    for (var offset = 0; offset < padded.length; offset += 16) {
      engine.processBlock(padded, offset, output, offset);
    }
    return base64Encode(output);
  }

  Map<String, String> _jsonHeaders() {
    final key = _randomKey();
    final encoded = base64Encode(utf8.encode(key));
    final half = encoded.length ~/ 2;
    final value =
        encoded.substring(0, half) + encoded + encoded.substring(half);
    final digest = MD5Digest().process(utf8.encode(value));
    final md5 = digest
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return {
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': 'application/json',
      'Referer': '$ssoBase/login',
      'sid-language': 'zh_CN',
      'Csrf-Key': key,
      'Csrf-Value': md5,
      if (_ssoCookies.isNotEmpty) 'Cookie': _cookieHeader(_ssoCookies),
    };
  }

  static String _randomKey() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static String? _field(String html, String id) {
    final match = RegExp(
      'id=["\\\']$id["\\\'][^>]*>([^<]*)<',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1)?.trim();
  }

  static Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  static int? _intOf(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }

  static void _absorbCookies(
    Map<String, String> target,
    GmisResponse response,
  ) {
    final values = response.headers['set-cookie'] ?? const <String>[];
    for (final raw in values) {
      final first = raw.split(';').first.trim();
      final index = first.indexOf('=');
      if (index <= 0) continue;
      target[first.substring(0, index).trim()] = first
          .substring(index + 1)
          .trim();
    }
  }

  static String _cookieHeader(Map<String, String> cookies) =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
}
