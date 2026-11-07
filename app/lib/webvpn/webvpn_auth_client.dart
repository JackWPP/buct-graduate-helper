import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/api.dart';

import '../gmis/gmis_exception.dart';
import '../gmis/gmis_transport.dart';
import 'webvpn_session.dart';
import 'webvpn_url.dart';

/// 学校统一身份认证的网页登录协议。
///
/// 只处理学号、密码换取 CAS ticket，再用 ticket 换网页版 VPN Cookie；
/// 密码不会写入任何存储，也不会出现在日志里。
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

  Future<WebVpnSession> login({
    required String userId,
    required String password,
  }) async {
    final id = userId.trim();
    if (id.isEmpty || password.isEmpty) {
      throw const GmisAuthException('请填写学号和密码');
    }
    final ssoCookies = <String, String>{};
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
    _absorbCookies(ssoCookies, page);
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
          'Cookie': _cookieHeader(ssoCookies),
        },
        followRedirects: false,
      ),
    );
    _absorbCookies(ssoCookies, response);

    final location = response.header('location');
    if (response.statusCode >= 300 &&
        response.statusCode < 400 &&
        location != null &&
        location.isNotEmpty) {
      return _exchangeTicket(location);
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

  static String? _field(String html, String id) {
    final match = RegExp(
      'id=["\\\']$id["\\\'][^>]*>([^<]*)<',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1)?.trim();
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
