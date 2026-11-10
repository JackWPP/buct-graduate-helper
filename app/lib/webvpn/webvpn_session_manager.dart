import 'webvpn_credential.dart';
import 'webvpn_credential_store.dart';
import 'webvpn_validator.dart';

/// 启动时的路由决策，独立成纯函数方便测试。
enum WebVpnStartupRoute { direct, webVpnReady, gmisLogin, ssoLogin, offline }

WebVpnStartupRoute decideStartup({
  required WebVpnState webVpn,
  required bool hasCredential,
  required bool hasGmisSession,
  required bool hasDirectSession,
  required bool defaultWebVpn,
}) {
  if (webVpn == WebVpnState.valid) {
    return hasGmisSession
        ? WebVpnStartupRoute.webVpnReady
        : WebVpnStartupRoute.gmisLogin;
  }
  if (webVpn == WebVpnState.offline) {
    return WebVpnStartupRoute.offline;
  }
  if (webVpn == WebVpnState.expired) {
    return defaultWebVpn
        ? WebVpnStartupRoute.ssoLogin
        : WebVpnStartupRoute.direct;
  }
  // unknown：可能是没有 ticket，也可能是 ticket 还没校验。
  if (hasDirectSession) return WebVpnStartupRoute.direct;
  if (hasCredential) return WebVpnStartupRoute.offline;
  return defaultWebVpn
      ? WebVpnStartupRoute.ssoLogin
      : WebVpnStartupRoute.direct;
}

/// 管理 ticket 的生命周期：加载、校验、更新、清除。
class WebVpnSessionManager {
  WebVpnSessionManager({
    required this.store,
    required this.validator,
    DateTime Function()? clock,
    this.validationTtl = const Duration(minutes: 5),
  }) : _clock = clock ?? DateTime.now;

  final WebVpnCredentialStore store;
  final WebVpnValidator validator;
  final DateTime Function() _clock;
  final Duration validationTtl;

  WebVpnCredential? _credential;
  WebVpnState _state = WebVpnState.unknown;

  WebVpnCredential? get credential => _credential;
  WebVpnState get state => _state;
  bool get hasCredential => _credential != null;
  String? get ticketHeader => _credential?.cookieHeader;

  Future<WebVpnState> restore() async {
    _credential = await store.read();
    if (_credential == null) {
      _state = WebVpnState.unknown;
      return _state;
    }
    return validate(force: true);
  }

  Future<WebVpnState> validate({bool force = false}) async {
    final current = _credential;
    if (current == null) {
      _state = WebVpnState.unknown;
      return _state;
    }
    final validatedAt = current.lastValidatedAt;
    if (!force &&
        _state == WebVpnState.valid &&
        validatedAt != null &&
        _clock().difference(validatedAt) < validationTtl) {
      return _state;
    }

    WebVpnValidation result;
    try {
      result = await validator.validate(current);
    } catch (_) {
      result = const WebVpnValidation(WebVpnState.offline);
    }

    switch (result.state) {
      case WebVpnState.valid:
        final now = _clock();
        _credential = current.copyWith(
          lastUsedAt: now,
          lastValidatedAt: now,
        );
        await store.write(_credential!);
        _state = WebVpnState.valid;
        break;
      case WebVpnState.expired:
        await invalidate();
        _state = WebVpnState.expired;
        break;
      case WebVpnState.offline:
      case WebVpnState.unknown:
        // 网络/未知错误不清 ticket；下次请求或恢复时再校验。
        _state = result.state;
        break;
    }
    return _state;
  }

  /// 已由调用方校验过的 credential 直接落盘（SSO/WebView 成功路径）。
  Future<void> adopt(
    WebVpnCredential credential, {
    WebVpnState state = WebVpnState.valid,
  }) async {
    final now = _clock();
    _credential = credential.copyWith(
      lastUsedAt: now,
      lastValidatedAt: state == WebVpnState.valid ? now : null,
    );
    _state = state;
    await store.write(_credential!);
  }

  /// 门户轮换 ticket 时更新；空值表示门户清除了 ticket。
  Future<void> updateTicket(String name, String? value) async {
    final current = _credential;
    if (current == null) return;
    final ticket = (value ?? '').trim();
    if (ticket.isEmpty) {
      await invalidate();
      return;
    }
    _credential = current.copyWith(
      ticketName: name,
      ticketValue: ticket,
      lastUsedAt: _clock(),
    );
    if (_state == WebVpnState.unknown) _state = WebVpnState.valid;
    try {
      await store.write(_credential!);
    } catch (_) {
      // 轮换后的 ticket 仍在内存里；本次请求继续可用，下次保存再重试。
    }
  }

  Future<void> invalidate() async {
    _credential = null;
    _state = WebVpnState.expired;
    await store.clear();
  }

  Future<void> clear() async {
    _credential = null;
    _state = WebVpnState.unknown;
    await store.clear();
  }
}
