import '../schedule.dart' show weekdayLabel;

/// 活动页和本地通知共用的日期文案。
///
/// 学校的活动时间是具体日期，用户排课时按“周几”思考；这里统一把周几
/// 带在日期后面，避免页面、详情和通知各写一套格式。
String activityClockText(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String activityDateText(
  DateTime date, {
  bool withYear = false,
  bool compact = false,
}) {
  final weekday = weekdayLabel[date.weekday - 1];
  if (compact) {
    final year = withYear ? '${date.year}/' : '';
    return '$year${date.month}/${date.day} $weekday';
  }
  final year = withYear ? '${date.year}年' : '';
  return '$year${date.month}月${date.day}日（$weekday）';
}

String activityDateTimeText(
  DateTime date, {
  bool withYear = false,
  bool compact = false,
}) {
  return '${activityDateText(date, withYear: withYear, compact: compact)} '
      '${activityClockText(date)}';
}

/// 同一天只写一次日期；跨天保留两端日期；只有一端时明确“待定/起”。
String activityRangeText(
  DateTime? start,
  DateTime? end, {
  bool withYear = false,
  bool compact = false,
}) {
  if (start == null && end == null) return '待定';
  if (start == null) {
    return '待定 – ${activityDateTimeText(end!, withYear: withYear, compact: compact)}';
  }
  final startText = activityDateTimeText(
    start,
    withYear: withYear,
    compact: compact,
  );
  if (end == null) return '$startText 起';

  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) {
    return '${activityDateText(start, withYear: withYear, compact: compact)} '
        '${activityClockText(start)}–${activityClockText(end)}';
  }

  final sameYear = start.year == end.year;
  final endText = activityDateTimeText(
    end,
    withYear: withYear && !sameYear,
    compact: compact,
  );
  return '$startText – $endText';
}

/// 相对日：用日历日差，不用 24 小时差，避免跨午夜时把“明天”算成今天。
String relativeDayText(DateTime target, DateTime now) {
  final targetDate = DateTime.utc(target.year, target.month, target.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final days = targetDate.difference(today).inDays;
  if (days == 0) return '今天';
  if (days == 1) return '明天';
  if (days == 2) return '后天';
  if (days == -1) return '昨天';
  if (days < 0) return '${-days} 天前';
  return '$days 天后';
}
