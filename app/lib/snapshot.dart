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
}

class CreditCategory {
  const CreditCategory({
    required this.name,
    required this.got,
    required this.need,
  });

  final String name;
  final double got;
  final double need;

  factory CreditCategory.fromJson(Map<String, dynamic> json) {
    return CreditCategory(
      name: '${json['name'] ?? ''}',
      got: (json['got'] as num?)?.toDouble() ?? 0,
      need: (json['need'] as num?)?.toDouble() ?? 0,
    );
  }
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
}

class Evaluation {
  const Evaluation({
    required this.name,
    required this.teacher,
    required this.credits,
    required this.rated,
    required this.open,
  });

  final String name;
  final String teacher;
  final double credits;
  final bool rated;
  final bool open;

  factory Evaluation.fromJson(Map<String, dynamic> json) {
    return Evaluation(
      name: '${json['name'] ?? ''}',
      teacher: '${json['teacher'] ?? ''}',
      credits: (json['credits'] as num?)?.toDouble() ?? 0,
      rated: json['rated'] == true,
      open: json['open'] == true,
    );
  }
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
    this.updatedLabel = '',
    this.campusNote = '',
    this.notices = 0,
    this.exams = 0,
    this.credits,
    this.services = const [],
    this.evaluations = const [],
    this.applications = const [],
    List<Period>? periods,
  }) : periods = periods ?? periodsFromJson(null);

  final String termName;
  final String termStart;
  final String updatedLabel;
  final String campusNote;
  final Student student;
  final List<Course> courses;
  final int notices;
  final int exams;
  final Credits? credits;
  final List<ServiceGroup> services;
  final List<Evaluation> evaluations;
  final List<ApplicationItem> applications;
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
    return Snapshot(
      termName: '${term['name'] ?? ''}',
      termStart: '${term['start'] ?? ''}',
      updatedLabel: '${json['updatedLabel'] ?? ''}',
      campusNote: '${json['campusNote'] ?? ''}',
      student: Student.fromJson(
        json['student'] is Map
            ? Map<String, dynamic>.from(json['student'] as Map)
            : null,
      ),
      courses: courses,
      notices: (json['notices'] as List?)?.length ?? 0,
      exams: (json['exams'] as List?)?.length ?? 0,
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
      periods: periodList,
    );
  }
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
