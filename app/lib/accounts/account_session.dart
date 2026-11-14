import 'dart:async';

import '../app_controller.dart';
import '../auth/auth_gateway.dart';
import '../auth/gmis_password_vault.dart';
import '../auth/login_flow.dart';
import '../config/app_config.dart';
import '../gmis/gmis_api.dart';
import '../gmis/gmis_client.dart';
import '../gmis/gmis_transport.dart';
import '../prefs.dart';
import '../webvpn/webvpn_silent_login.dart';
import '../webvpn/webvpn_validator.dart';
import '../webvpn/webvpn_credential.dart';
import '../webvpn/webvpn_session.dart';
import '../webvpn/webvpn_session_manager.dart';
import '../webvpn/webview_cookies.dart';
import 'account_models.dart';
import 'account_storage.dart';

/// 一个已保存账号的运行时。认证、会话恢复和 scoped 存储都收在这里；
/// LiveShell 只负责界面、Tab、监测和待办。
class AccountSession {
  AccountSession({
    required this.profile,
    required this.storage,
    required this.onWebVpnExpired,
    this.prefs,
    this.onStage,
  }) : passwordVault = storage.passwordVault;

  final AccountProfile profile;
  final AccountStorage storage;
  final PrefsStore? prefs;
  final Future<void> Function() onWebVpnExpired;
  final void Function(String stage)? onStage;

  final GmisPasswordVault passwordVault;
  WebVpnSessionManager? webVpn;
  WebVpnSilentLogin? silentLogin;
  SavedGmisLogin? savedLogin;
  AppController? controller;
  WebVpnStartupRoute route = WebVpnStartupRoute.ssoLogin;
  bool usingWebVpn = false;
  bool needsWebVpnLogin = AppConfig.useWebVpnByDefault;
  bool webVpnExpiryHandled = false;
  bool webVpnRenewing = false;
  String? webVpnNotice;
  bool disposed = false;

  bool get hasGmisSession =>
      controller?.phase == AppPhase.ready ||
      controller?.phase == AppPhase.restoring ||
      controller?.phase == AppPhase.offline;

  String get initialSid {
    final savedId = savedLogin?.userId ?? '';
    if (savedId.isNotEmpty) return savedId;
    if (profile.id.isNotEmpty) return profile.id;
    return prefs?.sid ?? '';
  }

  Future<void> boot() async {
    _stage('正在读取本机会话');
    try {
      savedLogin = await passwordVault.read(touch: true);
    } catch (_) {
      savedLogin = null;
    }

    final silent = WebVpnSilentLogin(store: storage.ssoSessionStore);
    silentLogin = silent;
    final manager = WebVpnSessionManager(
      store: storage.webVpnCredentialStore,
      validator: HttpWebVpnValidator(),
      renew: silent.renew,
    );
    webVpn = manager;
    final gmisWebVpnStore = storage.sessionStore(webVpn: true);
    final directStore = storage.sessionStore();
    final storedWebVpn = await gmisWebVpnStore.read();
    final storedDirect = await directStore.read();

    if (AppConfig.useWebVpnByDefault) {
      _stage('正在检查校外访问会话');
      try {
        await manager.restore();
      } catch (_) {
        // 安全存储/网络异常按未校验处理，不阻塞启动。
      }

      // 旧版本把 ticket 混在 GMIS 会话 Cookie 里；启动时迁移并从 GMIS
      // 会话中剔除，避免把 bearer token 当成普通 Cookie 保存。
      if (storedWebVpn != null) {
        try {
          final legacy = WebVpnCredential.fromLegacySession(
            storedWebVpn.toJson(),
          );
          if (legacy != null) {
            if (!manager.hasCredential) {
              await manager.adopt(legacy, state: WebVpnState.unknown);
              await manager.validate(force: true);
            }
            final cleanedCookies = Map<String, String>.from(
              storedWebVpn.cookies,
            )..removeWhere((name, _) => name.startsWith(webVpnTicketPrefix));
            await gmisWebVpnStore.write(
              AuthSession(
                userId: storedWebVpn.userId,
                cookies: cleanedCookies,
                savedAt: storedWebVpn.savedAt,
                baseUrl: storedWebVpn.baseUrl,
              ),
            );
          }
        } catch (_) {
          // 迁移失败按没有旧 ticket 处理，不影响本次启动。
        }
      }
    }

    final hasGmisSession = storedWebVpn?.baseUrl != null;
    route = AppConfig.useWebVpnByDefault
        ? decideStartup(
            webVpn: manager.state,
            hasCredential: manager.hasCredential,
            hasGmisSession: hasGmisSession,
            hasDirectSession: storedDirect != null,
            defaultWebVpn: true,
          )
        : WebVpnStartupRoute.direct;

    final webVpnSession = manager.hasCredential
        ? WebVpnSession(credential: manager.credential!)
        : null;

    _stage('正在恢复登录状态');
    controller = _createController(
      webVpnSession: route == WebVpnStartupRoute.ssoLogin
          ? null
          : webVpnSession,
    );
    usingWebVpn = webVpnSession != null && route != WebVpnStartupRoute.ssoLogin;
    needsWebVpnLogin =
        route == WebVpnStartupRoute.ssoLogin ||
        (route == WebVpnStartupRoute.offline && !hasGmisSession);
    webVpnNotice = manager.state == WebVpnState.expired
        ? '校外访问会话已过期，请重新登录统一身份认证'
        : route == WebVpnStartupRoute.offline
        ? '暂时无法校验校外访问会话，请检查网络后重试'
        : null;
    webVpnExpiryHandled = false;
    await controller!.bootstrap();
  }

  AppController _createController({WebVpnSession? webVpnSession}) {
    final baseUrl = webVpnSession?.baseUrl ?? AppConfig.baseUrl;
    final viaWebVpn = webVpnSession != null;
    final manager = webVpn;
    final client = GmisClient(
      transport: DioGmisTransport(baseUrl: baseUrl),
      baseUrl: baseUrl,
      webVpnTicketHeader: viaWebVpn ? () => webVpn?.ticketHeader : null,
      onWebVpnTicket: viaWebVpn
          ? (name, value) {
              final current = manager;
              if (current != null) {
                unawaited(current.updateTicket(name, value));
              }
            }
          : null,
      viaWebVpn: viaWebVpn,
    );
    return AppController(
      gateway: client,
      api: GmisApi(client),
      sessionStore: storage.sessionStore(webVpn: viaWebVpn),
      cache: storage.snapshotCache,
      calendar: storage.termCalendar(prefs: prefs),
      onWebVpnExpired: onWebVpnExpired,
    );
  }

  Future<void> acceptSso(SsoLoginSuccess result) async {
    try {
      await webVpn?.adopt(result.session.credential);
    } catch (_) {
      // ticket 仍在内存里，本次可以用；下次启动重新 SSO。
    }
    try {
      await silentLogin?.remember(result.ssoCookies);
    } catch (_) {
      // 留存失败只影响下次静默续签，不阻塞本次登录。
    }
    await acceptWebVpnSession(result.session);
  }

  Future<void> acceptWebVpnSession(WebVpnSession session) async {
    final old = controller;
    old?.dispose();
    controller = _createController(webVpnSession: session);
    usingWebVpn = true;
    needsWebVpnLogin = false;
    webVpnNotice = null;
    webVpnExpiryHandled = false;
    await controller!.bootstrap();
  }

  Future<void> useDirectLogin() async {
    final old = controller;
    old?.dispose();
    controller = _createController();
    usingWebVpn = false;
    needsWebVpnLogin = false;
    webVpnNotice = null;
    webVpnExpiryHandled = false;
    await controller!.bootstrap();
  }

  /// 退出当前账号：清会话/密码/票据/缓存，保留账号资料和待办。
  Future<void> logout() async {
    await controller?.logout();
    await webVpn?.clear();
    await silentLogin?.clear();
    await storage.clearSessionData();
    savedLogin = null;
    await WebViewCookies.clear();
  }

  /// 移除账号：在退出基础上清掉本机学期开始日；待办由 shell 按学号清。
  Future<void> wipe() async {
    await logout();
    await prefs?.clearTermStarts(accountId: profile.storageKey);
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    controller?.dispose();
    controller = null;
  }

  void _stage(String stage) => onStage?.call(stage);
}
