import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/main.dart';
import 'package:huayan/schedule.dart';
import 'package:huayan/settings.dart';
import 'package:huayan/snapshot.dart';
import 'package:huayan/timetable_page.dart';

void main() {
  final snap = Snapshot.fromJson(
    jsonDecode(File('assets/snapshot.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final now = DateTime(2026, 11, 3, 11, 37);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> boot(WidgetTester tester, {int tab = 0, Snapshot? data}) async {
    await phone(tester);
    await tester.pumpWidget(
      HuayanApp(
        now: now,
        snapshot: data ?? snap,
        initialTab: tab,
        skipGate: true,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home shows the greeting, week, next class and credits', (
    tester,
  ) async {
    await boot(tester);
    expect(find.text('上午好，王海翔'), findsOneWidget);
    expect(find.textContaining('2026-2027秋季学期 · 第 10 周'), findsOneWidget);
    expect(find.text('下一节'), findsOneWidget);
    expect(find.text('化学生物学导论'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-scroll')),
        matching: find.text('13:30'),
      ),
      findsOneWidget,
    );
    expect(find.text('还有 1 小时 53 分钟'), findsOneWidget);
    expect(find.textContaining('已上完 数值分析'), findsOneWidget);
    expect(find.text('28 / 40'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('tabbar')),
        matching: find.text('首页'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tabbar')),
        matching: find.text('课表'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tabbar')),
        matching: find.text('服务'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tabbar')),
        matching: find.text('我的'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tabbar')),
        matching: find.text('考试'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('tabbar')),
        matching: find.text('通知'),
      ),
      findsNothing,
    );
  });

  testWidgets('week grid keeps the long course readable and opens a sheet', (
    tester,
  ) async {
    await boot(tester, tab: 1);
    expect(find.text('第 10 周'), findsOneWidget);
    expect(find.text('周日'), findsNothing);
    expect(find.text('分子探针与诊疗新技术'), findsOneWidget);
    expect(find.text('宋继彬'), findsNothing);
    await tester.tap(find.text('分子探针与诊疗新技术'));
    await tester.pumpAndSettle();
    expect(find.text('宋继彬'), findsOneWidget);
    expect(find.text('周一 上午 3–5 节 · 09:45–12:15'), findsOneWidget);
    expect(find.textContaining('教617'), findsWidgets);
    await tester.tap(find.text('查看完整详情'));
    await tester.pumpAndSettle();
    expect(find.text('ACh52501'), findsOneWidget);
  });

  testWidgets('week switcher moves forward and back', (tester) async {
    await boot(tester, tab: 1);
    await tester.tap(find.byKey(const Key('week-next')));
    await tester.pumpAndSettle();
    expect(find.text('第 11 周'), findsOneWidget);
    await tester.tap(find.byKey(const Key('week-prev')));
    await tester.pumpAndSettle();
    expect(find.text('第 10 周'), findsOneWidget);
    await tester.tap(find.byKey(const Key('back-today')));
    await tester.pumpAndSettle();
    expect(find.text('第 10 周'), findsOneWidget);
  });

  testWidgets('services keep the snapshot groups and empty exams', (
    tester,
  ) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('tab-services')));
    await tester.pumpAndSettle();
    expect(find.text('培养管理'), findsOneWidget);
    expect(find.text('网上考试'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('service-wskscp')));
    await tester.pumpAndSettle();
    final item = tester.getRect(find.text('网上考试测评'));
    final bar = tester.getRect(find.byKey(const Key('tabbar')));
    expect(item.bottom, lessThanOrEqualTo(bar.top + 1));
    await tester.tap(find.byKey(const Key('service-wskscp')));
    await tester.pumpAndSettle();
    expect(find.text('会在学校网站打开'), findsOneWidget);
    expect(
      find.textContaining('https://gmis.buct.edu.cn/student/wsks/wskscp'),
      findsOneWidget,
    );
    expect(find.textContaining('网上考试测评'), findsWidgets);

    await tester.tap(find.byKey(const Key('nav-back')));
    await tester.pumpAndSettle();
    expect(find.text('会在学校网站打开'), findsNothing);
    await tester.fling(
      find.byKey(const Key('services-scroll')),
      const Offset(0, 1600),
      4000,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('service-search')), '考场');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-kckccx')));
    await tester.pumpAndSettle();
    expect(find.text('考场和调课导出是空的，这里不编倒计时。'), findsOneWidget);
  });

  testWidgets('notices stay empty and me shows the snapshot student', (
    tester,
  ) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('notices-button')));
    await tester.pumpAndSettle();
    expect(find.text('通知列表还没有学校数据，这里保持空态。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-me')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026201060'), findsOneWidget);
    expect(find.text('化学学院'), findsNothing);
    expect(find.textContaining('化学学院'), findsOneWidget);
    expect(find.textContaining('手机'), findsNothing);
    expect(find.textContaining('邮箱'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('me-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('me-settings')));
    await tester.pumpAndSettle();
    expect(find.text('上课提醒'), findsOneWidget);
    expect(find.text('显示非本周课程'), findsOneWidget);
    expect(find.textContaining('没有学校登录会话'), findsOneWidget);
  });

  testWidgets('a one-week timetable hides sunday until a sunday class exists', (
    tester,
  ) async {
    await phone(tester);
    final small = Snapshot(
      termName: '2026-2027秋季学期',
      termStart: '2026-08-31',
      student: const Student(name: '测试', id: '1'),
      notices: 0,
      exams: 0,
      courses: [
        decorateCourse(
          Course.fromJson(const {
            'id': 'a',
            'name': '数值分析',
            'room': '科303',
            'teacher': '甲',
            'online': false,
            'ksz': 1,
            'jsz': 1,
            'pattern': '连续周',
            'sjms': '星期二 上午1 -上午2',
            'credits': 3,
          }),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TimetablePage(
          snap: small,
          now: now,
          settings: AppSettings(),
          initialWeek: 1,
          onCourse: (_, _) {},
          onOnline: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 1 周'), findsOneWidget);
    expect(find.text('数值分析'), findsOneWidget);
    expect(find.text('周日'), findsNothing);
    await tester.tap(find.byKey(const Key('week-next')));
    await tester.pumpAndSettle();
    expect(find.text('第 2 周'), findsOneWidget);
    expect(find.text('数值分析'), findsNothing);

    small.courses.add(
      decorateCourse(
        Course.fromJson(const {
          'id': 'sun',
          'name': '周日实验',
          'room': '科101',
          'teacher': '乙',
          'online': false,
          'ksz': 1,
          'jsz': 2,
          'pattern': '连续周',
          'sjms': '星期日 上午1 -上午2',
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TimetablePage(
          snap: small,
          now: now,
          settings: AppSettings(),
          initialWeek: 1,
          onCourse: (_, _) {},
          onOnline: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('周日'), findsOneWidget);
    expect(find.text('周日实验'), findsOneWidget);
  });

  testWidgets('off-week courses stay hidden until the setting is on', (
    tester,
  ) async {
    await phone(tester);
    final small = Snapshot(
      termName: '2026-2027秋季学期',
      termStart: '2026-08-31',
      student: const Student(name: '测试', id: '1'),
      courses: [
        decorateCourse(
          Course.fromJson(const {
            'id': 'later',
            'name': '稍后才上',
            'room': '科303',
            'teacher': '甲',
            'online': false,
            'ksz': 5,
            'jsz': 6,
            'pattern': '连续周',
            'sjms': '星期一 上午1 -上午2',
          }),
        ),
      ],
    );
    final hidden = AppSettings();
    await tester.pumpWidget(
      MaterialApp(
        home: TimetablePage(
          snap: small,
          now: now,
          settings: hidden,
          initialWeek: 1,
          onCourse: (_, _) {},
          onOnline: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('稍后才上'), findsNothing);
    final shown = AppSettings()..showOffWeek = true;
    await tester.pumpWidget(
      MaterialApp(
        home: TimetablePage(
          snap: small,
          now: now,
          settings: shown,
          initialWeek: 1,
          onCourse: (_, _) {},
          onOnline: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('稍后才上'), findsOneWidget);
  });

  testWidgets('the bundled asset snapshot loads', (tester) async {
    await phone(tester);
    await tester.pumpWidget(HuayanApp(now: now, skipGate: true));
    await tester.pumpAndSettle();
    expect(find.text('上午好，王海翔'), findsOneWidget);
    expect(find.text('28 / 40'), findsOneWidget);
  });
}
