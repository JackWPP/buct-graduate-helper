import '../schedule.dart' show parseIsoDate;

DateTime plannerDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

String plannerDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

DateTime? parsePlannerDate(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
  try {
    return parseIsoDate(text);
  } catch (_) {
    return null;
  }
}

/// 本机个人待办。和学校流程待办（注册、评教、开题）不是同一类数据，
/// 只保存日期/时间段/关联课程，不写任何学校接口或快照。
class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.date,
    required this.createdAt,
    this.note = '',
    this.startMin,
    this.endMin,
    this.courseId = '',
    this.done = false,
  });

  final String id;
  final String title;
  final String note;

  /// `YYYY-MM-DD`，按本机日历日保存。
  final String date;
  final int? startMin;
  final int? endMin;
  final String courseId;
  final bool done;
  final int createdAt;

  bool get allDay => startMin == null || endMin == null;

  bool get timed => startMin != null && endMin != null && endMin! > startMin!;

  int get duration => timed ? endMin! - startMin! : 0;

  DateTime get day => parsePlannerDate(date) ?? DateTime(1970);

  TodoItem copyWith({
    String? title,
    String? note,
    String? date,
    int? startMin,
    int? endMin,
    String? courseId,
    bool? done,
    bool clearTime = false,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      date: date ?? this.date,
      startMin: clearTime ? null : (startMin ?? this.startMin),
      endMin: clearTime ? null : (endMin ?? this.endMin),
      courseId: courseId ?? this.courseId,
      done: done ?? this.done,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'date': date,
    'startMin': startMin,
    'endMin': endMin,
    'courseId': courseId,
    'done': done,
    'createdAt': createdAt,
  };

  static TodoItem? tryFromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    final title = '${json['title'] ?? ''}'.trim();
    final date = '${json['date'] ?? ''}'.trim();
    if (id.isEmpty || title.isEmpty || parsePlannerDate(date) == null) {
      return null;
    }
    final rawStart = json['startMin'];
    final rawEnd = json['endMin'];
    final start = rawStart is num ? rawStart.toInt() : null;
    final end = rawEnd is num ? rawEnd.toInt() : null;
    final validTime =
        start != null &&
        end != null &&
        start >= 0 &&
        end <= 24 * 60 &&
        end > start;
    final createdAt = json['createdAt'];
    return TodoItem(
      id: id,
      title: title,
      note: '${json['note'] ?? ''}'.trim(),
      date: date,
      startMin: validTime ? start : null,
      endMin: validTime ? end : null,
      courseId: '${json['courseId'] ?? ''}'.trim(),
      done: json['done'] == true,
      createdAt: createdAt is num
          ? createdAt.toInt()
          : DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String newId([DateTime? now]) {
    final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
    return 'todo-$stamp';
  }
}
