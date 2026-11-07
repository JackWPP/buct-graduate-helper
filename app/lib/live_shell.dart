import 'package:flutter/material.dart';

import 'academics_page.dart';
import 'app_controller.dart';
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
import 'webvpn/sso_login_page.dart';
import 'webvpn/webvpn_login_page.dart';
import 'webvpn/webvpn_session.dart';
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

class _LiveShellState extends State<LiveShell> {
  late final DateTime _now = widget.now ?? DateTime.now();
  final _settings = AppSettings();
  AppController? _controller;
  PrefsStore? _store;
  int _tab = 0;
  bool _onboarded = false;
  bool _guide = false;
  bool _sheetQueued = false;
  bool _reminded = false;
  bool _needsWebVpnLogin = AppConfig.useWebVpnByDefault;
  bool _usingWebVpn = false;
  String? _lastNotice;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab ?? 0;
    _tab = initial < 0 || initial > 4 ? 0 : initial;
    _boot();
  }

  Future<void> _boot() async {
    final store = await PrefsStore.tryOpen();
    store?.apply(_settings);
    final webVpnStore = SecureSessionStore(key: SecureSessionStore.webVpnKey);
    final storedWebVpn = await webVpnStore.read();
    final webVpnSession = storedWebVpn?.baseUrl == null
        ? null
        : WebVpnSession(
            baseUrl: storedWebVpn!.baseUrl!,
            cookies: storedWebVpn.cookies,
          );
    final controller = _createController(
      store: store,
      webVpnSession: webVpnSession,
    );
    if (!mounted) return;
    setState(() {
      _store = store;
      _onboarded = store?.onboarded ?? false;
      _controller = controller;
      _usingWebVpn = webVpnSession != null;
      _needsWebVpnLogin = webVpnSession == null && AppConfig.useWebVpnByDefault;
    });
    await controller.bootstrap();
  }

  AppController _createController({
    PrefsStore? store,
    WebVpnSession? webVpnSession,
  }) {
    final baseUrl = webVpnSession?.baseUrl ?? AppConfig.baseUrl;
    final client = GmisClient(
      transport: DioGmisTransport(baseUrl: baseUrl),
      baseUrl: baseUrl,
      initialCookies: webVpnSession?.cookies ?? const {},
    );
    final controller = AppController(
      gateway: client,
      api: GmisApi(client),
      sessionStore: SecureSessionStore(
        key: webVpnSession == null
            ? SecureSessionStore.directKey
            : SecureSessionStore.webVpnKey,
      ),
      cache: SnapshotCache(),
      calendar: TermCalendar(prefs: store),
    );
    controller.addListener(_onController);
    return controller;
  }

  Future<void> _openWebVpnLogin() async {
    final session = await Navigator.of(context).push<WebVpnSession>(
      MaterialPageRoute(builder: (_) => const WebVpnLoginPage()),
    );
    if (session == null || !mounted) return;
    await _acceptWebVpnSession(session);
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
      _lastNotice = null;
    });
    await controller.bootstrap();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onController);
    _controller?.dispose();
    super.dispose();
  }

  void _onController() {
    if (!mounted) return;
    setState(() {});
    final controller = _controller;
    if (controller == null) return;
    final notice = controller.notice ?? controller.error;
    if (notice != null && notice.isNotEmpty && notice != _lastNotice) {
      _lastNotice = notice;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notice),
            action: controller.phase == AppPhase.offline
                ? SnackBarAction(label: '重试', onPressed: controller.refresh)
                : null,
          ),
        );
      });
    }
    if (controller.phase == AppPhase.ready) _scheduleRemind();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(milliseconds: 1200),
        ),
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

  Future<void> _login(String sid, bool remember) async {
    if (remember) {
      await _store?.setSid(sid);
    } else {
      await _store?.setSid(null);
    }
    await _store?.setOnboarded();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _logout() async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await _controller?.logout();
    await SecureSessionStore(key: SecureSessionStore.directKey).clear();
    await SecureSessionStore(key: SecureSessionStore.webVpnKey).clear();
    if (!mounted) return;
    setState(() {
      _usingWebVpn = false;
      _needsWebVpnLogin = AppConfig.useWebVpnByDefault;
    });
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
              onSessionExpired: () => _controller?.logout(),
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
                onSessionExpired: () => _controller?.logout(),
              ),
            );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return _loading('正在连接学校系统');
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
    if (_needsWebVpnLogin) {
      return SsoLoginPage(
        initialSid: _store?.sid ?? '',
        onUserId: (sid) => _store?.setSid(sid),
        onSuccess: _acceptWebVpnSession,
        onDirect: _useDirectLogin,
      );
    }
    if (controller.phase == AppPhase.booting) {
      return _loading('正在恢复登录状态');
    }
    final snap = controller.snapshot;
    if (snap == null) {
      if (controller.phase == AppPhase.restoring) {
        return _loading('正在读取学校数据');
      }
      return LiveLoginPage(
        controller: controller,
        initialSid: _store?.sid ?? '',
        notice: controller.error,
        onSuccess: _login,
        onWebVpnLogin: _openWebVpnLogin,
        description: _usingWebVpn ? '网页版 VPN 已连接，请登录研究生管理系统。' : null,
        webVpnLabel: _usingWebVpn ? '重新登录网页版 VPN' : '校外访问：使用网页版 VPN 登录',
      );
    }
    if (controller.phase == AppPhase.signedOut ||
        controller.phase == AppPhase.sessionExpired) {
      return LiveLoginPage(
        controller: controller,
        initialSid: _store?.sid ?? '',
        notice: controller.error,
        onSuccess: _login,
        onWebVpnLogin: _openWebVpnLogin,
        description: _usingWebVpn ? '网页版 VPN 已连接，请登录研究生管理系统。' : null,
        webVpnLabel: _usingWebVpn ? '重新登录网页版 VPN' : '校外访问：使用网页版 VPN 登录',
      );
    }
    _queueSheet();
    return _scaffold(snap);
  }

  Widget _loading(String text) {
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 14),
            Text(text, style: const TextStyle(color: HuayanColors.sub)),
          ],
        ),
      ),
    );
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
                    onCourse: (course) =>
                        _openCourse(course, weekIndex(_now, snap.termStart)),
                  ),
                  MePage(
                    snap: snap,
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
              child: HuayanTabBar(
                index: _tab,
                onChanged: (index) => setState(() => _tab = index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
