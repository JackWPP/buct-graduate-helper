import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/schedule.dart';

void main() {
  final raw = File('../web/data/snapshot.json').readAsStringSync();
  final snap = jsonDecode(raw) as Map<String, dynamic>;
  final termStart = snap['term']['start'] as String;
  final courses = (snap['courses'] as List)
      .map((item) => decorateCourse(Course.fromJson(Map<String, dynamic>.from(item as Map))))
      .toList();

  test('2026-11-03 is week 10 and that week starts on Nov 2', () {
    expect(weekIndex(DateTime(2026, 11, 3, 11, 37), termStart), 10);
    final monday = weekMonday(10, termStart);
    expect(monday.month, 11);
    expect(monday.day, 2);
  });

  test('tuesday of week 10 shows the two offline classes', () {
    final names = blocksForWeek(courses, 10).where((block) => block.weekday == 1).map((block) => block.name).toList()..sort();
    expect(names, ['化学生物学导论', '数值分析']);
  });

  test('online courses stay off the grid and sunday is hidden', () {
    final blocks = blocksForWeek(courses, 10, showOffWeek: true);
    expect(blocks.any((block) => block.name.contains('科研伦理')), isFalse);
    expect(courses.where((course) => course.online).length, 7);
    expect(visibleWeekdays(courses).contains(6), isFalse);
    expect(visibleWeekdays(courses).contains(3), isTrue);
  });

  test('numeric analysis splits across tuesday morning and saturday', () {
    final course = courses.firstWhere((item) => item.name == '数值分析');
    final segments = parseSjms(course.sjms);
    expect(segments.length, 2);
    expect(segments.map((seg) => seg.weekday).toList(), [1, 5]);
    expect(segments[0].startTime, '08:00');
    expect(segments[0].endTime, '09:35');
  });

  test('at 11:37 the next class is chemical biology', () {
    final now = DateTime(2026, 11, 3, 11, 37);
    final day = sessionsOn(courses, now, termStart);
    final hero = pickHero(day.items, now);
    expect(hero.kind, 'next');
    expect(hero.item!.course.name, '化学生物学导论');
    expect(hero.item!.seg.startTime, '13:30');
  });

  test('ics exports offline courses only', () {
    final ics = buildIcs(courses, termStart);
    expect(ics, contains('SUMMARY:催化化学'));
    expect(ics, contains('RRULE:FREQ=WEEKLY'));
    expect(ics.contains('科研伦理'), isFalse);
    expect(ics.contains('英文科技论文'), isFalse);
  });

  test('parseSjms uses period times supplied with the snapshot', () {
    final custom = periods.map((period) => period.n == 1 ? period.copyWith(start: '08:05', end: '08:50') : period).toList();
    final segments = parseSjms('星期二 上午1 -上午2', custom);
    expect(segments.first.startTime, '08:05');
    expect(segments.first.endTime, '09:35');
  });

  test('bundled snapshot stays free of contact data', () {
    final credits = snap['credits'] as Map<String, dynamic>;
    final categories = credits['categories'] as List;
    final selected = categories.fold<num>(0, (sum, item) => sum + (item['got'] as num)) + (credits['orphanCredits'] as num);
    expect(selected, credits['selected']);
    expect(credits['selected'], 28);
    expect(credits['required'], 40);
    expect(credits['recorded'], 0);
    for (final key in ['sfzh', 'sjhm', 'jtdh', 'jtdz', 'lxdh', 'passwd', 'email']) {
      expect(raw.contains('"$key"'), isFalse, reason: key);
    }
    expect((snap['notices'] as List).isEmpty, isTrue);
    expect((snap['exams'] as List).isEmpty, isTrue);
  });
}
