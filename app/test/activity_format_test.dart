import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/activities/activity_format.dart';

void main() {
  test('date and clock text carries the weekday', () {
    final date = DateTime(2026, 11, 17, 13, 30);
    expect(activityDateText(date), '11月17日（周二）');
    expect(activityDateText(date, compact: true), '11/17 周二');
    expect(activityDateText(date, withYear: true), '2026年11月17日（周二）');
    expect(
      activityDateText(date, withYear: true, compact: true),
      '2026/11/17 周二',
    );
    expect(activityClockText(date), '13:30');
    expect(activityDateTimeText(date), '11月17日（周二） 13:30');
    expect(activityDateTimeText(date, compact: true), '11/17 周二 13:30');
  });

  test('same-day range writes the date once', () {
    final start = DateTime(2026, 11, 17, 13, 30);
    final end = DateTime(2026, 11, 17, 16, 30);
    expect(
      activityRangeText(start, end, compact: true),
      '11/17 周二 13:30–16:30',
    );
    expect(
      activityRangeText(start, end, withYear: true),
      '2026年11月17日（周二） 13:30–16:30',
    );
  });

  test('cross-day range keeps both weekdays and only repeats the year', () {
    final start = DateTime(2026, 11, 17, 13, 30);
    final end = DateTime(2026, 11, 18, 12);
    expect(
      activityRangeText(start, end, compact: true),
      '11/17 周二 13:30 – 11/18 周三 12:00',
    );
    expect(
      activityRangeText(start, end, withYear: true, compact: true),
      '2026/11/17 周二 13:30 – 11/18 周三 12:00',
    );
  });

  test('cross-year range repeats the year on both ends', () {
    expect(
      activityRangeText(
        DateTime(2026, 12, 31, 22),
        DateTime(2027, 1, 1, 1),
        withYear: true,
        compact: true,
      ),
      '2026/12/31 周四 22:00 – 2027/1/1 周五 01:00',
    );
  });

  test('one-sided and missing ranges are explicit', () {
    final start = DateTime(2026, 11, 17, 13, 30);
    final end = DateTime(2026, 11, 17, 16, 30);
    expect(activityRangeText(null, null), '待定');
    expect(activityRangeText(start, null), '11月17日（周二） 13:30 起');
    expect(activityRangeText(null, end), '待定 – 11月17日（周二） 16:30');
  });

  test('relative day uses calendar days, including across midnight', () {
    final now = DateTime(2026, 11, 10, 23, 30);
    expect(relativeDayText(DateTime(2026, 11, 10, 23, 59), now), '今天');
    expect(relativeDayText(DateTime(2026, 11, 11, 0, 30), now), '明天');
    expect(relativeDayText(DateTime(2026, 11, 12, 8), now), '后天');
    expect(relativeDayText(DateTime(2026, 11, 15, 8), now), '5 天后');
    expect(relativeDayText(DateTime(2026, 11, 9, 8), now), '昨天');
    expect(relativeDayText(DateTime(2026, 11, 8, 8), now), '2 天前');
  });
}
