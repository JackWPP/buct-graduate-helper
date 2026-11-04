import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'course_sheet.dart';
import 'home_page.dart';
import 'me_page.dart';
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
  });

  final DateTime? now;
  final Snapshot? snapshot;
  final int? initialTab;
  final String? openCourseName;
  final String? fontFamily;

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
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    this.now,
    this.snapshot,
    this.initialTab,
    this.openCourseName,
  });

  final DateTime? now;
  final Snapshot? snapshot;
  final int? initialTab;
  final String? openCourseName;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final DateTime _now = widget.now ?? DateTime.now();
  final _settings = AppSettings();
  int _tab = 0;
  Snapshot? _snap;
  Object? _error;
  var _sheetQueued = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab ?? 0;
    _tab = initial < 0 || initial > 3 ? 0 : initial;
    final given = widget.snapshot;
    if (given != null) {
      _snap = given;
      _queueSheet();
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/snapshot.json');
      if (!mounted) return;
      setState(
        () =>
            _snap = Snapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
      _queueSheet();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
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

  void _openCourse(Course course, int week) {
    final snap = _snap;
    if (snap == null) return;
    openCourseSheet(
      context,
      course: course,
      week: clampWeek(week, termMaxWeek(snap.courses, _now, snap.termStart)),
      now: _now,
      termStart: snap.termStart,
    );
  }

  void _goTab(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _tab = index);
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
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
        _push(UnavailablePage(title: item.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final pageBottom = 12 + bottom + 64 + 8;
    Widget body;
    if (_error != null) {
      body = const Center(child: Text('课表没有载入'));
    } else if (snap == null) {
      body = const Center(child: Text('正在读取课表'));
    } else {
      body = IndexedStack(
        index: _tab,
        children: [
          HomePage(
            snap: snap,
            now: _now,
            onCourse: (course) =>
                _openCourse(course, weekIndex(_now, snap.termStart)),
            onProgress: () => _push(ProgressPage(snap: snap)),
            onNotices: () => _push(NoticesPage(count: snap.notices)),
          ),
          TimetablePage(
            snap: snap,
            now: _now,
            settings: _settings,
            onCourse: _openCourse,
            onOnline: () => _push(
              OnlinePage(
                snap: snap,
                onCourse: (course) =>
                    _openCourse(course, weekIndex(_now, snap.termStart)),
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
                onCourse: (course) =>
                    _openCourse(course, weekIndex(_now, snap.termStart)),
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
                onChanged: () => setState(() {}),
              ),
            ),
          ),
        ],
      );
    }
    return RepaintBoundary(
      key: const Key('app-boundary'),
      child: Scaffold(
        backgroundColor: HuayanColors.bg,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: pageBottom),
                child: body,
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
      ),
    );
  }
}
