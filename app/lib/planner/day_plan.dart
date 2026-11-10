import 'dart:math' as math;

import '../activities/activity_models.dart';
import '../schedule.dart';
import 'planner_models.dart';
import 'todo_models.dart';

/// 一天的空闲建议窗口。集中在这里，后续要调午饭/晚课边界只改常量。
const plannerDayStartMin = 8 * 60;
const plannerDayEndMin = 22 * 60;
const plannerMinFreeMinutes = 30;

DayPlan buildDayPlan({
  required DateTime date,
  required List<Course> courses,
  required String termStart,
  required DateTime now,
  List<ActivityItem> activities = const <ActivityItem>[],
  List<TodoItem> todos = const <TodoItem>[],
  ActivityItem? candidate,
  bool termStartKnown = true,
}) {
  final day = plannerDateOnly(date);
  final today = plannerDateOnly(now);
  final isToday = _sameDay(day, now);
  final isPast = day.isBefore(today);
  final hasTerm = termStart.isNotEmpty;
  final week = hasTerm ? weekIndex(day, termStart) : 0;
  final weekday = (day.weekday + 6) % 7;
  final items = <PlanItem>[];

  if (hasTerm && courses.isNotEmpty) {
    final sessions = sessionsOn(courses, day, termStart);
    for (final session in sessions.items) {
      final course = session.course;
      items.add(
        PlanItem(
          id: 'course-${course.id}-${session.seg.weekday}-${session.seg.startPeriod}',
          kind: PlanItemKind.course,
          title: course.name,
          subtitle: course.teacher,
          location: course.room,
          startMin: session.startMin,
          endMin: session.endMin,
          courseId: course.id,
          sourceId: course.id,
        ),
      );
    }
  }

  for (final activity in activities) {
    final item = _activityItem(activity, day, candidate: false);
    if (item != null) items.add(item);
  }
  if (candidate != null) {
    final item = _activityItem(candidate, day, candidate: true);
    if (item != null) items.add(item);
  }

  for (final todo in todos) {
    if (!_sameDay(todo.day, day)) continue;
    final timed = todo.timed;
    items.add(
      PlanItem(
        id: 'todo-${todo.id}',
        kind: PlanItemKind.todo,
        title: todo.title,
        subtitle: [
          if (_courseName(courses, todo.courseId).isNotEmpty)
            _courseName(courses, todo.courseId),
          if (todo.note.isNotEmpty) todo.note,
        ].join(' · '),
        startMin: timed ? todo.startMin : null,
        endMin: timed ? todo.endMin : null,
        allDay: !timed,
        courseId: todo.courseId,
        sourceId: todo.id,
        done: todo.done,
        overdue: !todo.done && todo.day.isBefore(today),
      ),
    );
  }

  items.sort(_compareItems);

  final busy = <({int start, int end})>[];
  for (final item in items) {
    if (!item.timed) continue;
    if (item.kind == PlanItemKind.todo && item.done) continue;
    busy.add((start: item.startMin!, end: item.endMin!));
  }

  var windowStart = plannerDayStartMin;
  if (isToday) {
    final nowMin = now.hour * 60 + now.minute;
    final rounded = ((nowMin + 4) ~/ 5) * 5;
    windowStart = math.max(plannerDayStartMin, rounded);
  }
  final freeSlots = isPast || windowStart >= plannerDayEndMin
      ? const <FreeSlot>[]
      : _freeSlots(busy, windowStart, plannerDayEndMin);

  return DayPlan(
    date: day,
    week: week,
    weekday: weekday,
    items: items,
    freeSlots: freeSlots,
    isToday: isToday,
    isPast: isPast,
    termKnown: termStartKnown && hasTerm,
    hasCourseData: courses.isNotEmpty,
  );
}

WeekPlan buildWeekPlan({
  required DateTime monday,
  required List<Course> courses,
  required String termStart,
  required DateTime now,
  List<ActivityItem> activities = const <ActivityItem>[],
  List<TodoItem> todos = const <TodoItem>[],
  bool termStartKnown = true,
}) {
  final start = plannerDateOnly(monday);
  return WeekPlan(
    monday: start,
    days: [
      for (var index = 0; index < 7; index++)
        buildDayPlan(
          date: start.add(Duration(days: index)),
          courses: courses,
          termStart: termStart,
          now: now,
          activities: activities,
          todos: todos,
          termStartKnown: termStartKnown,
        ),
    ],
  );
}

PlanItem? _activityItem(
  ActivityItem activity,
  DateTime day, {
  required bool candidate,
}) {
  final start = activity.activityStart;
  if (start == null) return null;
  final end = activity.activityEnd;
  final nextDay = day.add(const Duration(days: 1));
  if (!start.isBefore(nextDay)) return null;
  if (end != null && !end.isAfter(day)) return null;
  if (end != null && end.isBefore(start)) {
    // 学校字段异常时按“只有开始时间”处理，不生成负区间。
    return _activityItemWithEnd(
      activity,
      day,
      start,
      null,
      candidate: candidate,
    );
  }
  return _activityItemWithEnd(activity, day, start, end, candidate: candidate);
}

PlanItem _activityItemWithEnd(
  ActivityItem activity,
  DateTime day,
  DateTime start,
  DateTime? end, {
  required bool candidate,
}) {
  final startMin = start.isBefore(day) ? 0 : start.hour * 60 + start.minute;
  int? endMin;
  if (end != null) {
    final nextDay = day.add(const Duration(days: 1));
    if (end.isAfter(nextDay) || end.isAtSameMomentAs(nextDay)) {
      endMin = 24 * 60;
    } else {
      endMin = end.hour * 60 + end.minute;
    }
    if (endMin <= startMin) endMin = null;
  }
  return PlanItem(
    id: '${activity.stableKey}-${candidate ? 'candidate' : 'activity'}',
    kind: PlanItemKind.activity,
    title: activity.title.isEmpty ? '未命名活动' : activity.title,
    subtitle: activity.kind.label,
    location: activity.location,
    startMin: startMin,
    endMin: endMin,
    courseId: '',
    sourceId: activity.stableKey,
    activityKind: activity.kind,
    candidate: candidate,
  );
}

String _courseName(List<Course> courses, String courseId) {
  if (courseId.isEmpty) return '';
  for (final course in courses) {
    if (course.id == courseId) return course.name;
  }
  return '';
}

int _compareItems(PlanItem a, PlanItem b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  final aStart = a.startMin;
  final bStart = b.startMin;
  if (aStart == null && bStart != null) return -1;
  if (aStart != null && bStart == null) return 1;
  if (aStart != null && bStart != null && aStart != bStart) {
    return aStart.compareTo(bStart);
  }
  final byKind = a.kind.index.compareTo(b.kind.index);
  if (byKind != 0) return byKind;
  return a.title.compareTo(b.title);
}

List<FreeSlot> _freeSlots(
  List<({int start, int end})> busy,
  int windowStart,
  int windowEnd,
) {
  final intervals = <({int start, int end})>[];
  for (final item in busy) {
    final start = math.max(item.start, windowStart);
    final end = math.min(item.end, windowEnd);
    if (end > start) intervals.add((start: start, end: end));
  }
  intervals.sort((a, b) => a.start.compareTo(b.start));

  final slots = <FreeSlot>[];
  var cursor = windowStart;
  for (final interval in intervals) {
    if (interval.start > cursor) {
      final end = math.min(interval.start, windowEnd);
      if (end - cursor >= plannerMinFreeMinutes) {
        slots.add(FreeSlot(cursor, end));
      }
    }
    if (interval.end > cursor) cursor = interval.end;
    if (cursor >= windowEnd) break;
  }
  if (windowEnd - cursor >= plannerMinFreeMinutes) {
    slots.add(FreeSlot(cursor, windowEnd));
  }
  return slots;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
