import 'schedule.dart';

String formatNum(num value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  return rounded.toStringAsFixed(1);
}

String greeting(DateTime date) {
  final hour = date.hour;
  if (hour < 5) return '夜深了';
  if (hour < 12) return '上午好';
  if (hour < 14) return '中午好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

String weekText(int week) => week < 1 ? '学期还没开始' : '第 $week 周';

String placeOf(Course course) {
  final parts = <String>[];
  if (course.room.isNotEmpty) parts.add(course.room);
  final campus = course.campus;
  if (campus != null && campus.isNotEmpty) parts.add(campus);
  return parts.join(' · ');
}

String formatSegment(Segment seg) {
  final group = seg.startName.replaceAll(RegExp(r'\d'), '');
  final startNum = seg.startName.replaceAll(RegExp(r'\D'), '');
  final endNum = seg.endName.replaceAll(RegExp(r'\D'), '');
  final span = startNum.isNotEmpty && endNum.isNotEmpty
      ? '$group $startNum–$endNum 节'
      : '${seg.startName}–${seg.endName}';
  return '${weekdayLabel[seg.weekday]} $span · ${seg.startTime}–${seg.endTime}';
}

String courseTimeText(Course course) {
  if (course.segments.isEmpty) {
    return course.sjms.isEmpty ? '无线下时间' : course.sjms;
  }
  return course.segments.map(formatSegment).join('；');
}

String categoryName(Course course) {
  if (course.category.isEmpty) return '未写入培养方案';
  return course.category.substring(1);
}
