import 'dart:typed_data';

import '../activities/activity_models.dart';
import '../planner/todo_models.dart';

/// UI_PREVIEW / 设计预览用的假活动。正常构建不会走这里。
List<ActivityItem> demoAvailableActivities(ActivityKind kind) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final nextTuesday = _nextWeekday(now, DateTime.tuesday);
  final openStart = DateTime(
    nextTuesday.year,
    nextTuesday.month,
    nextTuesday.day,
    8,
    30,
  );
  final openEnd = DateTime(
    nextTuesday.year,
    nextTuesday.month,
    nextTuesday.day,
    10,
  );
  return [
    _activity(
      kind: kind,
      id: 'demo-open',
      title: '学术报告：计算化学与人工智能',
      signupStart: _at(today.subtract(const Duration(days: 1)), 12),
      signupEnd: _at(today.add(const Duration(days: 2)), 12),
      start: openStart,
      end: openEnd,
      enrolled: 12,
    ),
    _activity(
      kind: kind,
      id: 'demo-upcoming',
      title: '学术报告：新能源材料前沿',
      signupStart: _at(today.add(const Duration(days: 1)), 12),
      signupEnd: _at(today.add(const Duration(days: 3)), 12),
      start: nextTuesday.add(const Duration(days: 1, hours: 14)),
      end: nextTuesday.add(const Duration(days: 1, hours: 16)),
    ),
    _activity(
      kind: kind,
      id: 'demo-full',
      title: '学术报告：催化反应工程',
      signupStart: _at(today.subtract(const Duration(days: 2)), 12),
      signupEnd: _at(today.add(const Duration(days: 1)), 12),
      start: nextTuesday.add(const Duration(days: 2, hours: 9)),
      end: nextTuesday.add(const Duration(days: 2, hours: 11)),
      capacity: 30,
      enrolled: 30,
    ),
  ];
}

List<ActivityItem> demoAppliedActivities() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final nextTuesday = _nextWeekday(now, DateTime.tuesday);
  return [
    _activity(
      kind: ActivityKind.academicReport,
      id: 'demo-applied',
      title: '学术报告：实验室安全',
      signupStart: _at(today.subtract(const Duration(days: 5)), 12),
      signupEnd: _at(today.subtract(const Duration(days: 4)), 12),
      start: nextTuesday.add(const Duration(days: 3, hours: 14)),
      end: nextTuesday.add(const Duration(days: 3, hours: 16)),
      applied: true,
    ),
  ];
}

List<TodoItem> demoTodos() {
  final nextTuesday = _nextWeekday(DateTime.now(), DateTime.tuesday);
  final date =
      '${nextTuesday.year.toString().padLeft(4, '0')}-'
      '${nextTuesday.month.toString().padLeft(2, '0')}-'
      '${nextTuesday.day.toString().padLeft(2, '0')}';
  return [
    TodoItem(
      id: 'demo-todo',
      title: '交实验报告',
      date: date,
      startMin: 12 * 60,
      endMin: 12 * 60 + 30,
      createdAt: 0,
    ),
  ];
}

class DemoActivityDataSource implements ActivityDataSource {
  @override
  Future<List<ActivityItem>> activityAvailable(ActivityKind kind) async =>
      demoAvailableActivities(kind);

  @override
  Future<List<ActivityItem>> activityApplied(ActivityKind kind) async =>
      kind == ActivityKind.academicReport ? demoAppliedActivities() : const [];

  @override
  Future<double> laborPracticeHours() async => 12.5;

  @override
  Future<bool> canApplyAcademicReport(String id) async => true;

  @override
  Future<Uint8List> activityCaptcha() async => Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ]);

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

ActivityItem _activity({
  required ActivityKind kind,
  required String id,
  required String title,
  required DateTime signupStart,
  required DateTime signupEnd,
  required DateTime start,
  required DateTime end,
  int capacity = 50,
  int enrolled = 12,
  bool applied = false,
}) {
  return ActivityItem(
    kind: kind,
    id: id,
    applicationId: applied ? 'hd-$id' : '',
    title: title,
    category: kind.label,
    publisher: '研究生院',
    organizer: '化学工程学院',
    location: '会议中心报告厅',
    method: '线下',
    activityStart: start,
    activityEnd: end,
    signupStart: signupStart,
    signupEnd: signupEnd,
    capacity: capacity,
    enrolled: enrolled,
    score: '0.5',
    duration: '1.5 小时',
    auditStatus: applied ? '1' : '',
    applied: applied,
  );
}

DateTime _at(DateTime date, int hour, [int minute = 0]) =>
    DateTime(date.year, date.month, date.day, hour, minute);

DateTime _nextWeekday(DateTime now, int weekday) {
  final today = DateTime(now.year, now.month, now.day);
  var delta = (weekday - today.weekday + 7) % 7;
  if (delta == 0) delta = 7;
  return today.add(Duration(days: delta));
}
