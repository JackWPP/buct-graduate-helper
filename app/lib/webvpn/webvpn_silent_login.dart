import 'sso_session.dart';
import 'sso_session_store.dart';
import 'webvpn_auth_client.dart';
import 'webvpn_session.dart';

/// 统一身份认证的“保持登录”能力。
///
/// 原生 SSO 成功后保存 `sidportal` Cookie；WebVPN ticket 失效时用它静默
/// 换新 ticket，只有 SSO 会话本身也失效才让用户重新输入密码。
class WebVpnSilentLogin {
  WebVpnSilentLogin({
    required this.store,
    WebVpnAuthClient? client,
    DateTime Function()? clock,
  }) : _client = client ?? WebVpnAuthClient(),
       _clock = clock ?? DateTime.now;

  final SsoSessionStore store;
  final WebVpnAuthClient _client;
  final DateTime Function() _clock;

  /// 保存本次 SSO 成功后的会话 Cookie（只进安全存储）。
  Future<void> remember(Map<String, String> cookies) async {
    if (cookies.isEmpty) return;
    await store.write(
      SsoSession(cookies: Map<String, String>.from(cookies), savedAt: _clock()),
    );
  }

  /// 静默续签；SSO 会话失效时清除留存并返回 null。
  ///
  /// 网络异常会继续抛出，由会话层标成 offline，保留 Cookie 供下次重试。
  Future<WebVpnSession?> renew() async {
    final saved = await store.read();
    if (saved == null) return null;
    final session = await _client.renewSilently(ssoCookies: saved.cookies);
    if (session == null) {
      await store.clear();
      return null;
    }
    final rotated = _client.ssoCookies;
    if (rotated.isNotEmpty) {
      await store.write(
        SsoSession(
          cookies: Map<String, String>.from(rotated),
          savedAt: _clock(),
        ),
      );
    }
    return session;
  }

  Future<void> clear() => store.clear();
}
