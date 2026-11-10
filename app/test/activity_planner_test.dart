import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/activities/activity_models.dart';
import 'package:huayan/activities/activity_monitor.dart';
import 'package:huayan/activity_page.dart';
import 'package:huayan/schedule.dart';
import 'package:huayan/theme.dart';

class _Source implements ActivityDataSource {
  _Source(this.items);

  final List<ActivityItem> items;

  @override
  Future<List<ActivityItem>> activityAvailable(ActivityKind kind) async =>
      items;

  @override
  Future<List<ActivityItem>> activityApplied(ActivityKind kind) async => [];

  @override
  Future<double> laborPracticeHours() async => 0;

  @override
  Future<bool> canApplyAcademicReport(String id) async => true;

  @override
  Future<Uint8List> activityCaptcha() async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zl1sAAAAASUVORK5CYII=',
  );

  @override
  Future<ActivitySignResult> registerActivity({
    required String id,
    required String captcha,
  }) async => const ActivitySignResult(ok: true, message: '');

  @override
  Future<ActivitySignResult> cancelActivity({
    required ActivityKind kind,
    required String applicationId,
  }) async => const ActivitySignResult(ok: true, message: '');
}

Course _course() {
  return decorateCourse(
    Course.fromJson(const {
      'id': 'c1',
      'name': '数值分析',
      'className': '1班',
      'code': 'c1',
      'credits': 3,
      'teacher': '老师',
      'room': '科303',
      'online': false,
      'ksz': 1,
      'jsz': 20,
      'pattern': '连续周',
      'sjms': '星期二 上午1 -上午2',
    }),
  );
}

ActivityItem _item() {
  final now = DateTime.now();
  return ActivityItem(
    kind: ActivityKind.academicReport,
    id: 'a1',
    applicationId: '',
    title: '学术报告：计算化学',
    category: '学术报告',
    publisher: '研究生院',
    organizer: '',
    location: '报告厅',
    method: '线下',
    activityStart: DateTime(2026, 11, 17, 8, 30),
    activityEnd: DateTime(2026, 11, 17, 9),
    signupStart: now.subtract(const Duration(days: 1)),
    signupEnd: now.add(const Duration(days: 2)),
    capacity: 50,
    enrolled: 10,
    score: '',
    duration: '',
    auditStatus: '',
    applied: false,
  );
}

void main() {
  testWidgets('activity card and detail preview timetable conflict', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: ActivityPage(
          kind: ActivityKind.academicReport,
          dataSource: _Source([_item()]),
          courses: [_course()],
          termStart: '2026-08-31',
          termStartKnown: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('与《数值分析》冲突'), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-card-a1-available')));
    await tester.pumpAndSettle();

    expect(find.text('课表冲突'), findsOneWidget);
    expect(find.text('当天空闲'), findsOneWidget);
    expect(find.byKey(const Key('activity-view-day')), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-view-day')));
    await tester.pumpAndSettle();

    expect(find.text('当天空闲'), findsOneWidget);
    expect(find.text('待报名'), findsOneWidget);
    expect(find.text('数值分析'), findsOneWidget);
    ActivityMonitor.instance.stop();
  });
}
