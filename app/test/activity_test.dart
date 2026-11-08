import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/activities/activity_models.dart';
import 'package:huayan/activities/activity_monitor.dart';
import 'package:huayan/activity_page.dart';
import 'package:huayan/theme.dart';

class _FakeActivitySource implements ActivityDataSource {
  _FakeActivitySource({this.available = const []});

  List<ActivityItem> available;
  List<ActivityItem> applied = [];
  int registerCalls = 0;
  int cancelCalls = 0;

  @override
  Future<List<ActivityItem>> activityAvailable(ActivityKind kind) async =>
      available;

  @override
  Future<List<ActivityItem>> activityApplied(ActivityKind kind) async =>
      applied;

  @override
  Future<double> laborPracticeHours() async => 12.5;

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
  }) async {
    registerCalls++;
    final item = available.firstWhere((item) => item.id == id);
    available = available.where((item) => item.id != id).toList();
    applied = [...applied, _copyAsApplied(item)];
    return const ActivitySignResult(ok: true, message: '');
  }

  @override
  Future<ActivitySignResult> cancelActivity({
    required ActivityKind kind,
    required String applicationId,
  }) async {
    cancelCalls++;
    applied = applied
        .where((item) => item.applicationId != applicationId)
        .toList();
    return const ActivitySignResult(ok: true, message: '');
  }

  ActivityItem _copyAsApplied(ActivityItem item) => ActivityItem(
    kind: item.kind,
    id: item.id,
    applicationId: 'hd-${item.id}',
    title: item.title,
    category: item.category,
    publisher: item.publisher,
    organizer: item.organizer,
    location: item.location,
    method: item.method,
    activityStart: item.activityStart,
    activityEnd: item.activityEnd,
    signupStart: item.signupStart,
    signupEnd: item.signupEnd,
    capacity: item.capacity,
    enrolled: item.enrolled,
    score: item.score,
    duration: item.duration,
    auditStatus: '0',
    applied: true,
  );
}

ActivityItem _item({
  String id = 'a-1',
  String title = '研究生学术报告：计算化学前沿',
  bool applied = false,
  DateTime? signupStart,
  DateTime? signupEnd,
  int capacity = 50,
  int enrolled = 12,
}) {
  final now = DateTime(2026, 11, 8, 15);
  return ActivityItem(
    kind: ActivityKind.academicReport,
    id: id,
    applicationId: applied ? 'hd-$id' : '',
    title: title,
    category: '学术报告',
    publisher: '研究生院',
    organizer: '化学工程学院',
    location: '会议中心报告厅',
    method: '线下',
    activityStart: now.add(const Duration(days: 3)),
    activityEnd: now.add(const Duration(days: 3, hours: 2)),
    signupStart: signupStart ?? now.subtract(const Duration(hours: 1)),
    signupEnd: signupEnd ?? now.add(const Duration(days: 1)),
    capacity: capacity,
    enrolled: enrolled,
    score: '0.5',
    duration: '2 小时',
    auditStatus: '',
    applied: applied,
  );
}

void main() {
  test('activity item parses school fields and phase', () {
    final item = ActivityItem.fromJson(
      {
        'id': '123',
        'mc': '学术报告：化学前沿',
        'fl': '学术报告',
        'kssj': '2026-11-10 14:00',
        'jzsj': '2026-11-10 16:00',
        'bmkssj': '2026-11-08 08:00',
        'bmjzsj': '2026-11-09 20:00',
        'rs': '50',
        'bmrs': '49',
        'fs': '0.5',
        'dd': '报告厅',
      },
      kind: ActivityKind.academicReport,
      applied: false,
    );

    expect(item.id, '123');
    expect(item.title, '学术报告：化学前沿');
    expect(item.capacity, 50);
    expect(item.enrolled, 49);
    expect(item.remaining, 1);
    expect(item.phaseAt(DateTime(2026, 11, 8, 12)), ActivityPhase.open);
    expect(item.phaseAt(DateTime(2026, 11, 10, 9)), ActivityPhase.closed);
  });

  testWidgets('activity page shows available activities and total hours', (
    tester,
  ) async {
    final source = _FakeActivitySource(available: [_item()]);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(ActivityMonitor.instance.stop);
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: ActivityPage(
          kind: ActivityKind.laborPractice,
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('activity-card-a-1-available')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('activity-total-hours')), findsOneWidget);
    expect(find.text('12.5 小时'), findsOneWidget);
    ActivityMonitor.instance.stop();
  });

  testWidgets('activity cancellation asks for confirmation', (tester) async {
    final source = _FakeActivitySource(
      available: [_item(applied: true, id: 'a-2')],
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(ActivityMonitor.instance.stop);
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: ActivityPage(
          kind: ActivityKind.academicReport,
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-primary-a-2-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('取消报名'), findsWidgets);
    expect(find.byKey(const Key('activity-cancel-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-cancel-confirm')));
    await tester.pumpAndSettle();
    expect(source.cancelCalls, 1);
    ActivityMonitor.instance.stop();
  });

  testWidgets('activity registration requires captcha and adds to applied', (
    tester,
  ) async {
    final source = _FakeActivitySource(available: [_item()]);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(ActivityMonitor.instance.stop);
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: ActivityPage(
          kind: ActivityKind.academicReport,
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-primary-a-1-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-captcha-input')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('activity-captcha-input')),
      '1234',
    );
    await tester.tap(find.byKey(const Key('activity-captcha-confirm')));
    await tester.pumpAndSettle();
    expect(source.registerCalls, 1);
    expect(find.text('报名成功'), findsWidgets);
    ActivityMonitor.instance.stop();
  });
}
