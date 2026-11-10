import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/activities/activity_models.dart';
import 'package:huayan/planner/activity_conflict.dart';
import 'package:huayan/schedule.dart';

const _termStart = '2026-08-31';

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

ActivityItem _activity({DateTime? start, DateTime? end}) {
  return ActivityItem(
    kind: ActivityKind.academicReport,
    id: 'a',
    applicationId: '',
    title: '学术报告',
    category: '学术报告',
    publisher: '研究生院',
    organizer: '',
    location: '报告厅',
    method: '线下',
    activityStart: start,
    activityEnd: end,
    signupStart: DateTime(2026, 11, 1),
    signupEnd: DateTime(2026, 11, 20),
    capacity: 50,
    enrolled: 10,
    score: '',
    duration: '',
    auditStatus: '',
    applied: false,
  );
}

void main() {
  final now = DateTime(2026, 11, 10, 7);

  test('detects a course conflict and reports its time', () {
    final conflict = activityConflict(
      activity: _activity(
        start: DateTime(2026, 11, 10, 8, 30),
        end: DateTime(2026, 11, 10, 9),
      ),
      courses: [_course()],
      termStart: _termStart,
      now: now,
    );

    expect(conflict.hasConflict, isTrue);
    expect(conflict.courses.single.name, '数值分析');
    expect(conflict.courses.single.time, '08:00–09:35');
    expect(conflict.summary, '与《数值分析》冲突');
  });

  test('no overlap means no conflict', () {
    final conflict = activityConflict(
      activity: _activity(
        start: DateTime(2026, 11, 10, 10),
        end: DateTime(2026, 11, 10, 11),
      ),
      courses: [_course()],
      termStart: _termStart,
      now: now,
    );

    expect(conflict.hasConflict, isFalse);
    expect(conflict.summary, '与课表不冲突');
  });

  test('point time can conflict', () {
    final conflict = activityConflict(
      activity: _activity(start: DateTime(2026, 11, 10, 8, 30)),
      courses: [_course()],
      termStart: _termStart,
      now: now,
    );

    expect(conflict.hasConflict, isTrue);
  });

  test('missing course data and unknown term are explained', () {
    final noCourses = activityConflict(
      activity: _activity(
        start: DateTime(2026, 11, 10, 8, 30),
        end: DateTime(2026, 11, 10, 9),
      ),
      courses: const [],
      termStart: _termStart,
      now: now,
    );
    expect(noCourses.summary, '课表未加载，暂不判断');

    final unknownTerm = activityConflict(
      activity: _activity(
        start: DateTime(2026, 11, 10, 8, 30),
        end: DateTime(2026, 11, 10, 9),
      ),
      courses: [_course()],
      termStart: _termStart,
      now: now,
      termStartKnown: false,
    );
    expect(unknownTerm.summary, '课表周次未确认，暂不判断');
  });

  test('activity outside the term is marked', () {
    final conflict = activityConflict(
      activity: _activity(
        start: DateTime(2027, 3, 1, 8, 30),
        end: DateTime(2027, 3, 1, 9),
      ),
      courses: [_course()],
      termStart: _termStart,
      now: now,
    );

    expect(conflict.outsideTerm, isTrue);
    expect(conflict.summary, '不在本学期课表范围');
  });

  test('multi-day activity does not create false conflicts', () {
    final conflict = activityConflict(
      activity: _activity(
        start: DateTime(2026, 11, 9, 23),
        end: DateTime(2026, 11, 10, 1),
      ),
      courses: [_course()],
      termStart: _termStart,
      now: now,
    );

    expect(conflict.hasConflict, isFalse);
  });
}
