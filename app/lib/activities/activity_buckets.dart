import 'activity_models.dart';

/// 活动页的两个“可操作”分组。
///
/// 学校返回的列表把报名中、已满、已截止和还没开始的活动混在一起；
/// 页面按“现在能不能报名”拆开，默认页只留真正可报的。
class ActivityBuckets {
  const ActivityBuckets({
    this.open = const <ActivityItem>[],
    this.pending = const <ActivityItem>[],
  });

  /// 当前报名窗口内、还有名额。
  final List<ActivityItem> open;

  /// 还没开始报名，或名额已满但活动尚未结束。
  final List<ActivityItem> pending;

  int get total => open.length + pending.length;
}

ActivityBuckets partitionAvailableActivities(
  Iterable<ActivityItem> items,
  DateTime now,
) {
  final open = <ActivityItem>[];
  final pending = <ActivityItem>[];
  for (final item in items) {
    if (item.applied) continue;
    final phase = item.phaseAt(now);
    final ended = _hasEnded(item, now);
    switch (phase) {
      case ActivityPhase.open:
        open.add(item);
      case ActivityPhase.upcoming:
      case ActivityPhase.full:
        if (!ended) pending.add(item);
      case ActivityPhase.closed:
      case ActivityPhase.applied:
        break;
    }
  }
  open.sort(_compareOpen);
  pending.sort((a, b) => _comparePending(a, b, now));
  return ActivityBuckets(open: open, pending: pending);
}

bool _hasEnded(ActivityItem item, DateTime now) {
  final end = item.activityEnd ?? item.activityStart;
  if (end == null) return false;
  return !now.isBefore(end);
}

int _compareOpen(ActivityItem a, ActivityItem b) {
  final byDeadline = _compareTime(a.signupEnd, b.signupEnd);
  if (byDeadline != 0) return byDeadline;
  final byStart = _compareTime(a.activityStart, b.activityStart);
  if (byStart != 0) return byStart;
  return a.title.compareTo(b.title);
}

DateTime? _nextMoment(ActivityItem item, DateTime now) {
  if (item.phaseAt(now) == ActivityPhase.upcoming) {
    return item.signupStart ?? item.activityStart;
  }
  return item.activityStart ?? item.signupEnd;
}

int _comparePending(ActivityItem a, ActivityItem b, DateTime now) {
  final byMoment = _compareTime(_nextMoment(a, now), _nextMoment(b, now));
  if (byMoment != 0) return byMoment;
  final byTitle = a.title.compareTo(b.title);
  if (byTitle != 0) return byTitle;
  return a.stableKey.compareTo(b.stableKey);
}

int _compareTime(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
