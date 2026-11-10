import '../gmis/gmis_exception.dart';

/// WebVPN 门户 ticket 失效：必须重新走统一身份认证。
///
/// 故意不继承 [GmisSessionExpired]，避免现有 catch 顺序把它当成
/// “研究生管理系统登录过期”而送到 GMIS 验证码页。
class WebVpnSessionExpired extends GmisAuthException {
  const WebVpnSessionExpired()
    : super('校外访问会话已过期，请重新登录统一身份认证');
}

/// 统一身份认证完成了，但门票没有生效（例如只拿到匿名 ticket）。
class WebVpnAuthException extends GmisAuthException {
  const WebVpnAuthException(super.message);
}
