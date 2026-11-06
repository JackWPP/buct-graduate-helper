import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/schedule.dart';
import 'package:huayan/snapshot.dart';

void main() {
  final raw = File('assets/snapshot.json').readAsStringSync();
  final snap = jsonDecode(raw) as Map<String, dynamic>;
  final termStart = snap['term']['start'] as String;
  final courses = (snap['courses'] as List)
      .map(
        (item) => decorateCourse(
          Course.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      )
      .toList();

  test('2026-11-03 is week 10 and that week starts on Nov 2', () {
    expect(weekIndex(DateTime(2026, 11, 3, 11, 37), termStart), 10);
    final monday = weekMonday(10, termStart);
    expect(monday.month, 11);
    expect(monday.day, 2);
  });

  test('tuesday of week 10 shows the two offline classes', () {
    final names =
        blocksForWeek(courses, 10)
            .where((block) => block.weekday == 1)
            .map((block) => block.name)
            .toList()
          ..sort();
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
    final custom = periods
        .map(
          (period) => period.n == 1
              ? period.copyWith(start: '08:05', end: '08:50')
              : period,
        )
        .toList();
    final segments = parseSjms('星期二 上午1 -上午2', custom);
    expect(segments.first.startTime, '08:05');
    expect(segments.first.endTime, '09:35');
  });

  test('bundled snapshot stays free of contact data', () {
    final credits = snap['credits'] as Map<String, dynamic>;
    final categories = credits['categories'] as List;
    final selected =
        categories.fold<num>(0, (sum, item) => sum + (item['got'] as num)) +
        (credits['orphanCredits'] as num);
    expect(selected, credits['selected']);
    expect(credits['selected'], 28);
    expect(credits['required'], 40);
    expect(credits['recorded'], 0);
    for (final key in [
      'sfzh',
      'sjhm',
      'jtdh',
      'jtdz',
      'lxdh',
      'passwd',
      'email',
    ]) {
      expect(raw.contains('"$key"'), isFalse, reason: key);
    }
    expect((snap['notices'] as List).isEmpty, isTrue);
    expect((snap['exams'] as List).isEmpty, isTrue);
  });

  test('grid geometry matches the web preview', () {
    expect(periodTop(1), 0);
    expect(periodTop(3), 102);
    expect(periodTop(5), 194);
    expect(spanHeight(3, 5), 135);
    expect(gridHeight, 582);
  });

  test('course colors stay with the course', () {
    expect(courseColor('分子探针与诊疗新技术'), '#7C5CFF');
    expect(courseColor('数值分析', {'数值分析': '#E8618C'}), '#E8618C');
    final hashed = courseColor('一门没有指定颜色的课');
    expect(coursePalette.contains(hashed), isTrue);
    expect(courseColor('一门没有指定颜色的课'), hashed);
  });

  test('duration and week progress use the same rules as the web preview', () {
    expect(formatDuration(53), '53 分钟');
    expect(formatDuration(113), '1 小时 53 分钟');
    expect(formatDuration(120), '2 小时');
    final course = decorateCourse(
      Course.fromJson(const {
        'id': 'bio',
        'name': '化学生物学导论',
        'ksz': 10,
        'jsz': 17,
        'pattern': '连续周',
        'sjms': '星期二 下午6-下午9',
      }),
    );
    final progress = weekProgress(course, 10);
    expect(progress.phase, 'current');
    expect(progress.done, 1);
    expect(progress.total, 8);
    expect(progress.remain, 7);
  });

  test('sunday column appears only when an offline class uses it', () {
    final course = decorateCourse(
      Course.fromJson(const {
        'id': 'sun',
        'name': '周日实验',
        'online': false,
        'ksz': 1,
        'jsz': 2,
        'pattern': '连续周',
        'sjms': '星期日 上午1 -上午2',
      }),
    );
    expect(visibleWeekdays([course]).contains(6), isTrue);
    expect(visibleWeekdays(courses).contains(6), isFalse);
  });

  test('snapshot periods replace the default map and empty periods do not', () {
    final custom = Snapshot.fromJson({
      'term': {'name': 't', 'start': '2026-08-31'},
      'student': {'xm': '甲', 'xh': '1'},
      'periods': [
        {
          'n': 1,
          'name': '上午1',
          'start': '08:05',
          'end': '08:50',
          'group': '上午',
        },
        {
          'n': 2,
          'name': '上午2',
          'start': '08:55',
          'end': '09:40',
          'group': '上午',
        },
      ],
      'courses': [
        {
          'id': 'a',
          'name': '数值分析',
          'online': false,
          'ksz': 1,
          'jsz': 1,
          'pattern': '连续周',
          'sjms': '星期二 上午1 -上午2',
        },
      ],
    });
    expect(custom.courses.single.segments.single.startTime, '08:05');
    expect(custom.courses.single.segments.single.endTime, '09:40');
    expect(periodsFromJson(null).first.start, '08:00');
    expect(periodsFromJson(const []).first.start, '08:00');
  });

  test('service search uses the same aliases and does not invent rows', () {
    final parsed = Snapshot.fromJson(snap);
    final exams = searchServices(parsed.services, '考场');
    expect(exams.map((hit) => hit.item.name), ['课程考场查询']);
    expect(exams.single.item.native, 'exams');
    expect(searchServices(parsed.services, '网上考试').single.item.native, isNull);
    expect(previewApplications(parsed.applications).map((item) => item.id), [
      'lwkt',
      'pyjh',
    ]);
    expect(parsed.notices, 0);
    expect(parsed.exams, 0);
  });
}
