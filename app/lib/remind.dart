import 'schedule.dart';
import 'settings.dart';

/// 前台提示。没有系统闹钟，应用不在前台时不会响。
String? foregroundRemindText({
  required AppSettings settings,
  required List<Course> courses,
  required DateTime now,
  required String termStart,
}) {
  if (!settings.reminder || settings.inQuietHours(now)) return null;
  final day = sessionsOn(courses, now, termStart);
  final hero = pickHero(day.items, now);
  if (hero.kind != 'next' && hero.kind != 'ongoing') return null;
  final item = hero.item;
  if (item == null || !settings.courseRemindOn(item.course.id)) return null;
  if (hero.kind == 'next' && hero.minutes > settings.reminderMin) return null;
  final name = item.course.name;
  if (hero.kind == 'ongoing') return '$name正在上课';
  return '$name还有 ${formatDuration(hero.minutes)}上课';
}
