import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/activities/activity_models.dart';
import 'package:huayan/planner/day_plan.dart';
import 'package:huayan/planner/todo_models.dart';
import 'package:huayan/schedule.dart';

const _termStart = '2026-08-31';

Course _course({
  required String id,
  required String name,
  required String sjms,
  List<int> weeks = const [],
  bool online = false,
}) {
  final course = Course.fromJson({
    'id': id,
    'name': name,
    'className': '1班',
    'code': id,
    'credits': 3,
    'teacher': '老师',
    'room': '科303',
    'online': online,
    'ksz': weeks.isEmpty ? 1 : weeks.first,
    'jsz': weeks.isEmpty ? 20 : weeks.last,
    'pattern': '连续周',
    'sjms': sjms,
  });
  return decorateCourse(course);
}

ActivityItem _activity({
  String id = 'a',
  String title = '学术报告',
  DateTime? start,
  DateTime? end,
  bool applied = true,
}) {
  return ActivityItem(
    kind: ActivityKind.academicReport,
    id: id,
    applicationId: applied ? 'hd-$id' : '',
    title: title,
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
    applied: applied,
  );
}

TodoItem _todo({
  String id = 't',
  String title = '交作业',
  String date = '2026-11-10',
  int? start,
  int? end,
  bool done = false,
}) {
  return TodoItem(
    id: id,
    title: title,
    date: date,
    startMin: start,
    endMin: end,
    done: done,
    createdAt: 0,
  );
}

void main() {
  final tuesday = DateTime(2026, 11, 10);
  final courses = [
    _course(id: 'a', name: '数值分析', sjms: '星期二 上午1 -上午2'),
    _course(id: 'b', name: '催化化学', sjms: '星期二 下午6 -下午7'),
  ];

  test('free slots sit between Tuesday classes', () {
    final plan = buildDayPlan(
      date: tuesday,
      courses: courses,
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 7),
    );

    expect(plan.week, 11);
    expect(plan.weekday, 1);
    expect(plan.courseCount, 2);
    expect(plan.freeSlots.map((slot) => '${slot.startMin}-${slot.endMin}'), [
      '575-810',
      '905-1320',
    ]);
  });

  test('today starts free time from now, past days have no suggestions', () {
    final today = buildDayPlan(
      date: tuesday,
      courses: courses,
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 14),
    );
    expect(today.freeSlots.map((slot) => '${slot.startMin}-${slot.endMin}'), [
      '905-1320',
    ]);

    final past = buildDayPlan(
      date: DateTime(2026, 11, 9),
      courses: courses,
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 14),
    );
    expect(past.isPast, isTrue);
    expect(past.freeSlots, isEmpty);
  });

  test('online and off-week courses do not block free time', () {
    final plan = buildDayPlan(
      date: tuesday,
      courses: [
        _course(id: 'online', name: '线上课', sjms: '星期二 上午1 -上午2', online: true),
        _course(
          id: 'later',
          name: '第 20 周才上',
          sjms: '星期二 上午1 -上午2',
          weeks: [20],
        ),
      ],
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 7),
    );

    expect(plan.courseCount, 0);
    expect(plan.freeSlots.single.startMin, plannerDayStartMin);
    expect(plan.freeSlots.single.endMin, plannerDayEndMin);
  });

  test('applied activity and candidate both occupy their time', () {
    final activity = _activity(
      start: DateTime(2026, 11, 10, 10),
      end: DateTime(2026, 11, 10, 11),
    );
    final plan = buildDayPlan(
      date: tuesday,
      courses: courses,
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 7),
      activities: [activity],
      candidate: _activity(
        id: 'candidate',
        title: '候选报告',
        start: DateTime(2026, 11, 10, 12),
        end: DateTime(2026, 11, 10, 13),
        applied: false,
      ),
    );

    expect(plan.activityCount, 2);
    expect(plan.items.where((item) => item.candidate), hasLength(1));
    expect(plan.freeSlots.map((slot) => '${slot.startMin}-${slot.endMin}'), [
      '660-720',
      '780-810',
      '905-1320',
    ]);
  });

  test('timed todos block time only when incomplete', () {
    final plan = buildDayPlan(
      date: tuesday,
      courses: const [],
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 7),
      todos: [
        _todo(start: 9 * 60, end: 10 * 60),
        _todo(id: 'done', start: 11 * 60, end: 12 * 60, done: true),
        _todo(id: 'all-day'),
      ],
    );

    expect(plan.todoCount, 3);
    expect(plan.pendingTodoCount, 2);
    expect(plan.doneTodoCount, 1);
    expect(plan.items.first.allDay, isTrue);
    expect(plan.freeSlots.map((slot) => '${slot.startMin}-${slot.endMin}'), [
      '480-540',
      '600-1320',
    ]);
  });

  test('multi-day activity, missing end and invalid end are tolerated', () {
    final multi = buildDayPlan(
      date: tuesday,
      courses: const [],
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 7),
      activities: [
        _activity(
          start: DateTime(2026, 11, 9, 23),
          end: DateTime(2026, 11, 10, 1),
        ),
      ],
    );
    expect(multi.activityCount, 1);
    expect(multi.items.single.startMin, 0);
    expect(multi.items.single.endMin, 60);
    expect(multi.freeSlots.single.startMin, plannerDayStartMin);

    final point = buildDayPlan(
      date: tuesday,
      courses: const [],
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 7),
      activities: [_activity(start: DateTime(2026, 11, 10, 10))],
    );
    expect(point.activityCount, 1);
    expect(point.items.single.timed, isFalse);
    expect(point.freeSlots.single.startMin, plannerDayStartMin);

    final invalid = buildDayPlan(
      date: tuesday,
      courses: const [],
      termStart: _termStart,
      now: DateTime(2026, 11, 10, 7),
      activities: [
        _activity(
          start: DateTime(2026, 11, 10, 10),
          end: DateTime(2026, 11, 10, 9),
        ),
      ],
    );
    expect(invalid.activityCount, 1);
    expect(invalid.items.single.timed, isFalse);
  });

  test('week plan builds seven days with counts', () {
    final week = buildWeekPlan(
      monday: DateTime(2026, 11, 9),
      courses: courses,
      termStart: _termStart,
      now: tuesday,
      activities: [
        _activity(
          start: DateTime(2026, 11, 10, 10),
          end: DateTime(2026, 11, 10, 11),
        ),
      ],
      todos: [_todo(date: '2026-11-11')],
    );

    expect(week.days, hasLength(7));
    expect(week.days.first.weekday, 0);
    expect(week.days[1].weekday, 1);
    expect(week.activityCount, 1);
    expect(week.todoCount, 1);
  });

  test('missing term start does not crash and is marked unknown', () {
    final plan = buildDayPlan(
      date: tuesday,
      courses: courses,
      termStart: '',
      now: tuesday,
    );
    expect(plan.termKnown, isFalse);
    expect(plan.week, 0);
    expect(plan.courseCount, 0);
  });
}
