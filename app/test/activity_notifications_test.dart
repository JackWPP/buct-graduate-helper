import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/activities/activity_models.dart';
import 'package:huayan/activities/activity_notifications.dart';

ActivityItem _item() {
  final start = DateTime(2026, 11, 17, 13, 30);
  return ActivityItem(
    kind: ActivityKind.academicReport,
    id: 'activity-1',
    applicationId: '',
    title: '测试学术报告',
    category: '学术报告',
    publisher: '信息学院',
    organizer: '信息学院',
    location: '学术报告厅',
    method: '线下',
    activityStart: start,
    activityEnd: start.add(const Duration(hours: 2)),
    signupStart: DateTime(2026, 11, 10, 9),
    signupEnd: DateTime(2026, 11, 16, 17),
    capacity: 100,
    enrolled: 20,
    score: '',
    duration: '2 小时',
    auditStatus: '',
    applied: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('account label is shown and notification ids are isolated', () async {
    final service = ActivityNotificationService.instance;
    final item = _item();

    await service.showNewActivity(item);
    await service.showNewActivity(item, accountLabel: '李华');

    final shows = calls.where((call) => call.method == 'show').toList();
    expect(shows, hasLength(2));
    final first = shows[0].arguments as Map;
    final second = shows[1].arguments as Map;
    expect(first['title'], '发现新的学术报告活动');
    expect(second['title'], '发现新的学术报告活动（李华）');
    expect(second['id'], isNot(first['id']));
  });

  test('cancelAll clears notifications when switching accounts', () async {
    await ActivityNotificationService.instance.cancelAll();

    expect(calls.map((call) => call.method), contains('cancelAll'));
  });
}
