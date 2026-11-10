import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/activities/activity_buckets.dart';
import 'package:huayan/activities/activity_models.dart';

ActivityItem _item({
  required String id,
  DateTime? signupStart,
  DateTime? signupEnd,
  DateTime? activityStart,
  DateTime? activityEnd,
  int capacity = 50,
  int enrolled = 0,
  bool applied = false,
}) {
  return ActivityItem(
    kind: ActivityKind.academicReport,
    id: id,
    applicationId: applied ? 'hd-$id' : '',
    title: id,
    category: '学术报告',
    publisher: '研究生院',
    organizer: '',
    location: '报告厅',
    method: '线下',
    activityStart: activityStart,
    activityEnd: activityEnd,
    signupStart: signupStart,
    signupEnd: signupEnd,
    capacity: capacity,
    enrolled: enrolled,
    score: '',
    duration: '',
    auditStatus: '',
    applied: applied,
  );
}

void main() {
  final now = DateTime(2026, 11, 10, 10);

  test('splits open, pending and closed activities', () {
    final openLate = _item(
      id: 'open-late',
      signupStart: DateTime(2026, 11, 8, 12),
      signupEnd: DateTime(2026, 11, 14, 12),
      activityStart: DateTime(2026, 11, 17, 13, 30),
    );
    final openSoon = _item(
      id: 'open-soon',
      signupStart: DateTime(2026, 11, 8, 12),
      signupEnd: DateTime(2026, 11, 12, 12),
      activityStart: DateTime(2026, 11, 13, 13, 30),
    );
    final upcoming = _item(
      id: 'upcoming',
      signupStart: DateTime(2026, 11, 12, 12),
      signupEnd: DateTime(2026, 11, 16, 12),
      activityStart: DateTime(2026, 11, 20, 13, 30),
    );
    final full = _item(
      id: 'full',
      signupStart: DateTime(2026, 11, 8, 12),
      signupEnd: DateTime(2026, 11, 14, 12),
      activityStart: DateTime(2026, 11, 15, 13, 30),
      capacity: 30,
      enrolled: 30,
    );
    final closed = _item(
      id: 'closed',
      signupStart: DateTime(2026, 11, 1, 12),
      signupEnd: DateTime(2026, 11, 5, 12),
      activityStart: DateTime(2026, 11, 20, 13, 30),
    );
    final endedFull = _item(
      id: 'ended-full',
      signupStart: DateTime(2026, 11, 1, 12),
      signupEnd: DateTime(2026, 11, 5, 12),
      activityStart: DateTime(2026, 11, 9, 13, 30),
      capacity: 30,
      enrolled: 30,
    );
    final applied = _item(
      id: 'applied',
      signupStart: DateTime(2026, 11, 8, 12),
      signupEnd: DateTime(2026, 11, 14, 12),
      activityStart: DateTime(2026, 11, 17, 13, 30),
      applied: true,
    );

    final buckets = partitionAvailableActivities([
      openLate,
      openSoon,
      upcoming,
      full,
      closed,
      endedFull,
      applied,
    ], now);

    expect(buckets.open.map((item) => item.id), ['open-soon', 'open-late']);
    expect(buckets.pending.map((item) => item.id), ['upcoming', 'full']);
    expect(buckets.total, 4);
  });

  test('pending sorts by the next moment', () {
    final fullSoon = _item(
      id: 'full-soon',
      signupStart: DateTime(2026, 11, 8),
      signupEnd: DateTime(2026, 11, 12),
      activityStart: DateTime(2026, 11, 13, 9),
      capacity: 10,
      enrolled: 10,
    );
    final opensLater = _item(
      id: 'opens-later',
      signupStart: DateTime(2026, 11, 14),
      signupEnd: DateTime(2026, 11, 18),
      activityStart: DateTime(2026, 11, 25),
    );

    expect(
      partitionAvailableActivities([
        opensLater,
        fullSoon,
      ], now).pending.map((item) => item.id),
      ['full-soon', 'opens-later'],
    );
  });

  test('slot release needs a previous full activity and an open window', () {
    final full = _item(
      id: 'a',
      signupStart: DateTime(2026, 11, 8),
      signupEnd: DateTime(2026, 11, 14, 12),
      activityStart: DateTime(2026, 11, 17),
      capacity: 30,
      enrolled: 30,
    );
    final opened = _item(
      id: 'a',
      signupStart: DateTime(2026, 11, 8),
      signupEnd: DateTime(2026, 11, 14, 12),
      activityStart: DateTime(2026, 11, 17),
      capacity: 30,
      enrolled: 29,
    );
    final closed = _item(
      id: 'a',
      signupStart: DateTime(2026, 11, 8),
      signupEnd: DateTime(2026, 11, 9, 12),
      activityStart: DateTime(2026, 11, 17),
      capacity: 30,
      enrolled: 29,
    );
    final unknownCapacity = _item(
      id: 'a',
      signupStart: DateTime(2026, 11, 8),
      signupEnd: DateTime(2026, 11, 14, 12),
      activityStart: DateTime(2026, 11, 17),
      capacity: 0,
      enrolled: 0,
    );

    expect(opened.becameOpenFrom(full, now), isTrue);
    expect(closed.becameOpenFrom(full, now), isFalse);
    expect(full.becameOpenFrom(full, now), isFalse);
    expect(opened.becameOpenFrom(opened, now), isFalse);
    expect(unknownCapacity.becameOpenFrom(full, now), isFalse);
  });
}
