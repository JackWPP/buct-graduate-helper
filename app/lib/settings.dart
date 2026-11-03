class AppSettings {
  bool reminder = true;
  int reminderMin = 15;
  bool deadline = true;
  bool dnd = true;
  String weekStart = 'mon';
  bool showOffWeek = false;
  final Map<String, String> colors = {};

  void reset() {
    reminder = true;
    reminderMin = 15;
    deadline = true;
    dnd = true;
    weekStart = 'mon';
    showOffWeek = false;
    colors.clear();
  }
}
