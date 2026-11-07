import '../webvpn/webvpn_session.dart';

/// 从统一身份认证带到研究生管理系统登录页的临时凭据。
///
/// 只允许活在登录流程的内存里：没有 [toJson]，不要写入偏好、安全存储或日志。
class LoginPrefill {
  const LoginPrefill({required this.userId, required this.password});

  final String userId;
  final String password;

  @override
  String toString() =>
      'LoginPrefill(userId: $userId, password: <redacted>)';
}

/// 统一身份认证成功后的结果：WebVPN 会话 + 本次登录的临时凭据。
class SsoLoginSuccess {
  const SsoLoginSuccess({required this.session, required this.prefill});

  final WebVpnSession session;
  final LoginPrefill prefill;

  @override
  String toString() =>
      'SsoLoginSuccess(baseUrl: ${session.baseUrl}, prefill: $prefill)';
}

/// 登录流程里需要跨页面保留的少量状态。
///
/// 密码只保存在 [pendingPrefill] 里，登录完成或退出时清空。
class LoginFlowState {
  LoginPrefill? pendingPrefill;
  int resumeTab = 0;

  LoginPrefill? get prefill => pendingPrefill;

  void acceptSso(SsoLoginSuccess result) {
    pendingPrefill = result.prefill;
  }

  void markLoginComplete() {
    pendingPrefill = null;
  }

  void recordTab(int tab) {
    if (tab < 0 || tab > 4) return;
    resumeTab = tab;
  }

  void clear() {
    pendingPrefill = null;
    resumeTab = 0;
  }
}
