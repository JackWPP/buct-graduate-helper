import '../schedule.dart' show formatDuration, weekdayLabel;
import 'planner_models.dart';

String planClock(int minutes) {
  final value = minutes.clamp(0, 24 * 60);
  final hour = (value ~/ 60).toString().padLeft(2, '0');
  final minute = (value % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String planTimeRange(int? startMin, int? endMin) {
  if (startMin == null && endMin == null) return '全天';
  if (startMin == null) return '至 ${planClock(endMin!)}';
  if (endMin == null) return '${planClock(startMin)} 起';
  return '${planClock(startMin)}–${planClock(endMin)}';
}

String planSlotText(FreeSlot slot) =>
    '${planClock(slot.startMin)}–${planClock(slot.endMin)}';

String planSlotDuration(FreeSlot slot) => formatDuration(slot.minutes);

String planDateLabel(DateTime date) {
  final weekday = weekdayLabel[date.weekday - 1];
  return '${date.month}月${date.day}日 $weekday';
}

String planWeekday(DateTime date) => weekdayLabel[date.weekday - 1];
