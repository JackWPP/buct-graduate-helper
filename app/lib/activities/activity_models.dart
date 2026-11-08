import 'dart:typed_data';

/// 学术报告 / 劳动实践的活动模型。
///
/// 字段来自学校页面 JS 的列表接口，统一在这里把字符串转成可比较的
/// 时间、人数和状态，页面和通知都只依赖这个模型，不再散落解析逻辑。
enum ActivityKind {
  academicReport,
  laborPractice;

  String get serviceId => switch (this) {
    ActivityKind.academicReport => 'xshdbm',
    ActivityKind.laborPractice => 'zyzfwbm',
  };

  String get label => switch (this) {
    ActivityKind.academicReport => '学术报告',
    ActivityKind.laborPractice => '劳动实践',
  };

  String get availablePath => switch (this) {
    ActivityKind.academicReport => '/student/yggl/xshdbm_sqlist',
    ActivityKind.laborPractice => '/student/yggl/zyzfwbm_sqlist',
  };

  String get appliedPath => switch (this) {
    ActivityKind.academicReport => '/student/yggl/xshdbm_cklist',
    ActivityKind.laborPractice => '/student/yggl/zyzfwbm_cklist',
  };

  String get cancelPath => switch (this) {
    ActivityKind.academicReport => '/student/yggl/xshdbm_del',
    ActivityKind.laborPractice => '/student/yggl/ldsjbm_del',
  };
}

DateTime? parseSchoolTime(String value) {
  var text = value.trim();
  if (text.isEmpty) return null;
  text = text
      .replaceAll('年', '-')
      .replaceAll('月', '-')
      .replaceAll('日', '')
      .replaceAll('/', '-')
      .replaceAll('.', '-');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final direct = DateTime.tryParse(text);
  if (direct != null) return direct;
  final match = RegExp(
    r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?',
  ).firstMatch(text);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.tryParse(match.group(4) ?? '') ?? 0,
    int.tryParse(match.group(5) ?? '') ?? 0,
  );
}

String activityText(Map<String, dynamic> json, String key) =>
    '${json[key] ?? ''}'.trim();

int activityInt(Map<String, dynamic> json, String key) =>
    int.tryParse(activityText(json, key).replaceAll(RegExp(r'[^0-9-]'), '')) ??
    0;

class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.id,
    required this.applicationId,
    required this.title,
    required this.category,
    required this.publisher,
    required this.organizer,
    required this.location,
    required this.method,
    required this.activityStart,
    required this.activityEnd,
    required this.signupStart,
    required this.signupEnd,
    required this.capacity,
    required this.enrolled,
    required this.score,
    required this.duration,
    required this.auditStatus,
    required this.applied,
  });

  final ActivityKind kind;

  /// 可报名列表里的 `id`；已报名列表里学校只返回 `hdid`，因此两者都会填充。
  final String id;
  final String applicationId;
  final String title;
  final String category;
  final String publisher;
  final String organizer;
  final String location;
  final String method;
  final DateTime? activityStart;
  final DateTime? activityEnd;
  final DateTime? signupStart;
  final DateTime? signupEnd;
  final int capacity;
  final int enrolled;
  final String score;
  final String duration;
  final String auditStatus;
  final bool applied;

  factory ActivityItem.fromJson(
    Map<String, dynamic> json, {
    required ActivityKind kind,
    required bool applied,
  }) {
    final hdid = activityText(json, 'hdid');
    final rawId = activityText(json, 'id');
    return ActivityItem(
      kind: kind,
      id: rawId.isNotEmpty ? rawId : hdid,
      applicationId: hdid,
      title: activityText(json, 'mc'),
      category: activityText(json, 'fl'),
      publisher: activityText(json, 'fbdw'),
      organizer: activityText(json, 'zbdw'),
      location: activityText(json, 'dd'),
      method: activityText(json, 'bmfs'),
      activityStart: parseSchoolTime(activityText(json, 'kssj')),
      activityEnd: parseSchoolTime(activityText(json, 'jzsj')),
      signupStart: parseSchoolTime(activityText(json, 'bmkssj')),
      signupEnd: parseSchoolTime(activityText(json, 'bmjzsj')),
      capacity: activityInt(json, 'rs'),
      enrolled: activityInt(json, 'bmrs'),
      score: activityText(json, 'fs'),
      duration: activityText(json, 'hdsc'),
      auditStatus: activityText(json, 'shbj'),
      applied: applied,
    );
  }

  String get stableKey => '${kind.serviceId}:$id';

  int get remaining {
    if (capacity <= 0) return -1;
    final left = capacity - enrolled;
    return left < 0 ? 0 : left;
  }

  bool get isFull => remaining == 0;

  String get capacityLabel {
    if (capacity <= 0) return enrolled > 0 ? '已报名 $enrolled 人' : '人数以学校为准';
    return '$enrolled / $capacity 人';
  }

  String get auditLabel {
    if (!applied) return '';
    return switch (auditStatus) {
      '0' => '待审核',
      '1' => '已通过',
      '-1' || '2' => '未通过',
      _ => auditStatus.isEmpty ? '已报名' : auditStatus,
    };
  }

  ActivityPhase phaseAt(DateTime now) {
    if (applied) return ActivityPhase.applied;
    if (signupEnd != null && !now.isBefore(signupEnd!)) {
      return ActivityPhase.closed;
    }
    if (signupStart != null && now.isBefore(signupStart!)) {
      return ActivityPhase.upcoming;
    }
    if (isFull) return ActivityPhase.full;
    return ActivityPhase.open;
  }

  String phaseLabel(DateTime now) {
    switch (phaseAt(now)) {
      case ActivityPhase.applied:
        return auditLabel;
      case ActivityPhase.closed:
        return '报名已截止';
      case ActivityPhase.upcoming:
        return '未开始报名';
      case ActivityPhase.full:
        return '名额已满';
      case ActivityPhase.open:
        return isFull ? '名额已满' : '报名中';
    }
  }
}

enum ActivityPhase { open, upcoming, full, closed, applied }

class ActivityFeed {
  const ActivityFeed({
    this.available = const [],
    this.applied = const [],
    this.totalHours = 0,
    this.loading = false,
    this.error,
    this.lastChecked,
  });

  final List<ActivityItem> available;
  final List<ActivityItem> applied;
  final double totalHours;
  final bool loading;
  final String? error;
  final DateTime? lastChecked;

  ActivityFeed copyWith({
    List<ActivityItem>? available,
    List<ActivityItem>? applied,
    double? totalHours,
    bool? loading,
    String? error,
    DateTime? lastChecked,
    bool clearError = false,
  }) {
    return ActivityFeed(
      available: available ?? this.available,
      applied: applied ?? this.applied,
      totalHours: totalHours ?? this.totalHours,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class ActivitySignResult {
  const ActivitySignResult({required this.ok, required this.message});

  final bool ok;
  final String message;

  String get display {
    if (ok) return '报名成功';
    if (message.isEmpty) return '学校没有返回结果，请刷新后查看报名记录。';
    return message;
  }
}

/// 活动页面依赖的最小接口，便于 widget test 用假实现替换真实 GMIS。
abstract interface class ActivityDataSource {
  Future<List<ActivityItem>> activityAvailable(ActivityKind kind);
  Future<List<ActivityItem>> activityApplied(ActivityKind kind);
  Future<double> laborPracticeHours();
  Future<bool> canApplyAcademicReport(String id);
  Future<Uint8List> activityCaptcha();
  Future<ActivitySignResult> registerActivity({
    required String id,
    required String captcha,
  });
  Future<ActivitySignResult> cancelActivity({
    required ActivityKind kind,
    required String applicationId,
  });
}
