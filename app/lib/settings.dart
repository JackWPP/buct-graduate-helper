class AppSettings {
  bool reminder = true;
  int reminderMin = 15;
  bool deadline = true;
  bool dnd = true;
  String weekStart = 'mon';
  bool showOffWeek = false;
  final Map<String, String> colors = {};
  final Map<String, bool> courseRemind = {};

  bool courseRemindOn(String id) => courseRemind[id] ?? reminder;

  bool inQuietHours(DateTime now) {
    if (!dnd) return false;
    return now.hour >= 22 || now.hour < 7;
  }

  void reset() {
    reminder = true;
    reminderMin = 15;
    deadline = true;
    dnd = true;
    weekStart = 'mon';
    showOffWeek = false;
    colors.clear();
    courseRemind.clear();
  }

  Map<String, Object> toJson() => {
    'reminder': reminder,
    'reminderMin': reminderMin,
    'deadline': deadline,
    'dnd': dnd,
    'weekStart': weekStart,
    'showOffWeek': showOffWeek,
    'colors': colors,
    'courseRemind': courseRemind,
  };

  void applyJson(Object? raw) {
    if (raw is! Map) return;
    reminder = raw['reminder'] as bool? ?? reminder;
    final minutes = raw['reminderMin'];
    if (minutes is num) reminderMin = minutes.toInt();
    deadline = raw['deadline'] as bool? ?? deadline;
    dnd = raw['dnd'] as bool? ?? dnd;
    final start = raw['weekStart'];
    if (start == 'mon' || start == 'sun') weekStart = start as String;
    showOffWeek = raw['showOffWeek'] as bool? ?? showOffWeek;
    final colorMap = raw['colors'];
    if (colorMap is Map) {
      colors
        ..clear()
        ..addAll(colorMap.map((key, value) => MapEntry('$key', '$value')));
    }
    final remindMap = raw['courseRemind'];
    if (remindMap is Map) {
      courseRemind
        ..clear()
        ..addAll(
          remindMap.map((key, value) => MapEntry('$key', value == true)),
        );
    }
  }
}
