import 'dart:convert';
import 'dart:typed_data';

import '../auth/auth_gateway.dart';
import '../config/app_config.dart';
import '../webvpn/webvpn_exception.dart';
import '../webvpn/webvpn_url.dart';
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
  GmisClient({
    required this.transport,
    String baseUrl = AppConfig.baseUrl,
    Map<String, String> initialCookies = const {},
    this.webVpnTicketHeader,
    this.onWebVpnTicket,
    this.viaWebVpn = false,
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _initialCookies = Map<String, String>.fromEntries(
         initialCookies.entries.where((entry) => !_isTicketName(entry.key)),
       ) {
    _cookies.addAll(_initialCookies);
  }

  final GmisTransport transport;
  final String _baseUrl;
  final Map<String, String> _initialCookies;
  final Map<String, String> _cookies = {};

  /// 每次请求现取 ticket，门户轮换后立刻生效；ticket 永不进入 [_cookies]。
  final String? Function()? webVpnTicketHeader;
  final void Function(String name, String? value)? onWebVpnTicket;

  /// 当前是否经网页版 VPN 访问；302 分类依赖这个标记。
  final bool viaWebVpn;

  String? _pendingPublicKey;

  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  /// GET /home/stulogin，并记住本次登录页的 #pubkey。
  Future<String> fetchLoginPage() async {
    _resetCookiesForLogin();
    _pendingPublicKey = null;
    final response = await _sendFollowing(
      const GmisRequest(
        method: 'GET',
        path: '/home/stulogin',
        headers: {'Accept': 'text/html,application/xhtml+xml'},
      ),
    );
    _pendingPublicKey = extractPublicKey(response.body);
    return response.body;
  }

  @override
  Future<CaptchaChallenge> fetchCaptcha() async {
    final bytes = await fetchCaptchaBytes(CaptchaKind.login);
    return CaptchaChallenge(imageBytes: bytes);
  }

  /// 取一张验证码图片。
  ///
  /// 登录验证码必须先重载登录页，公钥和图片必须来自同一次会话；
  /// 选课验证码（`xkyzm`）与登录验证码完全独立，直接取图即可。
  Future<Uint8List> fetchCaptchaBytes(CaptchaKind kind) async {
    if (kind == CaptchaKind.login) {
      await fetchLoginPage();
    }
    final response = await _send(
      GmisRequest(
        method: 'GET',
        path: '/home/verificationcode',
        query: {
          'codetype': kind.code,
          't': '${DateTime.now().millisecondsSinceEpoch}',
        },
        asBytes: true,
      ),
    );
    final bytes = response.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const GmisApiException('验证码图片为空');
    }
    return bytes;
  }

  /// 学术报告/劳动实践报名页的验证码。页面脚本引用的相对路径是
  /// `/student/yggl/VerificationCode`，旧版入口则用 `/Home/VerificationCode`；
  /// 两个路径在不同部署上可能只启用其中一个，按顺序回退。
  Future<Uint8List> fetchActivityCaptcha() async {
    final paths = <String>[
      '/student/yggl/VerificationCode',
      '/Home/VerificationCode',
      '/home/verificationcode',
    ];
    for (final path in paths) {
      try {
        final response = await _send(
          GmisRequest(
            method: 'GET',
            path: path,
            query: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
            headers: {'Referer': '$_baseUrl/student/yggl/xshdbm'},
            asBytes: true,
          ),
        );
        final bytes = response.bytes;
        if (bytes != null && _looksLikeImage(bytes)) return bytes;
      } on GmisApiException {
        // 换下一个兼容路径。
      }
    }
    throw const GmisApiException('活动报名验证码加载失败，请稍后重试');
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PNG / JPEG / GIF / WEBP 的常见文件头。
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return true;
    }
    return false;
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
        headers: {'Accept': 'application/json, text/javascript, */*; q=0.01'},
      ),
    );
    final body = _decodeJson(response.body);
    if (body is! Map || '${body['jg']}' != '1') {
      final message = body is Map ? '${body['msg'] ?? ''}' : '';
      throw GmisAuthException(message.isEmpty ? '登录失败，请检查学号和密码' : message);
    }
    final url = '${body['url'] ?? 'student/default/index'}';
    await _sendFollowing(
      GmisRequest(
        method: 'GET',
        path: url.startsWith('/') ? url : '/$url',
        headers: {'Accept': 'text/html,application/xhtml+xml'},
      ),
    );
    return AuthSession(
      userId: userId.trim(),
      cookies: Map<String, String>.from(_cookies),
      savedAt: DateTime.now(),
      baseUrl: _baseUrl == AppConfig.baseUrl ? null : _baseUrl,
    );
  }

  @override
  Future<void> restore(AuthSession session) async {
    _cookies
      ..clear()
      ..addAll(
        Map<String, String>.fromEntries(
          session.cookies.entries.where(
            (entry) => !_isTicketName(entry.key),
          ),
        ),
      );
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
      _resetCookiesForLogin();
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

  Future<GmisResponse> _send(
    GmisRequest request, {
    bool checkStatus = true,
  }) async {
    final headers = <String, String>{
      'Referer': '$_baseUrl/home/stulogin',
      ...request.headers,
    };
    final ticket = webVpnTicketHeader?.call();
    final cookieParts = <String>[
      if (ticket != null && ticket.isNotEmpty) ticket,
      ..._cookies.entries.map((entry) => '${entry.key}=${entry.value}'),
    ];
    if (cookieParts.isNotEmpty) headers['Cookie'] = cookieParts.join('; ');
    final response = await transport.send(
      GmisRequest(
        method: request.method,
        path: request.path,
        query: request.query,
        form: request.form,
        json: request.json,
        headers: headers,
        asBytes: request.asBytes,
        followRedirects: false,
        absoluteUri: request.absoluteUri,
      ),
    );
    _absorbCookies(response);
    if (checkStatus) {
      _checkStatus(response, request.absoluteUri?.path ?? request.path);
    }
    return response;
  }

  /// 手动跟随 302，逐跳分类门户登录和目标登录。
  ///
  /// 只用于必须拿到最终页面的 POST 之后的 GET 或登录页；普通 JSON 请求
  /// 由 [_checkStatus] 直接分流。
  Future<GmisResponse> _sendFollowing(GmisRequest request) async {
    final initialPath = request.path.startsWith('/')
        ? request.path.substring(1)
        : request.path;
    var uri =
        request.absoluteUri ?? Uri.parse('$_baseUrl/$initialPath');
    if (request.query != null) {
      uri = uri.replace(
        queryParameters: {...uri.queryParameters, ...request.query!},
      );
    }
    for (var hop = 0; hop < 6; hop++) {
      final response = await _send(
        GmisRequest(
          method: request.method,
          path: uri.path,
          headers: request.headers,
          asBytes: request.asBytes,
          followRedirects: false,
          absoluteUri: uri,
        ),
        checkStatus: false,
      );
      final status = response.statusCode;
      if (status < 300 || status >= 400) {
        _checkStatus(response, uri.path);
        return response;
      }
      final raw = response.header('location');
      if (raw == null || raw.isEmpty) return response;
      final next = _resolveRedirect(uri, raw);
      final kind = WebVpnUrls.classifyRedirect(next, viaWebVpn: viaWebVpn);
      if (kind == WebVpnRedirectKind.portalLogin) {
        throw const WebVpnSessionExpired();
      }
      if (kind == WebVpnRedirectKind.external) {
        throw const GmisApiException('接口跳转到了不受信任的地址');
      }
      uri = next;
    }
    throw const GmisApiException('登录跳转次数过多，请稍后重试');
  }

  /// WebVPN 代理下，目标站点的绝对路径要保留 `/https/<token>/` 前缀；
  /// 门户自己的 `/login` 和已经带前缀的 `/https/...` 原样解析。
  Uri _resolveRedirect(Uri current, String raw) {
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return current;
    if (parsed.hasScheme || raw.startsWith('//')) {
      return current.resolve(raw);
    }
    if (viaWebVpn &&
        (raw == '/login' ||
            raw.startsWith('/login?') ||
            raw.startsWith('/login/'))) {
      return Uri.parse('https://${WebVpnUrls.host}$raw');
    }
    if (viaWebVpn &&
        raw.startsWith('/') &&
        !raw.startsWith('/https/')) {
      return Uri.parse('$_baseUrl$raw');
    }
    return current.resolve(raw);
  }

  static bool _isTicketName(String name) =>
      name.startsWith('wengine_vpn_ticket');

  void _resetCookiesForLogin() {
    _cookies
      ..clear()
      ..addAll(_initialCookies);
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
      if (_isTicketName(name)) {
        // ticket 由 WebVPN 会话层持有，绝不混进目标站点 Cookie。
        onWebVpnTicket?.call(name, value.isEmpty ? null : value);
        continue;
      }
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
      final raw = response.header('location') ?? '';
      if (raw.isEmpty) {
        throw GmisApiException('接口发生跳转但没有地址: $path');
      }
      final base = Uri.tryParse('$_baseUrl/') ?? Uri();
      final location = base.resolve(raw);
      final kind = WebVpnUrls.classifyRedirect(
        location,
        viaWebVpn: viaWebVpn,
      );
      switch (kind) {
        case WebVpnRedirectKind.portalLogin:
          throw const WebVpnSessionExpired();
        case WebVpnRedirectKind.targetLogin:
          throw const GmisSessionExpired();
        case WebVpnRedirectKind.external:
          throw const GmisApiException('接口跳转到了不受信任的地址');
        case WebVpnRedirectKind.targetPage:
          throw GmisApiException('接口发生跳转: $path -> ${location.path}');
      }
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
