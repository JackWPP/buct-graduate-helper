// 课表纯函数，与 web/js/schedule.mjs 对齐。节次时间默认同 gmis_client.DEFAULT_PERIOD_MAP。

class Period {
  const Period({
    required this.n,
    required this.name,
    required this.start,
    required this.end,
    required this.group,
  });

  final int n;
  final String name;
  final String start;
  final String end;
  final String group;

  Period copyWith({String? start, String? end}) {
    return Period(
      n: n,
      name: name,
      start: start ?? this.start,
      end: end ?? this.end,
      group: group,
    );
  }
}

const periods = <Period>[
  Period(n: 1, name: '上午1', start: '08:00', end: '08:45', group: '上午'),
  Period(n: 2, name: '上午2', start: '08:50', end: '09:35', group: '上午'),
  Period(n: 3, name: '上午3', start: '09:45', end: '10:30', group: '上午'),
  Period(n: 4, name: '上午4', start: '10:40', end: '11:25', group: '上午'),
  Period(n: 5, name: '上午5', start: '11:30', end: '12:15', group: '上午'),
  Period(n: 6, name: '下午6', start: '13:30', end: '14:15', group: '下午'),
  Period(n: 7, name: '下午7', start: '14:20', end: '15:05', group: '下午'),
  Period(n: 8, name: '下午8', start: '15:15', end: '16:00', group: '下午'),
  Period(n: 9, name: '下午9', start: '16:05', end: '16:50', group: '下午'),
  Period(n: 10, name: '晚上10', start: '18:00', end: '18:45', group: '晚上'),
  Period(n: 11, name: '晚上11', start: '18:50', end: '19:35', group: '晚上'),
  Period(n: 12, name: '晚上12', start: '19:40', end: '20:25', group: '晚上'),
];

const weekdayLabel = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

const _weekday = {
  '一': 0,
  '二': 1,
  '三': 2,
  '四': 3,
  '五': 4,
  '六': 5,
  '日': 6,
  '天': 6,
};

List<Period> asPeriods(List<Period>? value) {
  if (value == null || value.isEmpty) return periods;
  return value;
}

Map<String, Period> _periodTable(List<Period>? value) {
  return {for (final period in asPeriods(value)) period.name.trim(): period};
}

DateTime parseIsoDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime addDays(DateTime date, int days) =>
    startOfDay(date).add(Duration(days: days));

/// 第 1 周周一为 [termStart]。返回值可以小于 1 或大于学期长度。
int weekIndex(DateTime date, String termStart) {
  final start = parseIsoDate(termStart);
  final days = startOfDay(date).difference(start).inDays;
  return days ~/ 7 + 1;
}

DateTime weekMonday(int week, String termStart) {
  return addDays(parseIsoDate(termStart), (week - 1) * 7);
}

class Segment {
  const Segment({
    required this.weekday,
    required this.startName,
    required this.endName,
    required this.startPeriod,
    required this.endPeriod,
    required this.startTime,
    required this.endTime,
  });

  final int weekday;
  final String startName;
  final String endName;
  final int startPeriod;
  final int endPeriod;
  final String startTime;
  final String endTime;
}

class Course {
  const Course({
    required this.id,
    required this.name,
    required this.className,
    required this.code,
    required this.credits,
    required this.teacher,
    required this.room,
    required this.online,
    required this.ksz,
    required this.jsz,
    required this.pattern,
    required this.sjms,
    this.hours,
    this.campus,
    this.enrolled,
    this.category = '',
    this.degree = false,
    this.weeks = const [],
    this.segments = const [],
  });

  final String id;
  final String name;
  final String className;
  final String code;
  final double credits;
  final int? hours;
  final String teacher;
  final String room;
  final String? campus;
  final bool online;
  final int ksz;
  final int jsz;
  final String pattern;
  final int? enrolled;
  final String sjms;
  final String category;
  final bool degree;
  final List<int> weeks;
  final List<Segment> segments;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      className: '${json['className'] ?? ''}',
      code: '${json['code'] ?? ''}',
      credits: (json['credits'] as num?)?.toDouble() ?? 0,
      hours: (json['hours'] as num?)?.toInt(),
      teacher: '${json['teacher'] ?? ''}',
      room: '${json['room'] ?? ''}',
      campus: json['campus'] as String?,
      online: json['online'] == true,
      ksz: (json['ksz'] as num?)?.toInt() ?? 0,
      jsz: (json['jsz'] as num?)?.toInt() ?? 0,
      pattern: '${json['pattern'] ?? ''}',
      enrolled: (json['enrolled'] as num?)?.toInt(),
      sjms: '${json['sjms'] ?? ''}',
      category: '${json['category'] ?? ''}',
      degree: json['degree'] == true,
    );
  }

  Course copyWith({List<int>? weeks, List<Segment>? segments}) {
    return Course(
      id: id,
      name: name,
      className: className,
      code: code,
      credits: credits,
      hours: hours,
      teacher: teacher,
      room: room,
      campus: campus,
      online: online,
      ksz: ksz,
      jsz: jsz,
      pattern: pattern,
      enrolled: enrolled,
      sjms: sjms,
      category: category,
      degree: degree,
      weeks: weeks ?? this.weeks,
      segments: segments ?? this.segments,
    );
  }
}

List<int> courseWeeks(Course course) {
  if (course.ksz <= 0 || course.jsz < course.ksz) return const [];
  final weeks = [for (var week = course.ksz; week <= course.jsz; week++) week];
  final pattern = course.pattern.replaceAll(RegExp(r'\s'), '');
  if (pattern.contains('单周')) return weeks.where((week) => week.isOdd).toList();
  if (pattern.contains('双周')) {
    return weeks.where((week) => week.isEven).toList();
  }
  return weeks;
}

List<Segment> parseSjms(String? sjms, [List<Period>? periodList]) {
  final byName = _periodTable(periodList);
  final text = (sjms ?? '').replaceAll('，', ',');
  final re = RegExp(
    r'星期([一二三四五六日天])\s*(上午|下午|晚上)\s*(\d+)\s*[-~至]\s*(上午|下午|晚上)\s*(\d+)',
  );
  final out = <Segment>[];
  for (final match in re.allMatches(text)) {
    final startName = '${match[2]}${match[3]}';
    final endName = '${match[4]}${match[5]}';
    final start = byName[startName];
    final end = byName[endName];
    if (start == null || end == null) continue;
    out.add(
      Segment(
        weekday: _weekday[match[1]]!,
        startName: startName,
        endName: endName,
        startPeriod: start.n,
        endPeriod: end.n,
        startTime: start.start,
        endTime: end.end,
      ),
    );
  }
  return out;
}

Course decorateCourse(Course course, [List<Period>? periodList]) {
  return course.copyWith(
    weeks: courseWeeks(course),
    segments: parseSjms(course.sjms, periodList),
  );
}

/// 周日整学期都没有线下课则隐藏该列。周四即使为空也保留。
List<int> visibleWeekdays(List<Course> courses) {
  final used = <int>{};
  for (final course in courses) {
    if (course.online) continue;
    for (final seg in course.segments) {
      used.add(seg.weekday);
    }
  }
  return [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
  ].where((day) => day != 6 || used.contains(6)).toList();
}

class Block {
  const Block({
    required this.id,
    required this.courseId,
    required this.name,
    required this.room,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.startTime,
    required this.endTime,
    required this.active,
  });

  final String id;
  final String courseId;
  final String name;
  final String room;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final String startTime;
  final String endTime;
  final bool active;
}

List<Block> blocksForWeek(
  List<Course> courses,
  int week, {
  bool showOffWeek = false,
}) {
  final blocks = <Block>[];
  for (final course in courses) {
    if (course.online) continue;
    final active = course.weeks.contains(week);
    if (!active && !showOffWeek) continue;
    for (final seg in course.segments) {
      blocks.add(
        Block(
          id: '${course.id}-${seg.weekday}-${seg.startPeriod}',
          courseId: course.id,
          name: course.name,
          room: course.room,
          weekday: seg.weekday,
          startPeriod: seg.startPeriod,
          endPeriod: seg.endPeriod,
          startTime: seg.startTime,
          endTime: seg.endTime,
          active: active,
        ),
      );
    }
  }
  return blocks;
}

class Session {
  const Session({
    required this.course,
    required this.seg,
    required this.startMin,
    required this.endMin,
  });

  final Course course;
  final Segment seg;
  final int startMin;
  final int endMin;
}

class DaySessions {
  const DaySessions({
    required this.week,
    required this.weekday,
    required this.items,
  });

  final int week;
  final int weekday;
  final List<Session> items;
}

int toMinutes(String hhmm) {
  final parts = hhmm.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}

DaySessions sessionsOn(List<Course> courses, DateTime date, String termStart) {
  final week = weekIndex(date, termStart);
  final weekday = (date.weekday + 6) % 7;
  final items = <Session>[];
  for (final course in courses) {
    if (course.online) continue;
    if (!course.weeks.contains(week)) continue;
    for (final seg in course.segments) {
      if (seg.weekday != weekday) continue;
      items.add(
        Session(
          course: course,
          seg: seg,
          startMin: toMinutes(seg.startTime),
          endMin: toMinutes(seg.endTime),
        ),
      );
    }
  }
  items.sort((a, b) => a.startMin.compareTo(b.startMin));
  return DaySessions(week: week, weekday: weekday, items: items);
}

class HeroPick {
  const HeroPick({required this.kind, this.item, required this.minutes});

  final String kind;
  final Session? item;
  final int minutes;
}

HeroPick pickHero(List<Session> items, DateTime now) {
  final nowMin = now.hour * 60 + now.minute;
  for (final item in items) {
    if (nowMin >= item.startMin && nowMin < item.endMin) {
      return HeroPick(
        kind: 'ongoing',
        item: item,
        minutes: (item.endMin - nowMin).clamp(0, 1 << 30),
      );
    }
  }
  for (final item in items) {
    if (item.startMin > nowMin) {
      return HeroPick(
        kind: 'next',
        item: item,
        minutes: item.startMin - nowMin,
      );
    }
  }
  if (items.isNotEmpty) {
    return HeroPick(kind: 'done', item: items.last, minutes: 0);
  }
  return const HeroPick(kind: 'empty', minutes: 0);
}

String _icsEscape(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\n', r'\n');
}

String _pad(int n) => n.toString().padLeft(2, '0');

String _icsStamp(DateTime date) =>
    '${date.year}${_pad(date.month)}${_pad(date.day)}';

/// 只导出线下课。线上课的节次是占位，写进日历会把周五下午填满。
String buildIcs(
  List<Course> courses,
  String termStart, {
  String calendarName = '化研助手课表',
}) {
  final start0 = parseIsoDate(termStart);
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//BUCT Graduate Helper//Timetable//CN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${_icsEscape(calendarName)}',
    'X-WR-TIMEZONE:Asia/Shanghai',
    'BEGIN:VTIMEZONE',
    'TZID:Asia/Shanghai',
    'BEGIN:STANDARD',
    'DTSTART:19700101T000000',
    'TZOFFSETFROM:+0800',
    'TZOFFSETTO:+0800',
    'TZNAME:CST',
    'END:STANDARD',
    'END:VTIMEZONE',
  ];
  final now = DateTime.now().toUtc();
  final stamp =
      '${now.year}${_pad(now.month)}${_pad(now.day)}T${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}Z';
  for (final course in courses) {
    if (course.online || course.weeks.isEmpty) continue;
    final odd = course.pattern.contains('单周') || course.pattern.contains('双周');
    for (final seg in course.segments) {
      final day = addDays(start0, (course.weeks.first - 1) * 7 + seg.weekday);
      final ymd = _icsStamp(day);
      final start = seg.startTime.replaceAll(':', '');
      final end = seg.endTime.replaceAll(':', '');
      final place = [
        course.room,
        course.campus,
      ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:${course.id}-${seg.weekday}-${seg.startPeriod}@buct-graduate-helper',
        'DTSTAMP:$stamp',
        'DTSTART;TZID=Asia/Shanghai:${ymd}T${start}00',
        'DTEND;TZID=Asia/Shanghai:${ymd}T${end}00',
        'SUMMARY:${_icsEscape(course.name)}',
        'LOCATION:${_icsEscape(place)}',
        'DESCRIPTION:${_icsEscape('教师: ${course.teacher}\n周次: ${course.ksz}-${course.jsz}周\n节次: ${seg.startName}-${seg.endName}')}',
        'RRULE:FREQ=WEEKLY;INTERVAL=${odd ? 2 : 1};COUNT=${course.weeks.length}',
        'END:VEVENT',
      ]);
    }
  }
  lines.add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

/// 与 web/js/schedule.mjs 的网格几何一致。课表块按节次定位，不另写一套时间表。
const rowHeight = 46.0;
const rowGaps = <int, double>{2: 10, 5: 10, 9: 10};

double periodTop(int n) {
  var y = 0.0;
  for (var i = 1; i < n; i++) {
    y += rowHeight;
    final gap = rowGaps[i];
    if (gap != null) y += gap;
  }
  return y;
}

double spanHeight(int startPeriod, int endPeriod) {
  return periodTop(endPeriod) + rowHeight - periodTop(startPeriod) - 3;
}

final double gridHeight = periodTop(12) + rowHeight;

const coursePalette = [
  '#2F6BFF',
  '#7C5CFF',
  '#E8618C',
  '#F0853A',
  '#12A05C',
  '#0E9FB5',
  '#F0654E',
  '#7D9B2E',
];

const preferredCourseColors = <String, String>{
  '数值分析': '#2F6BFF',
  '分子探针与诊疗新技术': '#7C5CFF',
  '应用电化学': '#12A05C',
  '催化化学': '#0E9FB5',
  '化学生物学导论': '#F0853A',
  '学术英语读写': '#E8618C',
  '太阳能材料与化学': '#F0654E',
};

String courseColor(String name, [Map<String, String> overrides = const {}]) {
  final override = overrides[name];
  if (override != null && override.isNotEmpty) return override;
  final preferred = preferredCourseColors[name];
  if (preferred != null) return preferred;
  var hash = 0;
  for (final code in name.runes) {
    hash = (hash * 33 + code) % coursePalette.length;
  }
  return coursePalette[hash];
}

/// 快照里的 `periods` 优先。缺字段或空列表时退回 [periods]，不另造节次。
List<Period> periodsFromJson(Object? raw) {
  if (raw is! List || raw.isEmpty) return periods;
  final parsed = <Period>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final name = '${map['name'] ?? ''}'.trim();
    final start = '${map['start'] ?? ''}'.trim();
    final end = '${map['end'] ?? ''}'.trim();
    final n = (map['n'] as num?)?.toInt();
    if (name.isEmpty || start.isEmpty || end.isEmpty || n == null) continue;
    parsed.add(
      Period(
        n: n,
        name: name,
        start: start,
        end: end,
        group: '${map['group'] ?? ''}',
      ),
    );
  }
  return parsed.isEmpty ? periods : parsed;
}

String formatMonthDay(DateTime date) => '${date.month}月${date.day}日';

String formatDuration(num minutes) {
  final value = minutes.round() < 0 ? 0 : minutes.round();
  if (value < 60) return '$value 分钟';
  final hours = value ~/ 60;
  final remain = value % 60;
  return remain == 0 ? '$hours 小时' : '$hours 小时 $remain 分钟';
}

class WeekProgress {
  const WeekProgress({
    required this.done,
    required this.total,
    required this.remain,
    required this.phase,
  });

  final int done;
  final int total;
  final int remain;
  final String phase;
}

WeekProgress weekProgress(Course course, int week) {
  final weeks = course.weeks;
  if (weeks.isEmpty) {
    return const WeekProgress(done: 0, total: 0, remain: 0, phase: 'empty');
  }
  final total = weeks.length;
  final first = weeks.first;
  final last = weeks.last;
  if (week < first) {
    return WeekProgress(
      done: 0,
      total: total,
      remain: total,
      phase: 'upcoming',
    );
  }
  if (week > last) {
    return WeekProgress(done: total, total: total, remain: 0, phase: 'ended');
  }
  final done = weeks.where((item) => item <= week).length;
  return WeekProgress(
    done: done,
    total: total,
    remain: last - week,
    phase: 'current',
  );
}

int termMaxWeek(List<Course> courses, DateTime now, String termStart) {
  var fromCourses = 1;
  for (final course in courses) {
    if (course.jsz > fromCourses) fromCourses = course.jsz;
  }
  final current = weekIndex(now, termStart);
  var maxWeek = 20;
  if (fromCourses > maxWeek) maxWeek = fromCourses;
  if (current > maxWeek) maxWeek = current;
  if (maxWeek < 1) maxWeek = 1;
  return maxWeek;
}

int clampWeek(int week, int maxWeek) {
  if (week < 1) return 1;
  if (week > maxWeek) return maxWeek;
  return week;
}
