import '../activities/activity_models.dart';
import '../schedule.dart';
import 'todo_models.dart';

class ConflictCourse {
  const ConflictCourse({required this.name, required this.time});

  final String name;
  final String time;
}

class ActivityConflict {
  const ActivityConflict({
    this.courses = const <ConflictCourse>[],
    this.termKnown = true,
    this.hasCourseData = true,
    this.timeKnown = true,
    this.outsideTerm = false,
  });

  final List<ConflictCourse> courses;
  final bool termKnown;
  final bool hasCourseData;
  final bool timeKnown;
  final bool outsideTerm;

  bool get hasConflict => courses.isNotEmpty;

  String get summary {
    if (!timeKnown) return '时间待定，暂不判断冲突';
    if (!termKnown) return '课表周次未确认，暂不判断';
    if (!hasCourseData) return '课表未加载，暂不判断';
    if (outsideTerm) return '不在本学期课表范围';
    if (courses.isEmpty) return '与课表不冲突';
    if (courses.length == 1) return '与《${courses.first.name}》冲突';
    return '与《${courses.first.name}》等 ${courses.length} 门课冲突';
  }
}

ActivityConflict activityConflict({
  required ActivityItem activity,
  required List<Course> courses,
  required String termStart,
  required DateTime now,
  bool termStartKnown = true,
}) {
  final start = activity.activityStart;
  if (start == null) {
    return ActivityConflict(
      termKnown: termStartKnown && termStart.isNotEmpty,
      hasCourseData: courses.isNotEmpty,
      timeKnown: false,
    );
  }
  if (!termStartKnown || termStart.isEmpty) {
    return ActivityConflict(
      termKnown: false,
      hasCourseData: courses.isNotEmpty,
    );
  }
  if (courses.isEmpty) {
    return const ActivityConflict(hasCourseData: false);
  }

  final end = activity.activityEnd;
  final last = end != null && end.isAfter(start) ? end : start;
  final maxWeek = termMaxWeek(courses, now, termStart);
  final conflicts = <ConflictCourse>[];
  final seen = <String>{};
  var anyInside = false;
  var anyOutside = false;
  var date = plannerDateOnly(start);
  final lastDate = plannerDateOnly(last);
  var guard = 0;

  while (!date.isAfter(lastDate) && guard < 31) {
    guard++;
    final week = weekIndex(date, termStart);
    if (week < 1 || week > maxWeek) {
      anyOutside = true;
      date = date.add(const Duration(days: 1));
      continue;
    }
    anyInside = true;
    final sessions = sessionsOn(courses, date, termStart).items;
    if (sessions.isEmpty) {
      date = date.add(const Duration(days: 1));
      continue;
    }

    final dayEnd = date.add(const Duration(days: 1));
    final startMin = start.isBefore(date) ? 0 : start.hour * 60 + start.minute;
    int? endMin;
    if (end != null && end.isAfter(start)) {
      if (!end.isBefore(dayEnd)) {
        endMin = 24 * 60;
      } else {
        endMin = end.hour * 60 + end.minute;
      }
      if (endMin <= startMin) endMin = null;
    }

    for (final session in sessions) {
      final overlap = endMin == null
          ? startMin >= session.startMin && startMin < session.endMin
          : session.startMin < endMin && session.endMin > startMin;
      if (!overlap) continue;
      final key =
          '${session.course.id}-${session.seg.startTime}-${session.seg.endTime}';
      if (!seen.add(key)) continue;
      conflicts.add(
        ConflictCourse(
          name: session.course.name,
          time: '${session.seg.startTime}–${session.seg.endTime}',
        ),
      );
    }

    date = dayEnd;
  }

  return ActivityConflict(
    courses: conflicts,
    termKnown: true,
    hasCourseData: true,
    outsideTerm: !anyInside && anyOutside,
  );
}
