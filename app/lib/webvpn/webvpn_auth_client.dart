import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/digests/md5.dart';

import '../gmis/gmis_exception.dart';
import '../gmis/gmis_transport.dart';
import 'webvpn_credential.dart';
import 'webvpn_exception.dart';
import 'webvpn_session.dart';
import 'webvpn_url.dart';
import 'webvpn_validator.dart';

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

/// 短信发送成功后的重发间隔，用于页面倒计时。
class SmsCodeSent {
  const SmsCodeSent({required this.intervalSeconds});

  final int intervalSeconds;
}

class _ChainResult {
  const _ChainResult({
    required this.uri,
    required this.response,
    required this.tickets,
  });

  final Uri uri;
  final GmisResponse response;
  final List<(String, String)> tickets;
}

/// 学校统一身份认证的网页登录协议。
///
/// 密码只用于本次登录，不会写入存储或日志。流程：
/// 1. GET 登录页拿 croypto / flowkey；
/// 2. AES-128-ECB 加密密码并 POST；
/// 3. 若返回短信二次认证页，发送短信并再次提交验证码；
/// 4. 收集重定向链上的 ticket 候选并逐个校验，只有门户认可的才返回会话。
class WebVpnAuthClient {
  WebVpnAuthClient({
    GmisTransport? ssoTransport,
    GmisTransport? webVpnTransport,
    WebVpnValidator? validator,
  }) : _ssoTransport =
           ssoTransport ??
           DioGmisTransport(baseUrl: ssoBase),
       _webVpnTransport =
           webVpnTransport ??
           DioGmisTransport(baseUrl: 'https://${WebVpnUrls.host}'),
       _validator = validator ?? HttpWebVpnValidator();

  static const String ssoBase = 'https://sidportal.buct.edu.cn';
  static const String service = 'https://w.buct.edu.cn/login?cas_login=true';

  final GmisTransport _ssoTransport;
  final GmisTransport _webVpnTransport;
  final WebVpnValidator _validator;

  /// Cookie 按 host 隔离：SSO Cookie 不发给门户，门户 Cookie 不发给 SSO。
  final Map<String, Map<String, String>> _cookiesByHost = {};
  WebVpnSmsChallenge? _pendingSms;

  Future<WebVpnLoginResult> login({
    required String userId,
    required String password,
  }) async {
    final id = userId.trim();
    if (id.isEmpty || password.isEmpty) {
      throw const GmisAuthException('请填写学号和密码');
    }
    _cookiesByHost.clear();
    _pendingSms = null;

    final loginUri = Uri.parse(
      '$ssoBase/login',
    ).replace(queryParameters: {'service': service});
    final page = await _follow(
      loginUri,
      headers: _htmlHeaders(referer: '$ssoBase/login'),
    );
    final existing = await _trySession(page.tickets);
    if (existing != null) return WebVpnLoginResult.session(existing);

    if (page.response.statusCode != 200) {
      throw GmisApiException(
        '统一身份认证页面加载失败（HTTP ${page.response.statusCode}）',
        statusCode: page.response.statusCode,
      );
    }
    final croypto = _field(page.response.body, 'login-croypto');
    final flowKey = _field(page.response.body, 'login-page-flowkey');
    if (croypto == null || flowKey == null) {
      throw const GmisFormatException('统一身份认证页面结构已变化，请稍后重试');
    }

    final postUri = Uri.parse(
      '$ssoBase/login',
    ).replace(queryParameters: {'service': service});
    final response = await _follow(
      postUri,
      method: 'POST',
      form: {
        'type': 'UsernamePassword',
        '_eventId': 'submit',
        'geolocation': '',
        'execution': flowKey,
        'croypto': croypto,
        'username': id,
        'password': encryptSsoPassword(croypto, password),
      },
      headers: _htmlHeaders(referer: '$ssoBase/login'),
    );
    final session = await _trySession(response.tickets);
    if (session != null) return WebVpnLoginResult.session(session);
    if (response.tickets.isNotEmpty) {
      throw const WebVpnAuthException(
        '统一身份认证完成，但网页版 VPN 没有生效，请重试或使用网页版登录',
      );
    }

    final body = response.response.body;
    final loginType = _field(body, 'current-login-type');
    final second = _field(body, 'sso-second');
    if (loginType == 'smsLogin' || second == 'true') {
      final phone = _field(body, 'phone-number') ?? '';
      final smsUserId = _field(body, 'second-auth-user-id') ?? id;
      final execution = _field(body, 'login-page-flowkey') ?? '';
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

    final code =
        _field(body, 'login-error-code') ?? _field(body, 'login-error-msg');
    if (code != null && code.isNotEmpty) {
      throw GmisAuthException(switch (code) {
        '1030028' => '学号或密码不正确',
        _ => '统一身份认证失败（$code）',
      });
    }
    if (response.response.statusCode == 401) {
      throw const GmisAuthException('学号或密码不正确');
    }
    throw GmisApiException(
      '统一身份认证没有返回跳转（HTTP ${response.response.statusCode}）',
      statusCode: response.response.statusCode,
    );
  }

  /// 向当前短信挑战的手机号发送验证码，返回允许重发的间隔秒数。
  Future<SmsCodeSent> sendSmsCode() async {
    final challenge = _requireSmsChallenge();
    final uri = Uri.parse(
      '$ssoBase/api/protected/sms/publicNoToken/sendSmsCode',
    );
    final response = await _postJson(uri, {
      'phone': challenge.phoneNumber,
      'businessNo': '0008',
    });
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
    final payload = data['data'];
    final interval = payload is Map
        ? _intOf(payload['sendInterval']) ?? 120
        : 120;
    return SmsCodeSent(intervalSeconds: interval <= 0 ? 120 : interval);
  }

  /// 提交短信验证码，成功后返回 WebVPN 会话。
  Future<WebVpnSession> verifySmsCode(String code) async {
    final challenge = _requireSmsChallenge();
    final token = code.trim();
    if (token.isEmpty) {
      throw const GmisAuthException('请输入短信验证码');
    }
    final check = await _postJson(
      Uri.parse('$ssoBase/api/protected/sms/checkToken'),
      {
        'phone': challenge.phoneNumber,
        'token': token,
        'delete': false,
        'trustDevice': false,
      },
    );
    final checkData = _decodeMap(check.body);
    final checkCode = _intOf(checkData['code']);
    if (check.statusCode != 200 ||
        (checkCode != null && checkCode != 200)) {
      throw const GmisAuthException('短信验证码不正确');
    }

    final response = await _follow(
      Uri.parse('$ssoBase/login').replace(queryParameters: {'service': service}),
      method: 'POST',
      form: {
        'username': challenge.userId,
        'password': token,
        'type': 'smsLogin',
        '_eventId': 'submit',
        'geolocation': '',
        'execution': challenge.execution,
      },
      headers: _htmlHeaders(referer: '$ssoBase/login'),
    );
    final session = await _trySession(response.tickets);
    if (session != null) {
      _pendingSms = null;
      return session;
    }
    if (response.tickets.isNotEmpty) {
      throw const WebVpnAuthException(
        '短信验证完成，但网页版 VPN 没有生效，请重试或使用网页版登录',
      );
    }
    final errorCode =
        _field(response.response.body, 'login-error-msg') ??
        _field(response.response.body, 'login-error-code');
    if (errorCode != null && errorCode.isNotEmpty) {
      throw const GmisAuthException('短信验证码不正确');
    }
    if (response.response.body.contains('验证码有误')) {
      throw const GmisAuthException('短信验证码不正确');
    }
    throw GmisApiException(
      '短信验证没有返回跳转（HTTP ${response.response.statusCode}）',
      statusCode: response.response.statusCode,
    );
  }

  /// 依次校验重定向链上的 ticket 候选；只有门户认可的才返回。
  Future<WebVpnSession?> _trySession(List<(String, String)> candidates) async {
    if (candidates.isEmpty) return null;
    final seen = <String>{};
    var sawOffline = false;
    for (final candidate in candidates.reversed) {
      final key = '${candidate.$1}=${candidate.$2}';
      if (!seen.add(key)) continue;
      final now = DateTime.now();
      final credential = WebVpnCredential(
        ticketName: candidate.$1,
        ticketValue: candidate.$2,
        issuedAt: now,
        lastUsedAt: now,
        source: WebVpnCredential.sourceNativeSso,
      );
      final validation = await _validator.validate(credential);
      switch (validation.state) {
        case WebVpnState.valid:
          return WebVpnSession(
            credential: credential.copyWith(lastValidatedAt: now),
          );
        case WebVpnState.expired:
          continue;
        case WebVpnState.offline:
        case WebVpnState.unknown:
          sawOffline = true;
      }
    }
    if (sawOffline) {
      throw const GmisNetworkException('无法验证网页版 VPN 会话，请检查网络后重试');
    }
    return null;
  }

  /// 手动跟随重定向，支持跨 host，并在每一跳吸收 Set-Cookie。
  Future<_ChainResult> _follow(
    Uri start, {
    String method = 'GET',
    Map<String, String>? form,
    Map<String, dynamic>? json,
    Map<String, String>? headers,
  }) async {
    var uri = start;
    var currentMethod = method;
    var currentForm = form;
    var currentJson = json;
    final tickets = <(String, String)>[];
    for (var hop = 0; hop < 8; hop++) {
      _requireAllowedHost(uri);
      final response = await _transportFor(uri).send(
        GmisRequest(
          method: currentMethod,
          path: uri.path,
          absoluteUri: uri,
          form: currentForm,
          json: currentJson,
          headers: {
            ...?headers,
            if (_cookieHeaderFor(uri).isNotEmpty)
              'Cookie': _cookieHeaderFor(uri),
          },
          followRedirects: false,
        ),
      );
      tickets.addAll(_absorbCookies(uri, response));
      final status = response.statusCode;
      if (status < 300 || status >= 400) {
        return _ChainResult(uri: uri, response: response, tickets: tickets);
      }
      final raw = response.header('location');
      if (raw == null || raw.isEmpty) {
        return _ChainResult(uri: uri, response: response, tickets: tickets);
      }
      uri = uri.resolve(raw);
      _requireAllowedHost(uri);
      // 浏览器在 302/303/307 后都重新发 GET；POST 表单不再重复提交。
      currentMethod = 'GET';
      currentForm = null;
      currentJson = null;
    }
    throw const GmisFormatException('统一身份认证跳转次数过多');
  }

  GmisTransport _transportFor(Uri uri) {
    if (uri.host == WebVpnUrls.host) return _webVpnTransport;
    if (uri.host == WebVpnUrls.sidPortalHost) return _ssoTransport;
    throw GmisFormatException('统一身份认证跳转到了未知地址: ${uri.host}');
  }

  void _requireAllowedHost(Uri uri) {
    if (uri.host == WebVpnUrls.host || uri.host == WebVpnUrls.sidPortalHost) {
      return;
    }
    throw GmisFormatException('统一身份认证跳转到了未知地址: ${uri.host}');
  }

  Future<GmisResponse> _postJson(Uri uri, Map<String, dynamic> data) async {
    final response = await _transportFor(uri).send(
      GmisRequest(
        method: 'POST',
        path: uri.path,
        absoluteUri: uri,
        json: data,
        headers: _jsonHeaders(uri),
        followRedirects: false,
      ),
    );
    _absorbCookies(uri, response);
    return response;
  }

  List<(String, String)> _absorbCookies(Uri uri, GmisResponse response) {
    final tickets = <(String, String)>[];
    final jar = _cookiesByHost.putIfAbsent(uri.host, () => <String, String>{});
    for (final raw in response.headers['set-cookie'] ?? const <String>[]) {
      final first = raw.split(';').first.trim();
      final index = first.indexOf('=');
      if (index <= 0) continue;
      final name = first.substring(0, index).trim();
      final value = first.substring(index + 1).trim();
      if (name.isEmpty) continue;
      if (name.startsWith(webVpnTicketPrefix) && value.isNotEmpty) {
        tickets.add((name, value));
      }
      if (value.isEmpty) {
        jar.remove(name);
      } else {
        jar[name] = value;
      }
    }
    return tickets;
  }

  String _cookieHeaderFor(Uri uri) {
    final jar = _cookiesByHost[uri.host];
    if (jar == null || jar.isEmpty) return '';
    return jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Map<String, String> _htmlHeaders({required String referer}) => {
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Referer': referer,
  };

  Map<String, String> _jsonHeaders(Uri uri) {
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
      if (_cookieHeaderFor(uri).isNotEmpty)
        'Cookie': _cookieHeaderFor(uri),
    };
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
}
