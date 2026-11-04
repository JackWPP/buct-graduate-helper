import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'course_sheet.dart';
import 'gate.dart';
import 'home_page.dart';
import 'me_page.dart';
import 'prefs.dart';
import 'remind.dart';
import 'schedule.dart';
import 'services_page.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'subpages.dart';
import 'theme.dart';
import 'timetable_page.dart';
import 'widgets.dart';

void main() {
  final params = Uri.base.queryParameters;
  runApp(
    HuayanApp(
      now: DateTime.tryParse(params['now'] ?? ''),
      initialTab: int.tryParse(params['tab'] ?? ''),
      openCourseName: params['sheet'],
      skipGate: params['gate'] == 'off',
    ),
  );
}

class HuayanApp extends StatelessWidget {
  const HuayanApp({
    super.key,
    this.now,
    this.snapshot,
    this.initialTab,
    this.openCourseName,
    this.fontFamily,
    this.skipGate = false,
  });

  final DateTime? now;
  final Snapshot? snapshot;
  final int? initialTab;
  final String? openCourseName;
  final String? fontFamily;

  /// 截图用。正式启动不跳过引导和登录。
  final bool skipGate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '化研助手',
      debugShowCheckedModeBanner: false,
      theme: huayanTheme(fontFamily: fontFamily),
      themeMode: ThemeMode.light,
      home: Shell(
        now: now,
        snapshot: snapshot,
        initialTab: initialTab,
        openCourseName: openCourseName,
        skipGate: skipGate,
      ),
    );
  }
}

enum _Phase { loading, start, guide, login, app }

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    this.now,
    this.snapshot,
    this.initialTab,
    this.openCourseName,
    this.skipGate = false,
  });

  final DateTime? now;
  final Snapshot? snapshot;
  final int? initialTab;
  final String? openCourseName;
  final bool skipGate;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final DateTime _now = widget.now ?? DateTime.now();
  final _settings = AppSettings();
  int _tab = 0;
  Snapshot? _snap;
  Object? _error;
  PrefsStore? _store;
  var _phase = _Phase.loading;
  var _sheetQueued = false;
  var _reminded = false;
  var _loginEpoch = 0;
  var _booted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab ?? 0;
    _tab = initial < 0 || initial > 3 ? 0 : initial;
    final given = widget.snapshot;
    if (widget.skipGate && given != null) {
      _snap = given;
      _booted = true;
      _phase = _Phase.app;
      _queueSheet();
      _scheduleRemind();
      return;
    }
    _boot();
  }

  Future<void> _boot() async {
    Snapshot? snap = widget.snapshot;
    if (snap == null) {
      try {
        final raw = await rootBundle.loadString('assets/snapshot.json');
        snap = Snapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (error) {
        _error = error;
      }
    }
    // 跳过门禁的测试不读偏好，避免小组件通道把首帧停在「正在读取」。
    PrefsStore? store;
    if (!widget.skipGate) {
      store = await PrefsStore.tryOpen();
      store?.apply(_settings);
    }
    if (!mounted) return;
    final ready = store;
    setState(() {
      _store = ready;
      _snap = snap;
      _booted = true;
      if (_error != null || snap == null) {
        _phase = _Phase.loading;
      } else if (widget.skipGate || ready == null) {
        _phase = _Phase.app;
      } else if (!ready.onboarded) {
        _phase = _Phase.start;
      } else {
        _phase = _Phase.login;
      }
    });
    if (_phase == _Phase.app) {
      _queueSheet();
      _scheduleRemind();
    }
  }

  void _queueSheet() {
    final name = widget.openCourseName;
    final snap = _snap;
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
    final snap = _snap;
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

  Future<void> _markOnboarded() async {
    await _store?.setOnboarded();
  }

  void _openCourse(Course course, int week) {
    final snap = _snap;
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

  void _openService(ServiceItem item) {
    final snap = _snap;
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
      case 'exams':
        _push(ExamsPage(count: snap.exams));
      case 'grades':
        _push(GradesPage(snap: snap));
      case 'eval':
        _push(EvalPage(snap: snap));
      case 'profile':
        _push(ProfilePage(student: snap.student));
      default:
        _push(SchoolPage(title: item.name, path: item.path));
    }
  }

  void _enterApp() {
    setState(() => _phase = _Phase.app);
    _queueSheet();
    _scheduleRemind();
  }

  Future<void> _finishGuide() async {
    await _markOnboarded();
    if (!mounted) return;
    setState(() => _phase = _Phase.login);
  }

  Future<void> _login(String sid, bool remember) async {
    if (remember) {
      await _store?.setSid(sid);
    } else {
      await _store?.setSid(null);
    }
    await _markOnboarded();
    if (!mounted) return;
    _enterApp();
  }

  void _logout() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _phase = _Phase.login;
      _loginEpoch += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    Widget body;
    if (!_booted || snap == null) {
      body = Scaffold(
        backgroundColor: HuayanColors.bg,
        body: Center(child: Text(_error == null ? '正在读取课表' : '课表没有载入')),
      );
    } else if (_phase == _Phase.start) {
      body = StartPage(
        onNext: () => setState(() => _phase = _Phase.guide),
        onSkip: _finishGuide,
      );
    } else if (_phase == _Phase.guide) {
      body = GuidePage(
        updatedLabel: snap.updatedLabel,
        onStart: _finishGuide,
        onSkip: _finishGuide,
      );
    } else if (_phase == _Phase.login) {
      final stored = _store?.sid ?? '';
      body = LoginPage(
        key: ValueKey('login-$_loginEpoch'),
        snap: snap,
        initialSid: stored.isEmpty ? snap.loginStudentId : stored,
        onSuccess: _login,
      );
    } else {
      body = _scaffold(snap);
    }
    return RepaintBoundary(key: const Key('app-boundary'), child: body);
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
                    onNotices: () => _push(NoticesPage(count: snap.notices)),
                    onEval: () => _push(EvalPage(snap: snap)),
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
                  ServicesPage(
                    snap: snap,
                    onOpen: _openService,
                    onGroup: (group) =>
                        _push(GroupPage(group: group, onOpen: _openService)),
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
                    onExams: () => _push(ExamsPage(count: snap.exams)),
                    onNotices: () => _push(NoticesPage(count: snap.notices)),
                    onSettings: () => _push(
                      SettingsPage(
                        snap: snap,
                        settings: _settings,
                        now: _now,
                        onChanged: _changed,
                        onLogout: _logout,
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
