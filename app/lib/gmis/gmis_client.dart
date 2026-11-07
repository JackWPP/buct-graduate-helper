import 'dart:convert';

import '../auth/auth_gateway.dart';
import '../config/app_config.dart';
import 'gmis_crypto.dart';
import 'gmis_exception.dart';
import 'gmis_transport.dart';

enum CaptchaKind {
  login('stucode'),
  selection('xkyzm');

  const CaptchaKind(this.code);
  final String code;
}

/// GMIS 登录和 JSON 请求客户端。一个学生账号对应一个实例。
class GmisClient implements AuthGateway {
  GmisClient({required this.transport, String baseUrl = AppConfig.baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final GmisTransport transport;
  final String _baseUrl;
  final Map<String, String> _cookies = {};

  String? _pendingPublicKey;

  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  /// GET /home/stulogin，并记住本次登录页的 #pubkey。
  Future<String> fetchLoginPage() async {
    _cookies.clear();
    _pendingPublicKey = null;
    final response = await _send(
      const GmisRequest(
        method: 'GET',
        path: '/home/stulogin',
        followRedirects: true,
        headers: {'Accept': 'text/html,application/xhtml+xml'},
      ),
    );
    _pendingPublicKey = extractPublicKey(response.body);
    return response.body;
  }

  @override
  Future<CaptchaChallenge> fetchCaptcha() async {
    // 真实登录页每次都要重新取公钥；验证码和公钥必须来自同一次登录页。
    await fetchLoginPage();
    final response = await _send(
      GmisRequest(
        method: 'GET',
        path: '/home/verificationcode',
        query: {
          'codetype': CaptchaKind.login.code,
          't': '${DateTime.now().millisecondsSinceEpoch}',
        },
        asBytes: true,
      ),
    );
    final bytes = response.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const GmisApiException('验证码图片为空');
    }
    return CaptchaChallenge(imageBytes: bytes);
  }

  @override
  Future<AuthSession> login({
    required String userId,
    required String password,
    required String captcha,
  }) async {
    if (userId.trim().isEmpty || password.isEmpty) {
      throw const GmisAuthException('请填写学号和密码');
    }
    final pem =
        _pendingPublicKey ??
        await fetchLoginPage().then((_) {
          return _pendingPublicKey;
        });
    if (pem == null || pem.isEmpty) {
      throw const GmisAuthException('登录页公钥未就绪，请刷新验证码');
    }
    final payload = {
      'UserId': userId.trim(),
      'Password': encryptGmisPassword(pem, password),
      'VeriCode': captcha.trim(),
      'url': '',
      'city': '',
    };
    final response = await _send(
      GmisRequest(
        method: 'POST',
        path: '/home/stulogin_do',
        form: {'json': jsonEncode(payload)},
        followRedirects: true,
        headers: {'Accept': 'application/json, text/javascript, */*; q=0.01'},
      ),
    );
    final body = _decodeJson(response.body);
    if (body is! Map || '${body['jg']}' != '1') {
      final message = body is Map ? '${body['msg'] ?? ''}' : '';
      throw GmisAuthException(message.isEmpty ? '登录失败，请检查学号和密码' : message);
    }
    final url = '${body['url'] ?? 'student/default/index'}';
    await _send(
      GmisRequest(
        method: 'GET',
        path: url.startsWith('/') ? url : '/$url',
        followRedirects: true,
        headers: {'Accept': 'text/html,application/xhtml+xml'},
      ),
    );
    return AuthSession(
      userId: userId.trim(),
      cookies: Map<String, String>.from(_cookies),
      savedAt: DateTime.now(),
    );
  }

  @override
  Future<void> restore(AuthSession session) async {
    _cookies
      ..clear()
      ..addAll(session.cookies);
  }

  @override
  Future<void> logout() async {
    try {
      await _send(
        const GmisRequest(
          method: 'GET',
          path: '/home/logout',
          query: {'js': 'xs'},
          followRedirects: true,
        ),
      );
    } catch (_) {
      // 退出登录时网络失败也要清掉本地状态。
    } finally {
      _cookies.clear();
      _pendingPublicKey = null;
    }
  }

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final response = await _send(
      GmisRequest(method: 'GET', path: path, query: query),
    );
    return _decodeJson(response.body);
  }

  Future<dynamic> postJson(String path, {Map<String, String>? form}) async {
    final response = await _send(
      GmisRequest(method: 'POST', path: path, form: form ?? const {}),
    );
    return _decodeJson(response.body);
  }

  Future<GmisResponse> _send(GmisRequest request) async {
    final headers = <String, String>{
      'Referer': '$_baseUrl/home/stulogin',
      ...request.headers,
    };
    if (_cookies.isNotEmpty) {
      headers['Cookie'] = _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }
    final response = await transport.send(
      GmisRequest(
        method: request.method,
        path: request.path,
        query: request.query,
        form: request.form,
        headers: headers,
        asBytes: request.asBytes,
        followRedirects: request.followRedirects,
      ),
    );
    _absorbCookies(response);
    _checkStatus(response, request.path);
    return response;
  }

  void _absorbCookies(GmisResponse response) {
    final setCookies = response.headers['set-cookie'] ?? const <String>[];
    for (final raw in setCookies) {
      final first = raw.split(';').first.trim();
      final index = first.indexOf('=');
      if (index <= 0) continue;
      final name = first.substring(0, index).trim();
      final value = first.substring(index + 1).trim();
      if (name.isEmpty) continue;
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  void _checkStatus(GmisResponse response, String path) {
    final status = response.statusCode;
    if (status >= 300 && status < 400) {
      final location = response.header('location') ?? '';
      if (location.contains('stulogin')) {
        throw const GmisSessionExpired();
      }
      throw GmisApiException('接口发生跳转: $path -> $location');
    }
    if (status >= 500 && response.body.contains('block incorrect')) {
      throw const GmisAuthException('RSA 公钥与服务器不匹配，请刷新验证码重试');
    }
    if (status >= 400) {
      final preview = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      throw GmisApiException(
        'HTTP $status $path: $preview',
        statusCode: status,
      );
    }
  }

  dynamic _decodeJson(String body) {
    if (body.trim().isEmpty) return const <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      final preview = body.length > 300 ? body.substring(0, 300) : body;
      throw GmisFormatException('返回不是 JSON: $preview');
    }
  }
}
