import '../activities/activity_models.dart';

enum PlanItemKind { course, activity, todo }

/// 一天里的一个时间条目：课程、已报名活动、待办，或活动页里的候选人。
class PlanItem {
  const PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.location = '',
    this.startMin,
    this.endMin,
    this.allDay = false,
    this.courseId = '',
    this.sourceId = '',
    this.activityKind,
    this.done = false,
    this.candidate = false,
    this.overdue = false,
  });

  final String id;
  final PlanItemKind kind;
  final String title;
  final String subtitle;
  final String location;

  /// 从当天 00:00 起的分钟数；全天待办为 null。
  final int? startMin;
  final int? endMin;
  final bool allDay;
  final String courseId;

  /// 原始课程/活动/待办的 id，用于点击时找回完整对象。
  final String sourceId;
  final ActivityKind? activityKind;
  final bool done;

  /// 活动页里正在查看、尚未报名的活动。
  final bool candidate;
  final bool overdue;

  bool get timed => startMin != null && endMin != null && endMin! > startMin!;

  int get duration => timed ? endMin! - startMin! : 0;
}

class FreeSlot {
  const FreeSlot(this.startMin, this.endMin);

  final int startMin;
  final int endMin;

  int get minutes => endMin - startMin;

  bool get valid => minutes > 0;
}

class DayPlan {
  const DayPlan({
    required this.date,
    required this.week,
    required this.weekday,
    required this.items,
    required this.freeSlots,
    required this.isToday,
    required this.isPast,
    required this.termKnown,
    required this.hasCourseData,
  });

  final DateTime date;

  /// 从 1 开始的教学周；可能小于 1 或大于学期长度。
  final int week;

  /// 0=周一，6=周日。
  final int weekday;
  final List<PlanItem> items;
  final List<FreeSlot> freeSlots;
  final bool isToday;
  final bool isPast;
  final bool termKnown;
  final bool hasCourseData;

  int get courseCount =>
      items.where((item) => item.kind == PlanItemKind.course).length;

  int get activityCount =>
      items.where((item) => item.kind == PlanItemKind.activity).length;

  int get todoCount =>
      items.where((item) => item.kind == PlanItemKind.todo).length;

  int get pendingTodoCount => items
      .where((item) => item.kind == PlanItemKind.todo && !item.done)
      .length;

  int get doneTodoCount =>
      items.where((item) => item.kind == PlanItemKind.todo && item.done).length;

  int get freeMinutes =>
      freeSlots.fold<int>(0, (sum, slot) => sum + slot.minutes);

  bool get isEmpty => items.isEmpty;
}

class WeekPlan {
  const WeekPlan({required this.monday, required this.days});

  final DateTime monday;
  final List<DayPlan> days;

  int get activityCount =>
      days.fold<int>(0, (sum, day) => sum + day.activityCount);

  int get todoCount => days.fold<int>(0, (sum, day) => sum + day.todoCount);
}
