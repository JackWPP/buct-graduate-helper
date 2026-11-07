import '../schedule.dart';
import '../snapshot.dart';
import '../term_calendar.dart';
import 'gmis_api.dart';
import 'gmis_exception.dart';

class SnapshotBuildResult {
  const SnapshotBuildResult({
    required this.snapshot,
    required this.termCode,
    required this.termStartKnown,
  });

  final Snapshot snapshot;
  final String termCode;
  final bool termStartKnown;
}

/// 把 GMIS 的多个接口装配成 UI 使用的 Snapshot。
/// 核心接口失败时直接抛错，次要接口失败时保留空列表，避免整页白屏。
class LiveSnapshotBuilder {
  const LiveSnapshotBuilder({required this.api, required this.calendar});

  final GmisApi api;
  final TermCalendar calendar;

  Future<SnapshotBuildResult> build({
    String? preferredTermCode,
    List<ServiceGroup> fallbackServices = const [],
  }) async {
    final terms = await api.terms();
    if (terms.isEmpty) {
      throw const GmisFormatException('学校没有返回学期列表');
    }
    final term = _pickTerm(terms, preferredTermCode);
    final termCode = '${term['termcode'] ?? ''}';
    final termName = '${term['termname'] ?? ''}';
    final termStart = calendar.resolve(termCode);
    final termStartKnown = termStart != null && termStart.isNotEmpty;
    final effectiveStart = termStart ?? _fallbackTermStart(termName);

    final results = await Future.wait<dynamic>([
      api.studentCard(),
      api.selectedCourses(termCode),
      api.trainingPlan(),
      api.selectionMeta(),
      _optional(api.grades()),
      _optional(api.evaluations()),
      _optional(api.applications()),
      _optional(api.menu()),
      _optional(api.notices()),
      _optional(api.examRooms()),
      _optional(api.courseAdjustments()),
      _optional(api.courseList(rows: 200)),
    ]);

    final card = _asMap(results[0]);
    final selected = _asList(results[1]);
    final plan = _asMap(results[2]);
    final meta = _asMap(results[3]);
    final grades = _asMap(results[4]);
    final evaluations = _asList(results[5]);
    final applications = _asList(results[6]);
    final menu = _asMap(results[7]);
    final notices = _asMap(results[8]);
    final examRooms = _asList(results[9]);
    final courseList = _asMap(results[11]);

    final periodList = periodsFromJson(meta['jc']);
    final planRows = _asList(plan['pyjh']);
    final planByCode = <String, Map<String, dynamic>>{
      for (final row in planRows)
        if ('${row['kcbh'] ?? ''}'.isNotEmpty) '${row['kcbh']}': row,
    };
    final courses = selected
        .map((row) => _courseFromRow(row, planByCode))
        .map((course) => decorateCourse(course, periodList))
        .toList();

    final credits = _creditsFrom(planRows, courses, grades);
    final services = _servicesFromMenu(menu);
    final noticeItems = _noticesFrom(notices);
    final examItems = _examsFrom(examRooms);
    final gradeItems = _gradesFrom(grades);
    final selectionCourses = _selectionCoursesFrom(courseList);

    final now = DateTime.now();
    final snapshot = Snapshot(
      schemaVersion: 2,
      source: 'GMIS 实时数据',
      updatedAt: now.toIso8601String(),
      updatedLabel:
          '${now.month}月${now.day}日 ${_two(now.hour)}:${_two(now.minute)}',
      termName: termName,
      termStart: effectiveStart,
      termCode: termCode,
      termStartKnown: termStartKnown,
      demoStudentId: '',
      campusNote: '教、科 暂按朝阳校区显示。地点没有校区字段，未识别的楼名只显示教室。',
      student: Student(
        name: '${card['xm'] ?? ''}',
        id: '${card['xh'] ?? ''}',
        college: '${card['xsmc'] ?? ''}',
        major: '${card['zymc'] ?? ''}',
        advisor: '${card['dsxm'] ?? ''}',
        grade: '${card['nj'] ?? ''}',
        kind: '${card['xslb'] ?? ''}',
      ),
      courses: courses,
      credits: credits,
      services: services.isEmpty ? fallbackServices : services,
      evaluations: evaluations
          .map(
            (row) => Evaluation(
              name: '${row['kcmc'] ?? row['name'] ?? ''}',
              teacher: '${row['jsxm'] ?? row['teacher'] ?? ''}',
              credits: _double(row['kcxf'] ?? row['credits']),
              rated: '${row['sfpj'] ?? ''}' == '1' || row['rated'] == true,
              open: '${row['yxpj'] ?? ''}' == '1' || row['open'] == true,
              code: '${row['kcbh'] ?? row['code'] ?? ''}',
              className: '${row['bjmc'] ?? row['className'] ?? ''}',
            ),
          )
          .toList(),
      applications: applications.map((row) => _applicationFrom(row)).toList(),
      grades: gradeItems,
      notices: noticeItems.length,
      exams: examItems.length,
      noticeItems: noticeItems,
      examItems: examItems,
      selectionCourses: selectionCourses,
      periods: periodList,
    );

    _validateNoForbidden(snapshot.toJson());
    return SnapshotBuildResult(
      snapshot: snapshot,
      termCode: termCode,
      termStartKnown: termStartKnown,
    );
  }

  Map<String, dynamic> _pickTerm(
    List<Map<String, dynamic>> terms,
    String? preferred,
  ) {
    if (preferred != null && preferred.isNotEmpty) {
      for (final term in terms) {
        if ('${term['termcode'] ?? ''}' == preferred) return term;
      }
    }
    for (final term in terms) {
      if (term['selected'] == true) return term;
    }
    return terms.first;
  }

  Course _courseFromRow(
    Map<String, dynamic> raw,
    Map<String, Map<String, dynamic>> planByCode,
  ) {
    final plan = planByCode['${raw['kcbh'] ?? ''}'];
    final room = '${raw['dz'] ?? ''}';
    final teacher = '${raw['rkjsxm'] ?? ''}';
    final online = room == '网络课程' || teacher == '网络课程';
    return Course(
      id: '${raw['bjid'] ?? raw['id'] ?? ''}',
      name: '${raw['kcmc'] ?? raw['name'] ?? ''}',
      className: '${raw['bjmc'] ?? raw['className'] ?? ''}',
      code: '${raw['kcbh'] ?? raw['code'] ?? ''}',
      credits: _double(raw['kcxf'] ?? raw['credits']),
      hours: (plan?['kczxs'] as num?)?.toInt(),
      teacher: teacher,
      room: room,
      campus: _campusOf(room),
      online: online,
      ksz: _int(raw['ksz']),
      jsz: _int(raw['jsz']),
      pattern: '${raw['lxfs'] ?? raw['pattern'] ?? '连续周'}',
      enrolled: (raw['xkrs'] as num?)?.toInt(),
      sjms: '${raw['sjms'] ?? ''}',
      category: '${plan?['kclbmc'] ?? ''}',
      degree: '${plan?['xwk'] ?? ''}' == '1',
    );
  }

  Credits _creditsFrom(
    List<Map<String, dynamic>> planRows,
    List<Course> courses,
    Map<String, dynamic> grades,
  ) {
    final required = <String, double>{};
    for (final row in planRows) {
      final category = '${row['kclbmc'] ?? ''}';
      if (category.isEmpty) continue;
      required[category] = (required[category] ?? 0) + _double(row['kcxf']);
    }
    final got = <String, double>{};
    final orphans = <OrphanCourse>[];
    for (final course in courses) {
      if (course.category.isNotEmpty && required.containsKey(course.category)) {
        got[course.category] = (got[course.category] ?? 0) + course.credits;
      } else {
        orphans.add(
          OrphanCourse(
            name: course.name,
            credits: course.credits,
            code: course.code,
          ),
        );
      }
    }
    final xftj = _firstMap(grades['xftj']);
    final categories = required.keys
        .map(
          (key) => CreditCategory(
            key: key,
            name: key.replaceFirst(RegExp(r'^[A-Z]'), ''),
            got: _round(got[key] ?? 0),
            need: _round(required[key] ?? 0),
          ),
        )
        .toList();
    return Credits(
      selected: _round(courses.fold(0, (sum, course) => sum + course.credits)),
      requiredCredits: _round(
        required.values.fold(0, (sum, value) => sum + value),
      ),
      categories: categories,
      orphans: orphans,
      orphanCredits: _round(
        orphans.fold(0, (sum, course) => sum + course.credits),
      ),
      recorded: _double(xftj['zxf']),
      degreeRecorded: _double(xftj['xwxf']),
      nonDegreeRecorded: _double(xftj['fxwxf']),
      degreeRequired: _double(xftj['yxxwxf']),
      nonDegreeRequired: _double(xftj['yxfxwxf']),
      gpa: _nullableDouble(xftj['zfgpa']),
      degreeGpa: _nullableDouble(xftj['xwkgpa']),
    );
  }

  List<GradeRecord> _gradesFrom(Map<String, dynamic> grades) {
    final out = <GradeRecord>[];
    for (final key in ['xwklist', 'fxwklist', 'hjcjlist']) {
      for (final row in _asList(grades[key])) {
        out.add(
          GradeRecord(
            termName: '${row['termname'] ?? row['termName'] ?? ''}',
            courseCode: '${row['kcbh'] ?? row['courseCode'] ?? ''}',
            courseName: '${row['kcmc'] ?? row['courseName'] ?? ''}',
            credits: _double(row['kcxf'] ?? row['credits']),
            score: '${row['cj'] ?? row['score'] ?? row['cjdjmc'] ?? ''}',
            gradePoint: _nullableDouble(
              row['cjdj'] ?? row['cjdjmc'] ?? row['gradePoint'],
            ),
            category: '${row['kclbmc'] ?? row['category'] ?? ''}',
            recordedAt: '${row['lrsj'] ?? row['recordedAt'] ?? ''}',
          ),
        );
      }
    }
    return out;
  }

  List<NoticeItem> _noticesFrom(Map<String, dynamic> value) {
    final rows = _asList(value['rows']);
    return rows
        .map(
          (row) => NoticeItem(
            id: '${row['id'] ?? ''}',
            title: '${row['zbt'] ?? row['title'] ?? ''}',
            publishedAt: '${row['fbrq'] ?? row['publishedAt'] ?? ''}',
            publisher: '${row['fbr'] ?? row['publisher'] ?? ''}',
            department: '${row['fbdw'] ?? row['department'] ?? ''}',
            read: row['read'] == true || '${row['isReaded'] ?? ''}' == '1',
            content: '${row['nr'] ?? row['content'] ?? row['zw'] ?? ''}',
          ),
        )
        .toList();
  }

  List<ExamItem> _examsFrom(List<Map<String, dynamic>> rows) {
    return rows
        .map(
          (row) => ExamItem(
            termName: '${row['termname'] ?? row['termName'] ?? ''}',
            courseCode: '${row['kcbh'] ?? row['courseCode'] ?? ''}',
            courseName: '${row['kcmc'] ?? row['courseName'] ?? ''}',
            room: '${row['dz'] ?? row['room'] ?? ''}',
            date: '${row['ksrq'] ?? row['date'] ?? ''}',
            startTime: '${row['kssj'] ?? row['startTime'] ?? ''}',
            seatNo: '${row['zwh'] ?? row['seatNo'] ?? ''}',
            seats: _int(row['ksrs'] ?? row['seats']),
          ),
        )
        .toList();
  }

  List<SelectionCourse> _selectionCoursesFrom(Map<String, dynamic> value) {
    return _asList(value['kc']).map((row) {
      return SelectionCourse(
        id: '${row['bjid'] ?? row['id'] ?? ''}',
        code: '${row['kcbh'] ?? row['code'] ?? ''}',
        name: '${row['kcmc'] ?? row['name'] ?? ''}',
        className: '${row['bjmc'] ?? row['className'] ?? ''}',
        teacher: '${row['rkjsxm'] ?? row['teacher'] ?? ''}',
        room: '${row['dz'] ?? row['room'] ?? ''}',
        credits: _double(row['kcxf'] ?? row['credits']),
        hours: _int(row['kczxs'] ?? row['hours']),
        weeks: '${row['ksz'] ?? ''}-${row['jsz'] ?? ''}',
        sjms: '${row['sjms'] ?? ''}',
        capacity: _int(row['rnrs'] ?? row['capacity']),
        selected: row['selected'] == true || '${row['selected'] ?? ''}' == '1',
        selectable: _int(row['yxkc']),
      );
    }).toList();
  }

  List<ServiceGroup> _servicesFromMenu(Map<String, dynamic> menu) {
    final groups = <ServiceGroup>[];
    for (final group in _asList(menu['menus'])) {
      final items = <ServiceItem>[];
      ServiceGroup? examGroup;
      for (final entry in _asList(group['menus'])) {
        final id = '${entry['menuid'] ?? ''}';
        final name = '${entry['menuname'] ?? ''}';
        final path = '${entry['url'] ?? ''}';
        if (id == 'wskscp') {
          examGroup = ServiceGroup(
            id: 'wsks',
            name: '网上考试',
            items: [
              ServiceItem(id: id, name: name, path: path, native: 'online'),
            ],
          );
          continue;
        }
        items.add(
          ServiceItem(
            id: id,
            name: name,
            path: path,
            native: _nativeForPath(path) ?? id,
          ),
        );
      }
      if (items.isNotEmpty) {
        groups.add(
          ServiceGroup(
            id: '${group['menuid'] ?? ''}',
            name: '${group['menuname'] ?? ''}',
            items: items,
          ),
        );
      }
      if (examGroup != null) groups.add(examGroup);
    }
    return groups;
  }

  String? _nativeForPath(String path) {
    final clean = path.split('?').first.replaceAll(RegExp(r'/+$'), '');
    const native = {
      '/student/pygl/xskbcx': 'timetable',
      '/student/pygl/xscjcx': 'grades',
      '/student/pygl/xswsxk_kb': 'selected',
      '/student/pygl/xswsxk': 'catalog',
      '/student/pygl/qxkczml': 'catalog',
      '/student/pygl/xkjgcx': 'selected',
      '/student/pygl/pyjhtj': 'progress',
      '/student/pygl/wsjxpj': 'eval',
      '/student/pygl/pyjhcx': 'progress',
      '/student/pygl/pyfacx': 'progress',
      '/student/pygl/kckccx': 'exams',
      '/student/pygl/ttkcx': 'exams',
      '/student/grgl/xsxx': 'profile',
      '/student/grgl/xyjc': 'progress',
    };
    return native[clean];
  }

  ApplicationItem _applicationFrom(Map<String, dynamic> row) {
    final steps = _asList(row['shlbz']);
    String label = '状态未知';
    String tone = 'muted';
    String time = '';
    if (steps.isNotEmpty) {
      final first = steps.first;
      final approved = steps.where((step) => '${step['shlzt'] ?? ''}' == '1');
      if ('${first['shlmc'] ?? ''}' == '未提交') {
        label = '未提交';
        tone = 'amber';
      } else if (approved.isNotEmpty) {
        final last = approved.last;
        label = '${last['shlmc'] ?? '审核'}已通过';
        tone = 'ok';
        time = '${last['shsj'] ?? ''}';
      } else {
        label = '${first['shlmc'] ?? '进行中'}';
        time = '${first['shsj'] ?? ''}';
      }
    }
    return ApplicationItem(
      id: '${row['dm'] ?? ''}',
      name: '${row['mc'] ?? ''}',
      label: label,
      tone: tone,
      time: time,
    );
  }

  String _fallbackTermStart(String termName) {
    if (termName.contains('2026-2027') && termName.contains('秋')) {
      return '2026-08-31';
    }
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  String? _campusOf(String room) {
    if (room.isEmpty || room == '网络课程') return null;
    if (room.startsWith('教') || room.startsWith('科')) return '朝阳校区';
    return null;
  }

  Future<dynamic> _optional(Future<dynamic> future) async {
    try {
      return await future;
    } on GmisAuthException {
      // 会话过期/公钥失效必须让 AppController 处理，不能伪装成空列表。
      rethrow;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  Map<String, dynamic> _firstMap(dynamic value) {
    final list = _asList(value);
    return list.isEmpty ? const {} : list.first;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  double? _nullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  double _round(double value) => (value * 10).roundToDouble() / 10;

  String _two(int value) => value.toString().padLeft(2, '0');

  void _validateNoForbidden(Map<String, dynamic> value) {
    const forbidden = {
      'sfzh',
      'zjhm',
      'sfzjh',
      'sjhm',
      'jtdh',
      'jtdz',
      'lxdh',
      'email',
      'dzyx',
      'passwd',
      'password',
      'pwd',
      'cookie',
      'cookies',
      'vericode',
      'yzm',
      'captcha',
    };
    String? check(dynamic node) {
      if (node is Map) {
        for (final entry in node.entries) {
          if (forbidden.contains('${entry.key}'.toLowerCase())) {
            return '${entry.key}';
          }
          final found = check(entry.value);
          if (found != null) return found;
        }
      } else if (node is List) {
        for (final item in node) {
          final found = check(item);
          if (found != null) return found;
        }
      }
      return null;
    }

    final found = check(value);
    if (found != null) {
      throw GmisApiException('快照含有不允许写入的字段: $found');
    }
  }
}
