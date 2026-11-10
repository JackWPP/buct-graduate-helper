import 'dart:async';

import 'package:flutter/material.dart';

import 'academics_page.dart';
import 'activities/activity_models.dart';
import 'activity_page.dart';
import 'activities/activity_monitor.dart';
import 'app_controller.dart';
import 'auth/auth_gateway.dart';
import 'auth/gmis_password_vault.dart';
import 'auth/login_flow.dart';
import 'config/app_config.dart';
import 'course_sheet.dart';
import 'gate.dart';
import 'gmis/gmis_api.dart';
import 'gmis/gmis_client.dart';
import 'gmis/gmis_transport.dart';
import 'home_page.dart';
import 'live_login_page.dart';
import 'me_page.dart';
import 'native_service_page.dart';
import 'prefs.dart';
import 'remind.dart';
import 'schedule.dart';
import 'services_page.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'storage/secure_session_store.dart';
import 'storage/snapshot_cache.dart';
import 'subpages.dart';
import 'term_calendar.dart';
import 'theme.dart';
import 'timetable_page.dart';
import 'ui/feedback.dart';
import 'ui/startup_pages.dart';
import 'webvpn/sso_login_page.dart';
import 'webvpn/webvpn_login_page.dart';
import 'webvpn/webvpn_credential.dart';
import 'webvpn/webvpn_credential_store.dart';
import 'webvpn/sso_session_store.dart';
import 'webvpn/webvpn_session.dart';
import 'webvpn/webvpn_silent_login.dart';
import 'webvpn/webvpn_session_manager.dart';
import 'webvpn/webvpn_validator.dart';
import 'webvpn/webview_cookies.dart';
import 'widgets.dart';

/// 真实模式的外壳：登录、会话恢复、刷新和 5 个主 Tab。
class LiveShell extends StatefulWidget {
  const LiveShell({super.key, this.now, this.initialTab, this.openCourseName});

  final DateTime? now;
  final int? initialTab;
  final String? openCourseName;

  @override
  State<LiveShell> createState() => _LiveShellState();
}

class _LiveShellState extends State<LiveShell> with WidgetsBindingObserver {
  late final DateTime _now = widget.now ?? DateTime.now();
  final _settings = AppSettings();
  final _flow = LoginFlowState();
  AppController? _controller;
  WebVpnSessionManager? _webVpn;
  WebVpnSilentLogin? _silentLogin;
  GmisPasswordVault? _passwordVault;
  SavedGmisLogin? _savedLogin;
  String? _webVpnNotice;
  bool _webVpnExpiryHandled = false;
  bool _webVpnRenewing = false;
  PrefsStore? _store;
  int _tab = 0;
  bool _onboarded = false;
  bool _guide = false;
  bool _sheetQueued = false;
  bool _reminded = false;
  bool _needsWebVpnLogin = AppConfig.useWebVpnByDefault;
  bool _usingWebVpn = false;
  String? _lastNotice;
  String _bootStage = '正在启动';
  DateTime? _lastResumeRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initial = widget.initialTab ?? 0;
    _tab = initial < 0 || initial > 4 ? 0 : initial;
    _flow.recordTab(_tab);
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ActivityMonitor.instance.pause();
    }
    if (state != AppLifecycleState.resumed) return;
    ActivityMonitor.instance.resume();
    final controller = _controller;
    if (controller == null || controller.phase != AppPhase.ready) return;
    final last = _lastResumeRefresh;
    final now = DateTime.now();
    if (last != null && now.difference(last) < const Duration(minutes: 10)) {
      return;
    }
    _lastResumeRefresh = now;
    controller.refresh();
    unawaited(_validateWebVpnOnResume());
  }

  Future<void> _boot() async {
    final store = await PrefsStore.tryOpen();
    store?.apply(_settings);
    if (mounted) setState(() => _bootStage = '正在读取本机会话');

    final passwordVault = GmisPasswordVault();
    _passwordVault = passwordVault;
    try {
      _savedLogin = await passwordVault.read();
    } catch (_) {
      _savedLogin = null;
    }

    final silentLogin = WebVpnSilentLogin(store: SsoSessionStore());
    _silentLogin = silentLogin;
    final manager = WebVpnSessionManager(
      store: WebVpnCredentialStore(),
      validator: HttpWebVpnValidator(),
      renew: silentLogin.renew,
    );
    _webVpn = manager;
    final gmisWebVpnStore = SecureSessionStore(
      key: SecureSessionStore.webVpnKey,
    );
    final directStore = SecureSessionStore(key: SecureSessionStore.directKey);
    final storedWebVpn = await gmisWebVpnStore.read();
    final storedDirect = await directStore.read();

    if (AppConfig.useWebVpnByDefault) {
      if (mounted) setState(() => _bootStage = '正在检查校外访问会话');
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
            )..removeWhere(
                (name, _) => name.startsWith(webVpnTicketPrefix),
              );
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
    final route = AppConfig.useWebVpnByDefault
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

    if (mounted) setState(() => _bootStage = '正在恢复登录状态');
    final controller = _createController(
      store: store,
      webVpnSession: route == WebVpnStartupRoute.ssoLogin
          ? null
          : webVpnSession,
    );
    if (!mounted) return;
    setState(() {
      _store = store;
      _onboarded = store?.onboarded ?? false;
      _controller = controller;
      _usingWebVpn =
          webVpnSession != null && route != WebVpnStartupRoute.ssoLogin;
      _needsWebVpnLogin =
          route == WebVpnStartupRoute.ssoLogin ||
          (route == WebVpnStartupRoute.offline && !hasGmisSession);
      _webVpnNotice = manager.state == WebVpnState.expired
          ? '校外访问会话已过期，请重新登录统一身份认证'
          : route == WebVpnStartupRoute.offline
          ? '暂时无法校验校外访问会话，请检查网络后重试'
          : null;
      _webVpnExpiryHandled = false;
    });
    await controller.bootstrap();
  }

  AppController _createController({
    PrefsStore? store,
    WebVpnSession? webVpnSession,
  }) {
    final baseUrl = webVpnSession?.baseUrl ?? AppConfig.baseUrl;
    final usingWebVpn = webVpnSession != null;
    final client = GmisClient(
      transport: DioGmisTransport(baseUrl: baseUrl),
      baseUrl: baseUrl,
      webVpnTicketHeader: usingWebVpn ? () => _webVpn?.ticketHeader : null,
      onWebVpnTicket: usingWebVpn
          ? (name, value) {
              final manager = _webVpn;
              if (manager != null) {
                unawaited(manager.updateTicket(name, value));
              }
            }
          : null,
      viaWebVpn: usingWebVpn,
    );
    final controller = AppController(
      gateway: client,
      api: GmisApi(client),
      sessionStore: SecureSessionStore(
        key: usingWebVpn
            ? SecureSessionStore.webVpnKey
            : SecureSessionStore.directKey,
      ),
      cache: SnapshotCache(),
      calendar: TermCalendar(prefs: store),
      onWebVpnExpired: _handleWebVpnExpired,
    );
    controller.addListener(_onController);
    return controller;
  }

  Future<void> _openWebVpnLogin() async {
    final credential = await Navigator.of(context).push<WebVpnCredential>(
      MaterialPageRoute(builder: (_) => const WebVpnLoginPage()),
    );
    if (credential == null || !mounted) return;
    final manager = _webVpn;
    if (manager == null) return;
    await manager.adopt(credential, state: WebVpnState.unknown);
    final state = await manager.validate(force: true);
    if (!mounted) return;
    if (state != WebVpnState.valid) {
      setState(() {
        _needsWebVpnLogin = true;
        _webVpnNotice = state == WebVpnState.expired
            ? '网页版 VPN 登录没有生效，请重新登录统一身份认证'
            : '暂时无法校验网页版 VPN 会话，请检查网络后重试';
      });
      return;
    }
    await _acceptWebVpnSession(
      WebVpnSession(credential: manager.credential!),
    );
  }

  Future<void> _acceptSsoLogin(SsoLoginSuccess result) async {
    _flow.acceptSso(result);
    try {
      await _webVpn?.adopt(result.session.credential);
    } catch (_) {
      // ticket 仍在内存里，本次可以用；下次启动重新 SSO。
    }
    try {
      await _silentLogin?.remember(result.ssoCookies);
    } catch (_) {
      // 留存失败只影响下次静默续签，不阻塞本次登录。
    }
    if (!mounted) return;
    await _acceptWebVpnSession(result.session);
  }

  Future<void> _acceptWebVpnSession(WebVpnSession session) async {
    final old = _controller;
    if (old != null) {
      old.removeListener(_onController);
      old.dispose();
    }
    final controller = _createController(store: _store, webVpnSession: session);
    setState(() {
      _controller = controller;
      _usingWebVpn = true;
      _needsWebVpnLogin = false;
      _webVpnNotice = null;
      _webVpnExpiryHandled = false;
      _lastNotice = null;
    });
    await controller.bootstrap();
  }

  Future<void> _useDirectLogin() async {
    final old = _controller;
    if (old != null) {
      old.removeListener(_onController);
      old.dispose();
    }
    final controller = _createController(store: _store);
    setState(() {
      _controller = controller;
      _usingWebVpn = false;
      _needsWebVpnLogin = false;
      _webVpnNotice = null;
      _webVpnExpiryHandled = false;
      _lastNotice = null;
    });
    await controller.bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow.clear();
    _controller?.removeListener(_onController);
    _controller?.dispose();
    super.dispose();
  }

  void _onController() {
    if (!mounted) return;
    setState(() {});
    final controller = _controller;
    if (controller == null) return;
    final notice = controller.notice;
    if (notice != null && notice.isNotEmpty && notice != _lastNotice) {
      _lastNotice = notice;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppFeedback.show(notice);
      });
    }
    if (controller.phase == AppPhase.sessionExpired) {
      _flow.recordTab(_tab);
    }
    if (controller.phase == AppPhase.webVpnExpired) {
      unawaited(_handleWebVpnExpired());
    }
    if (controller.phase == AppPhase.ready) {
      _flow.markLoginComplete();
      _webVpnExpiryHandled = false;
      ActivityMonitor.instance.start(
        controller.api,
        onSessionExpired: _handleSessionExpired,
        onWebVpnExpired: _handleWebVpnExpired,
      );
      _scheduleRemind();
    }
  }

  void _setTab(int index) {
    _flow.recordTab(index);
    setState(() => _tab = index);
  }

  Future<void> _refresh() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.refresh();
    if (mounted) setState(() {});
  }

  void _queueSheet() {
    final name = widget.openCourseName;
    final snap = _controller?.snapshot;
    if (_sheetQueued || name == null || name.isEmpty || snap == null) return;
    Course? course;
    for (final item in snap.courses) {
      if (item.name == name) course = item;
    }
    if (course == null) return;
    _sheetQueued = true;
    final picked = course;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openCourse(picked, weekIndex(_now, snap.termStart));
    });
  }

  void _scheduleRemind() {
    if (_reminded) return;
    final snap = _controller?.snapshot;
    if (snap == null) return;
    final text = foregroundRemindText(
      settings: _settings,
      courses: snap.courses,
      now: _now,
      termStart: snap.termStart,
    );
    _reminded = true;
    if (text == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppFeedback.show(
        text,
        context: context,
        duration: const Duration(milliseconds: 1200),
      );
    });
  }

  void _changed() {
    _store?.save(_settings);
    setState(() {});
  }

  Future<void> _finishGuide() async {
    await _store?.setOnboarded();
    if (!mounted) return;
    setState(() {
      _onboarded = true;
      _guide = false;
    });
  }

  Future<void> _login(String sid, bool remember, String? password) async {
    if (remember) {
      await _store?.setSid(sid);
    } else {
      await _store?.setSid(null);
    }
    final vault = _passwordVault;
    if (vault != null) {
      try {
        if (password == null) {
          await vault.clear();
          _savedLogin = null;
        } else {
          await vault.write(sid, password);
          _savedLogin = await vault.read();
        }
      } catch (_) {
        // 保存失败只影响下次预填，不阻塞登录。
      }
    }
    await _store?.setOnboarded();
    _flow.markLoginComplete();
    final resumeTab = _flow.resumeTab;
    if (!mounted) return;
    setState(() {
      if (resumeTab >= 0 && resumeTab <= 4) _tab = resumeTab;
    });
  }

  Future<void> _clearSavedPassword() async {
    await _passwordVault?.clear();
    if (mounted) setState(() => _savedLogin = null);
  }

  Future<void> _logout() async {
    ActivityMonitor.instance.stop();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await _controller?.logout();
    await _webVpn?.clear();
    await _silentLogin?.clear();
    await _passwordVault?.clear();
    _savedLogin = null;
    await WebViewCookies.clear();
    await SecureSessionStore(key: SecureSessionStore.directKey).clear();
    await SecureSessionStore(key: SecureSessionStore.webVpnKey).clear();
    await SecureSessionStore(key: SecureSessionStore.webVpnTicketKey).clear();
    _flow.clear();
    if (!mounted) return;
    setState(() {
      _tab = 0;
      _usingWebVpn = false;
      _needsWebVpnLogin = AppConfig.useWebVpnByDefault;
      _webVpnNotice = null;
      _webVpnExpiryHandled = false;
      _lastNotice = null;
    });
  }

  /// 会话过期时保留课表和当前 Tab，只清 GMIS 会话。
  Future<void> _handleSessionExpired() async {
    ActivityMonitor.instance.stop();
    final controller = _controller;
    if (controller == null) return;
    _flow.recordTab(_tab);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await controller.expireSession();
    if (!mounted) return;
    _flow.markLoginComplete();
    setState(() {
      _needsWebVpnLogin = _usingWebVpn ? false : AppConfig.useWebVpnByDefault;
      _webVpnNotice = null;
      _lastNotice = null;
    });
  }

  /// WebVPN ticket 失效：先用留存 SSO 静默续签，失败才回统一身份认证。
  Future<void> _handleWebVpnExpired() async {
    if (_webVpnExpiryHandled || _webVpnRenewing) return;
    ActivityMonitor.instance.stop();
    final manager = _webVpn;
    var renewed = false;
    _webVpnRenewing = true;
    try {
      renewed = manager != null && await manager.renewSilently();
    } finally {
      _webVpnRenewing = false;
    }
    if (!mounted) return;
    if (renewed) {
      final credential = manager.credential;
      if (credential != null) {
        await _acceptWebVpnSession(WebVpnSession(credential: credential));
        return;
      }
    }
    _webVpnExpiryHandled = true;
    _flow.recordTab(_tab);
    Navigator.of(context).popUntil((route) => route.isFirst);
    try {
      await _webVpn?.invalidate();
      await WebViewCookies.clear();
    } catch (_) {
      // 清理失败也要回到 SSO 页面。
    }
    if (!mounted) return;
    _flow.markLoginComplete();
    setState(() {
      _usingWebVpn = false;
      _needsWebVpnLogin = true;
      _webVpnNotice = '校外访问已过期，请重新登录统一身份认证';
      _lastNotice = null;
    });
  }

  Future<void> _validateWebVpnOnResume() async {
    final manager = _webVpn;
    if (manager == null || !manager.hasCredential || !_usingWebVpn) return;
    final state = await manager.validate();
    if (!mounted || !_usingWebVpn) return;
    if (state == WebVpnState.expired) {
      await _handleWebVpnExpired();
    }
  }

  Future<void> _openActivities() async {
    final api = _controller?.api;
    if (api == null) return;
    final kind = await showModalBottomSheet<ActivityKind>(
      context: context,
      backgroundColor: HuayanColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: HuayanColors.blue,
              ),
              title: const Text('学术报告'),
              subtitle: const Text('可报名活动、我的报名和自动提醒'),
              onTap: () =>
                  Navigator.of(context).pop(ActivityKind.academicReport),
            ),
            ListTile(
              leading: const Icon(
                Icons.volunteer_activism_outlined,
                color: HuayanColors.amberInk,
              ),
              title: const Text('劳动实践'),
              subtitle: const Text('抢实践、累计劳动小时和自动提醒'),
              onTap: () =>
                  Navigator.of(context).pop(ActivityKind.laborPractice),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final controller = _controller;
    if (controller == null) return;
    _push(
      ActivityPage(
        kind: kind,
        dataSource: api,
        onSessionExpired: _handleSessionExpired,
        onWebVpnExpired: _handleWebVpnExpired,
      ),
    );
  }

  void _openCourse(Course course, int week) {
    final snap = _controller?.snapshot;
    if (snap == null) return;
    openCourseSheet(
      context,
      course: course,
      week: clampWeek(week, termMaxWeek(snap.courses, _now, snap.termStart)),
      now: _now,
      termStart: snap.termStart,
      settings: _settings,
      onChanged: _changed,
    );
  }

  void _goTab(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _tab = index);
  }

  void _push(Widget page) {
    Navigator.of(context).push(huayanRoute<void>(page));
  }

  /// 选课/退选成功后刷新快照，让课表、学分和已选列表跟着更新。
  Future<void> _refreshAfterChange() async {
    await _controller?.refresh();
    if (!mounted) return;
    setState(() {});
  }

  void _openService(ServiceItem item) {
    final snap = _controller?.snapshot;
    if (snap == null) return;
    switch (item.native) {
      case 'timetable':
        _goTab(1);
      case 'progress':
        _push(ProgressPage(snap: snap));
      case 'selected':
        _push(
          SelectedPage(
            snap: snap,
            now: _now,
            onCourse: (course) =>
                _openCourse(course, weekIndex(_now, snap.termStart)),
          ),
        );
      case 'catalog':
      case 'selection':
        if (_controller?.api == null) {
          _push(CourseCatalogPage(snap: snap));
        } else {
          _push(
            NativeServicePage(
              item: item,
              snap: snap,
              api: _controller?.api,
              onChanged: _refreshAfterChange,
              onSessionExpired: _handleSessionExpired,
              onWebVpnExpired: () {
                unawaited(_handleWebVpnExpired());
              },
            ),
          );
        }
      case 'exams':
        _push(ExamsPage(count: snap.exams, items: snap.examItems));
      case 'grades':
        _push(GradesPage(snap: snap));
      case 'eval':
        _push(EvalPage(snap: snap));
      case 'profile':
        _push(ProfilePage(student: snap.student));
      case 'notices':
        _push(NoticesPage(count: snap.notices, items: snap.noticeItems));
      case 'online':
        _push(
          OnlinePage(
            snap: snap,
            onCourse: (course) =>
                _openCourse(course, weekIndex(_now, snap.termStart)),
          ),
        );
      default:
        switch (item.id) {
          case 'grjbxx':
          case 'grxxxg':
            _push(ProfilePage(student: snap.student));
          case 'xyjc':
          case 'pyfacx':
          case 'pyjhcx':
          case 'pyjhtj':
            _push(ProgressPage(snap: snap));
          case 'xjydsq':
            _push(
              ApplicationsPage(
                snap: snap,
                title: item.name,
                applicationIds: const ['zc'],
              ),
            );
          case 'knzzsq':
            _push(
              ApplicationsPage(
                snap: snap,
                title: item.name,
                applicationIds: const ['knzz'],
              ),
            );
          case 'ktlwsq':
          case 'lwktsq':
          case 'zqkhsq':
          case 'zqkhdj':
            _push(
              ApplicationsPage(
                snap: snap,
                title: item.name,
                applicationIds: const ['lwkt'],
              ),
            );
          case 'xsdbsq':
          case 'lwpygl':
          case 'xsxwsq':
          case 'lwdb':
            _push(
              ApplicationsPage(
                snap: snap,
                title: item.name,
                applicationIds: const ['lwdb'],
              ),
            );
          case 'gjxsjlhd':
          case 'py_zysjwc':
          case 'lwkt':
            _push(ApplicationsPage(snap: snap, title: item.name));
          default:
            _push(
              NativeServicePage(
                item: item,
                snap: snap,
                api: _controller?.api,
                onChanged: _refreshAfterChange,
                onSessionExpired: _handleSessionExpired,
                onWebVpnExpired: () {
                  unawaited(_handleWebVpnExpired());
                },
              ),
            );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return SplashPage(message: _bootStage);
    }
    if (!_onboarded) {
      if (!_guide) {
        return StartPage(
          onNext: () => setState(() => _guide = true),
          onSkip: _finishGuide,
        );
      }
      return GuidePage(
        updatedLabel: '学校系统',
        live: true,
        onStart: _finishGuide,
        onSkip: _finishGuide,
      );
    }
    if (_needsWebVpnLogin || controller.phase == AppPhase.webVpnExpired) {
      return SsoLoginPage(
        initialSid: _store?.sid ?? '',
        onUserId: (sid) => _store?.setSid(sid),
        onSuccess: _acceptSsoLogin,
        onDirect: _useDirectLogin,
        notice: _webVpnNotice,
      );
    }
    if (controller.phase == AppPhase.booting) {
      return SplashPage(message: _bootStage);
    }
    final prefill = _flow.prefill;
    final savedLogin = _savedLogin;
    final initialSid =
        prefill?.userId ?? _store?.sid ?? savedLogin?.userId ?? '';
    final initialPassword =
        prefill?.password ??
        (savedLogin != null && savedLogin.userId == initialSid
            ? savedLogin.password
            : null);
    final loginDescription = _usingWebVpn
        ? prefill != null
              ? '统一身份认证已完成，请补研究生管理系统验证码。'
              : '网页版 VPN 已连接，请登录研究生管理系统。'
        : null;
    final snap = controller.snapshot;
    if (snap == null) {
      if (controller.phase == AppPhase.restoring) {
        return const HomeSkeleton();
      }
      return LiveLoginPage(
        controller: controller,
        initialSid: initialSid,
        initialPassword: initialPassword,
        fromSso: prefill != null,
        notice: controller.error,
        onSuccess: _login,
        onWebVpnLogin: _openWebVpnLogin,
        description: loginDescription,
        webVpnLabel: _usingWebVpn ? '重新登录网页版 VPN' : '校外访问：使用网页版 VPN 登录',
      );
    }
    if (controller.phase == AppPhase.signedOut ||
        controller.phase == AppPhase.sessionExpired) {
      return LiveLoginPage(
        controller: controller,
        initialSid: initialSid,
        initialPassword: initialPassword,
        fromSso: prefill != null,
        notice: controller.error,
        onSuccess: _login,
        onWebVpnLogin: _openWebVpnLogin,
        description: loginDescription,
        webVpnLabel: _usingWebVpn ? '重新登录网页版 VPN' : '校外访问：使用网页版 VPN 登录',
      );
    }
    _queueSheet();
    return _scaffold(snap);
  }

  Widget _scaffold(Snapshot snap) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final pageBottom = 12 + bottom + 64 + 8;
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: pageBottom,
              child: IndexedStack(
                index: _tab,
                children: [
                  HomePage(
                    snap: snap,
                    now: _now,
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    offline: _controller?.phase == AppPhase.offline,
                    onCourse: (course) =>
                        _openCourse(course, weekIndex(_now, snap.termStart)),
                    onProgress: () => _push(ProgressPage(snap: snap)),
                    onNotices: () => _push(
                      NoticesPage(count: snap.notices, items: snap.noticeItems),
                    ),
                    onEval: () => _push(EvalPage(snap: snap)),
                    onGrades: () => _push(GradesPage(snap: snap)),
                    onExams: () => _push(
                      ExamsPage(count: snap.exams, items: snap.examItems),
                    ),
                    onActivities: _openActivities,
                    onSelected: () => _push(
                      SelectedPage(
                        snap: snap,
                        now: _now,
                        onCourse: (course) => _openCourse(
                          course,
                          weekIndex(_now, snap.termStart),
                        ),
                      ),
                    ),
                  ),
                  TimetablePage(
                    snap: snap,
                    now: _now,
                    settings: _settings,
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    offline: _controller?.phase == AppPhase.offline,
                    onCourse: _openCourse,
                    onOnline: () => _push(
                      OnlinePage(
                        snap: snap,
                        onCourse: (course) => _openCourse(
                          course,
                          weekIndex(_now, snap.termStart),
                        ),
                      ),
                    ),
                  ),
                  AcademicsPage(
                    snap: snap,
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    onGrades: () => _push(GradesPage(snap: snap)),
                    onExams: () => _push(
                      ExamsPage(count: snap.exams, items: snap.examItems),
                    ),
                    onProgress: () => _push(ProgressPage(snap: snap)),
                    onEval: () => _push(EvalPage(snap: snap)),
                    onSelected: () => _push(
                      SelectedPage(
                        snap: snap,
                        now: _now,
                        onCourse: (course) => _openCourse(
                          course,
                          weekIndex(_now, snap.termStart),
                        ),
                      ),
                    ),
                  ),
                  ServicesPage(
                    snap: snap,
                    onOpen: _openService,
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    offline: _controller?.phase == AppPhase.offline,
                    onCourse: (course) =>
                        _openCourse(course, weekIndex(_now, snap.termStart)),
                  ),
                  MePage(
                    snap: snap,
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    onProfile: () => _push(ProfilePage(student: snap.student)),
                    onProgress: () => _push(ProgressPage(snap: snap)),
                    onApplications: () => _push(ApplicationsPage(snap: snap)),
                    onGrades: () => _push(GradesPage(snap: snap)),
                    onSelected: () => _push(
                      SelectedPage(
                        snap: snap,
                        now: _now,
                        onCourse: (course) => _openCourse(
                          course,
                          weekIndex(_now, snap.termStart),
                        ),
                      ),
                    ),
                    onEval: () => _push(EvalPage(snap: snap)),
                    onExams: () => _push(
                      ExamsPage(count: snap.exams, items: snap.examItems),
                    ),
                    onNotices: () => _push(
                      NoticesPage(count: snap.notices, items: snap.noticeItems),
                    ),
                    onSettings: () => _push(
                      SettingsPage(
                        snap: snap,
                        settings: _settings,
                        now: _now,
                        onChanged: _changed,
                        onLogout: _logout,
                        isLive: true,
                        hasSavedPassword: _savedLogin != null,
                        onClearSavedPassword: _clearSavedPassword,
                        onRefresh: _controller?.refresh,
                        termCode: snap.termCode,
                        onTermStart: (firstMonday) async {
                          await _store?.setTermStart(
                            snap.termCode,
                            firstMonday,
                          );
                          await _controller?.refresh();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              key: const Key('tabbar'),
              left: 16,
              right: 16,
              bottom: 12 + bottom,
              child: HuayanTabBar(index: _tab, onChanged: _setTab),
            ),
          ],
        ),
      ),
    );
  }
}
