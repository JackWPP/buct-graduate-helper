import 'schedule.dart';

class Student {
  const Student({
    required this.name,
    required this.id,
    this.college = '',
    this.major = '',
    this.advisor = '',
    this.grade = '',
    this.kind = '',
  });

  final String name;
  final String id;
  final String college;
  final String major;
  final String advisor;
  final String grade;
  final String kind;

  factory Student.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return Student(
      name: '${map['xm'] ?? ''}',
      id: '${map['xh'] ?? ''}',
      college: '${map['college'] ?? ''}',
      major: '${map['major'] ?? ''}',
      advisor: '${map['advisor'] ?? ''}',
      grade: '${map['grade'] ?? ''}',
      kind: '${map['kind'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'xm': name,
    'xh': id,
    'college': college,
    'major': major,
    'advisor': advisor,
    'grade': grade,
    'kind': kind,
  };
}

class CreditCategory {
  const CreditCategory({
    required this.name,
    required this.got,
    required this.need,
    this.key = '',
  });

  final String name;
  final double got;
  final double need;
  final String key;

  factory CreditCategory.fromJson(Map<String, dynamic> json) {
    return CreditCategory(
      name: '${json['name'] ?? ''}',
      got: (json['got'] as num?)?.toDouble() ?? 0,
      need: (json['need'] as num?)?.toDouble() ?? 0,
      key: '${json['key'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'got': got,
    'need': need,
  };
}

class OrphanCourse {
  const OrphanCourse({
    required this.name,
    required this.credits,
    required this.code,
  });

  final String name;
  final double credits;
  final String code;

  factory OrphanCourse.fromJson(Map<String, dynamic> json) {
    return OrphanCourse(
      name: '${json['name'] ?? ''}',
      credits: (json['credits'] as num?)?.toDouble() ?? 0,
      code: '${json['code'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'credits': credits,
    'code': code,
  };
}

class Credits {
  const Credits({
    required this.selected,
    required this.requiredCredits,
    this.categories = const [],
    this.orphans = const [],
    this.orphanCredits = 0,
    this.recorded = 0,
    this.degreeRecorded = 0,
    this.nonDegreeRecorded = 0,
    this.degreeRequired = 0,
    this.nonDegreeRequired = 0,
    this.gpa,
    this.degreeGpa,
  });

  final double selected;
  final double requiredCredits;
  final List<CreditCategory> categories;
  final List<OrphanCourse> orphans;
  final double orphanCredits;
  final double recorded;
  final double degreeRecorded;
  final double nonDegreeRecorded;
  final double degreeRequired;
  final double nonDegreeRequired;
  final double? gpa;
  final double? degreeGpa;

  factory Credits.fromJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List? ?? const [])
        .map(
          (item) =>
              CreditCategory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final orphans = (json['orphans'] as List? ?? const [])
        .map(
          (item) =>
              OrphanCourse.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return Credits(
      selected: (json['selected'] as num?)?.toDouble() ?? 0,
      requiredCredits: (json['required'] as num?)?.toDouble() ?? 0,
      categories: categories,
      orphans: orphans,
      orphanCredits: (json['orphanCredits'] as num?)?.toDouble() ?? 0,
      recorded: (json['recorded'] as num?)?.toDouble() ?? 0,
      degreeRecorded: (json['degreeRecorded'] as num?)?.toDouble() ?? 0,
      nonDegreeRecorded: (json['nonDegreeRecorded'] as num?)?.toDouble() ?? 0,
      degreeRequired: (json['degreeRequired'] as num?)?.toDouble() ?? 0,
      nonDegreeRequired: (json['nonDegreeRequired'] as num?)?.toDouble() ?? 0,
      gpa: (json['gpa'] as num?)?.toDouble(),
      degreeGpa: (json['degreeGpa'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'selected': selected,
    'required': requiredCredits,
    'categories': categories.map((item) => item.toJson()).toList(),
    'orphans': orphans.map((item) => item.toJson()).toList(),
    'orphanCredits': orphanCredits,
    'recorded': recorded,
    'degreeRecorded': degreeRecorded,
    'nonDegreeRecorded': nonDegreeRecorded,
    'degreeRequired': degreeRequired,
    'nonDegreeRequired': nonDegreeRequired,
    'gpa': gpa,
    'degreeGpa': degreeGpa,
  };
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.path,
    this.native,
  });

  final String id;
  final String name;
  final String path;
  final String? native;

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final native = json['native'];
    return ServiceItem(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      path: '${json['path'] ?? ''}',
      native: native == null || '$native'.isEmpty ? null : '$native',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'native': native,
  };
}

class ServiceGroup {
  const ServiceGroup({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<ServiceItem> items;

  factory ServiceGroup.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .map(
          (item) =>
              ServiceItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return ServiceGroup(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      items: items,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class Evaluation {
  const Evaluation({
    required this.name,
    required this.teacher,
    required this.credits,
    required this.rated,
    required this.open,
    this.code = '',
    this.className = '',
  });

  final String name;
  final String teacher;
  final double credits;
  final bool rated;
  final bool open;
  final String code;
  final String className;

  factory Evaluation.fromJson(Map<String, dynamic> json) {
    return Evaluation(
      name: '${json['name'] ?? ''}',
      teacher: '${json['teacher'] ?? ''}',
      credits: (json['credits'] as num?)?.toDouble() ?? 0,
      rated: json['rated'] == true,
      open: json['open'] == true,
      code: '${json['code'] ?? ''}',
      className: '${json['className'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'teacher': teacher,
    'credits': credits,
    'rated': rated,
    'open': open,
    'code': code,
    'className': className,
  };
}

class ApplicationItem {
  const ApplicationItem({
    required this.id,
    required this.name,
    required this.label,
    required this.tone,
    required this.time,
  });

  final String id;
  final String name;
  final String label;
  final String tone;
  final String time;

  factory ApplicationItem.fromJson(Map<String, dynamic> json) {
    return ApplicationItem(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      label: '${json['label'] ?? ''}',
      tone: '${json['tone'] ?? ''}',
      time: '${json['time'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'label': label,
    'tone': tone,
    'time': time,
  };
}

/// 一条成绩。成绩的原始值是字符串，等级成绩（优秀/良好）不转数字。
class GradeRecord {
  const GradeRecord({
    required this.termName,
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.score,
    this.gradePoint,
    this.category = '',
    this.recordedAt = '',
  });

  final String termName;
  final String courseCode;
  final String courseName;
  final double credits;
  final String score;
  final double? gradePoint;
  final String category;
  final String recordedAt;

  factory GradeRecord.fromJson(Map<String, dynamic> json) {
    return GradeRecord(
      termName: '${json['termName'] ?? json['termname'] ?? ''}',
      courseCode: '${json['courseCode'] ?? json['kcbh'] ?? ''}',
      courseName: '${json['courseName'] ?? json['kcmc'] ?? ''}',
      credits: (json['credits'] as num?)?.toDouble() ?? 0,
      score: '${json['score'] ?? json['cj'] ?? ''}',
      gradePoint: (json['gradePoint'] as num?)?.toDouble(),
      category: '${json['category'] ?? ''}',
      recordedAt: '${json['recordedAt'] ?? json['lrsj'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'termName': termName,
    'courseCode': courseCode,
    'courseName': courseName,
    'credits': credits,
    'score': score,
    'gradePoint': gradePoint,
    'category': category,
    'recordedAt': recordedAt,
  };
}

class ExamItem {
  const ExamItem({
    required this.termName,
    required this.courseCode,
    required this.courseName,
    required this.room,
    required this.date,
    required this.startTime,
    this.seatNo = '',
    this.seats,
  });

  final String termName;
  final String courseCode;
  final String courseName;
  final String room;
  final String date;
  final String startTime;
  final String seatNo;
  final int? seats;

  factory ExamItem.fromJson(Map<String, dynamic> json) {
    return ExamItem(
      termName: '${json['termName'] ?? json['termname'] ?? ''}',
      courseCode: '${json['courseCode'] ?? json['kcbh'] ?? ''}',
      courseName: '${json['courseName'] ?? json['kcmc'] ?? ''}',
      room: '${json['room'] ?? json['dz'] ?? ''}',
      date: '${json['date'] ?? json['ksrq'] ?? ''}',
      startTime: '${json['startTime'] ?? json['kssj'] ?? ''}',
      seatNo: '${json['seatNo'] ?? json['zwh'] ?? ''}',
      seats: (json['seats'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'termName': termName,
    'courseCode': courseCode,
    'courseName': courseName,
    'room': room,
    'date': date,
    'startTime': startTime,
    'seatNo': seatNo,
    'seats': seats,
  };
}

class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.title,
    this.publishedAt = '',
    this.publisher = '',
    this.department = '',
    this.read = false,
  });

  final String id;
  final String title;
  final String publishedAt;
  final String publisher;
  final String department;
  final bool read;

  factory NoticeItem.fromJson(Map<String, dynamic> json) {
    return NoticeItem(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? json['zbt'] ?? ''}',
      publishedAt: '${json['publishedAt'] ?? json['fbrq'] ?? ''}',
      publisher: '${json['publisher'] ?? json['fbr'] ?? ''}',
      department: '${json['department'] ?? json['fbdw'] ?? ''}',
      read: json['read'] == true || '${json['isReaded'] ?? ''}' == '1',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'publishedAt': publishedAt,
    'publisher': publisher,
    'department': department,
    'read': read,
  };
}

/// 选课列表里的一门课。和课表里的 Course 分开：它可能还没选。
class SelectionCourse {
  const SelectionCourse({
    required this.id,
    required this.code,
    required this.name,
    this.className = '',
    this.teacher = '',
    this.room = '',
    this.credits = 0,
    this.hours,
    this.weeks = '',
    this.sjms = '',
    this.capacity,
    this.selected = false,
    this.selectable = 0,
  });

  final String id;
  final String code;
  final String name;
  final String className;
  final String teacher;
  final String room;
  final double credits;
  final int? hours;
  final String weeks;
  final String sjms;
  final int? capacity;
  final bool selected;

  /// 0=可选，1=已选，2=可退选。
  final int selectable;

  factory SelectionCourse.fromJson(Map<String, dynamic> json) {
    final selected = json['selected'] == true || '${json['selected']}' == '1';
    return SelectionCourse(
      id: '${json['id'] ?? json['bjid'] ?? ''}',
      code: '${json['code'] ?? json['kcbh'] ?? ''}',
      name: '${json['name'] ?? json['kcmc'] ?? ''}',
      className: '${json['className'] ?? json['bjmc'] ?? ''}',
      teacher: '${json['teacher'] ?? json['rkjsxm'] ?? ''}',
      room: '${json['room'] ?? json['dz'] ?? ''}',
      credits: (json['credits'] as num?)?.toDouble() ?? 0,
      hours: (json['hours'] as num?)?.toInt(),
      weeks: '${json['weeks'] ?? ''}',
      sjms: '${json['sjms'] ?? ''}',
      capacity: (json['capacity'] as num?)?.toInt(),
      selected: selected,
      selectable:
          (json['selectable'] as num?)?.toInt() ??
          (json['yxkc'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'className': className,
    'teacher': teacher,
    'room': room,
    'credits': credits,
    'hours': hours,
    'weeks': weeks,
    'sjms': sjms,
    'capacity': capacity,
    'selected': selected,
    'selectable': selectable,
  };
}

class ServiceHit {
  const ServiceHit({required this.item, required this.group});

  final ServiceItem item;
  final String group;
}

const serviceAliases = <String, String>{
  'wsjxpj': '评教 评价',
  'xskbcx': '课表',
  'xscjcx': '成绩 分数',
  'xswsxk_kb': '选课',
  'xswsxk': '选课',
  'xkjgcx': '选课 已选',
  'kckccx': '考试 考场',
  'ttkcx': '调课',
  'pyjhcx': '培养计划 学分',
  'xsxx': '资料',
};

class Snapshot {
  Snapshot({
    required this.termName,
    required this.termStart,
    required this.student,
    required this.courses,
    this.schemaVersion = 2,
    this.source = '',
    this.updatedAt = '',
    this.updatedLabel = '',
    this.demoStudentId = '',
    this.campusNote = '',
    this.termCode = '',
    this.termStartKnown = true,
    this.notices = 0,
    this.exams = 0,
    this.credits,
    this.services = const [],
    this.evaluations = const [],
    this.applications = const [],
    this.grades = const [],
    this.noticeItems = const [],
    this.examItems = const [],
    this.selectionCourses = const [],
    List<Period>? periods,
  }) : periods = periods ?? periodsFromJson(null);

  final int schemaVersion;
  final String source;
  final String updatedAt;
  final String termName;
  final String termStart;
  final String updatedLabel;
  final String demoStudentId;
  final String campusNote;
  final String termCode;
  final bool termStartKnown;

  String get loginStudentId =>
      demoStudentId.isEmpty ? student.id : demoStudentId;
  final Student student;
  final List<Course> courses;
  final int notices;
  final int exams;
  final Credits? credits;
  final List<ServiceGroup> services;
  final List<Evaluation> evaluations;
  final List<ApplicationItem> applications;
  final List<GradeRecord> grades;
  final List<NoticeItem> noticeItems;
  final List<ExamItem> examItems;
  final List<SelectionCourse> selectionCourses;
  final List<Period> periods;

  String get studentName => student.name;

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    final term = Map<String, dynamic>.from(json['term'] as Map? ?? const {});
    final periodList = periodsFromJson(json['periods']);
    final courses = (json['courses'] as List? ?? const [])
        .map(
          (item) => decorateCourse(
            Course.fromJson(Map<String, dynamic>.from(item as Map)),
            periodList,
          ),
        )
        .toList();
    final creditRaw = json['credits'];

    final noticeRaw = json['notices'];
    final noticeItems = noticeRaw is List
        ? noticeRaw
              .map(
                (item) =>
                    NoticeItem.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList()
        : const <NoticeItem>[];
    final examRaw = json['exams'];
    final examItems = examRaw is List
        ? examRaw
              .map(
                (item) =>
                    ExamItem.fromJson(Map<String, dynamic>.from(item as Map)),
              )
              .toList()
        : const <ExamItem>[];

    return Snapshot(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      source: '${json['source'] ?? ''}',
      updatedAt: '${json['updatedAt'] ?? ''}',
      termName: '${term['name'] ?? ''}',
      termStart: '${term['start'] ?? ''}',
      updatedLabel: '${json['updatedLabel'] ?? ''}',
      demoStudentId: '${json['demoStudentId'] ?? ''}',
      campusNote: '${json['campusNote'] ?? ''}',
      termCode: '${term['code'] ?? ''}',
      termStartKnown:
          json['termStartKnown'] as bool? ??
          (term['start'] != null && '${term['start']}'.isNotEmpty),
      student: Student.fromJson(
        json['student'] is Map
            ? Map<String, dynamic>.from(json['student'] as Map)
            : null,
      ),
      courses: courses,
      notices: noticeRaw is List
          ? noticeItems.length
          : (noticeRaw as num?)?.toInt() ?? 0,
      exams: examRaw is List
          ? examItems.length
          : (examRaw as num?)?.toInt() ?? 0,
      credits: creditRaw is Map
          ? Credits.fromJson(Map<String, dynamic>.from(creditRaw))
          : null,
      services: (json['services'] as List? ?? const [])
          .map(
            (item) =>
                ServiceGroup.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      evaluations: (json['evaluations'] as List? ?? const [])
          .map(
            (item) =>
                Evaluation.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      applications: (json['applications'] as List? ?? const [])
          .map(
            (item) => ApplicationItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      grades: (json['grades'] as List? ?? const [])
          .map(
            (item) =>
                GradeRecord.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      noticeItems: noticeItems,
      examItems: examItems,
      selectionCourses: (json['selectionCourses'] as List? ?? const [])
          .map(
            (item) => SelectionCourse.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      periods: periodList,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'source': source,
    'updatedAt': updatedAt,
    'updatedLabel': updatedLabel,
    'demoStudentId': demoStudentId,
    'campusNote': campusNote,
    'term': {'code': termCode, 'name': termName, 'start': termStart},
    'termStartKnown': termStartKnown,
    'student': student.toJson(),
    'courses': courses.map((course) => course.toJson()).toList(),
    'credits': credits?.toJson(),
    'services': services.map((group) => group.toJson()).toList(),
    'evaluations': evaluations
        .map((evaluation) => evaluation.toJson())
        .toList(),
    'applications': applications
        .map((application) => application.toJson())
        .toList(),
    'grades': grades.map((grade) => grade.toJson()).toList(),
    'notices': noticeItems.map((notice) => notice.toJson()).toList(),
    'exams': examItems.map((exam) => exam.toJson()).toList(),
    'selectionCourses': selectionCourses
        .map((course) => course.toJson())
        .toList(),
    'periods': periods
        .map(
          (period) => {
            'n': period.n,
            'name': period.name,
            'start': period.start,
            'end': period.end,
            'group': period.group,
          },
        )
        .toList(),
  };
}

List<ServiceHit> searchServices(List<ServiceGroup> groups, String query) {
  final text = query.trim();
  if (text.isEmpty) return const [];
  final hits = <ServiceHit>[];
  for (final group in groups) {
    for (final item in group.items) {
      final alias = serviceAliases[item.id] ?? '';
      if (item.name.contains(text) || alias.contains(text)) {
        hits.add(ServiceHit(item: item, group: group.name));
      }
    }
  }
  return hits;
}

List<Course> searchCourses(List<Course> courses, String query) {
  final text = query.trim();
  if (text.isEmpty) return const [];
  final lower = text.toLowerCase();
  return courses.where((course) {
    return course.name.contains(text) ||
        course.teacher.contains(text) ||
        course.code.toLowerCase().contains(lower);
  }).toList();
}

List<ApplicationItem> previewApplications(List<ApplicationItem> all) {
  const preferred = ['lwkt', 'pyjh', 'zc', 'lwdb'];
  final picked = <ApplicationItem>[];
  for (final id in preferred) {
    for (final item in all) {
      if (item.id == id) picked.add(item);
    }
  }
  return picked.take(2).toList();
}

int pendingEvalCount(List<Evaluation> evaluations) {
  return evaluations.where((item) => item.open && !item.rated).length;
}
