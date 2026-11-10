import 'package:flutter/material.dart';

import '../schedule.dart';
import '../theme.dart';
import 'time_text.dart';
import 'todo_models.dart';

Future<void> showTodoEditor(
  BuildContext context, {
  required DateTime defaultDate,
  required List<Course> courses,
  required String termStart,
  required Future<void> Function(TodoItem) onSave,
  TodoItem? initial,
  Course? initialCourse,
  Future<void> Function(String)? onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TodoEditorSheet(
      initial: initial,
      initialCourse: initialCourse,
      defaultDate: defaultDate,
      courses: courses,
      termStart: termStart,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}

class TodoEditorSheet extends StatefulWidget {
  const TodoEditorSheet({
    super.key,
    required this.defaultDate,
    required this.courses,
    required this.termStart,
    required this.onSave,
    this.initial,
    this.initialCourse,
    this.onDelete,
  });

  final TodoItem? initial;
  final Course? initialCourse;
  final DateTime defaultDate;
  final List<Course> courses;
  final String termStart;
  final Future<void> Function(TodoItem) onSave;
  final Future<void> Function(String)? onDelete;

  @override
  State<TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends State<TodoEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  late bool _timed;
  late int _startMin;
  late int _endMin;
  late String _courseId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _note = TextEditingController(text: initial?.note ?? '');
    _date = initial?.day ?? widget.defaultDate;
    _timed = initial?.timed ?? false;
    _startMin = initial?.startMin ?? 9 * 60;
    _endMin = initial?.endMin ?? 10 * 60;
    _courseId = initial?.courseId ?? widget.initialCourse?.id ?? '';
    _applyInitialCourseTime();
  }

  void _applyInitialCourseTime() {
    if (widget.initial != null || widget.initialCourse == null) return;
    for (final session in _sessions) {
      if (session.course.id != _courseId) continue;
      _timed = true;
      _startMin = session.startMin;
      _endMin = session.endMin;
      return;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Session> get _sessions {
    if (widget.termStart.isEmpty || widget.courses.isEmpty) {
      return const <Session>[];
    }
    return sessionsOn(widget.courses, _date, widget.termStart).items;
  }

  List<Course> get _dayCourses {
    final byId = <String, Course>{};
    for (final session in _sessions) {
      byId[session.course.id] = session.course;
    }
    return byId.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: HuayanColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: HuayanColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.initial == null ? '新增待办' : '编辑待办',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: HuayanColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                TextField(
                  key: const Key('todo-title'),
                  controller: _title,
                  autofocus: widget.initial == null,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: '待办内容',
                    hintText: '例如：交实验报告、带材料',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 10),
                _RowButton(
                  key: const Key('todo-date'),
                  icon: Icons.calendar_today_outlined,
                  label: '日期',
                  value: planDateLabel(_date),
                  onTap: _pickDate,
                ),
                SwitchListTile(
                  key: const Key('todo-time-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('设置时间段', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    _timed
                        ? '${planClock(_startMin)}–${planClock(_endMin)}'
                        : '全天',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _timed,
                  onChanged: (value) => setState(() => _timed = value),
                ),
                if (_timed)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('todo-start-time'),
                          onPressed: () => _pickTime(true),
                          child: Text('开始 ${planClock(_startMin)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('todo-end-time'),
                          onPressed: () => _pickTime(false),
                          child: Text('结束 ${planClock(_endMin)}'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                const Text(
                  '关联课程（可选）',
                  style: TextStyle(fontSize: 13, color: HuayanColors.sub),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      key: const Key('todo-course-none'),
                      label: const Text('不关联'),
                      selected: _courseId.isEmpty,
                      onSelected: (_) => setState(() => _courseId = ''),
                    ),
                    for (final course in _dayCourses)
                      ChoiceChip(
                        key: Key('todo-course-${course.id}'),
                        label: Text(
                          course.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: _courseId == course.id,
                        onSelected: (_) =>
                            setState(() => _courseId = course.id),
                      ),
                  ],
                ),
                if (_courseId.isNotEmpty && _hasSessionForCourse)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('todo-use-course-time'),
                      onPressed: _useCourseTime,
                      child: const Text('使用这节课的时间'),
                    ),
                  ),
                TextField(
                  key: const Key('todo-note'),
                  controller: _note,
                  maxLength: 120,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    counterText: '',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HuayanColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    key: const Key('todo-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存待办'),
                  ),
                ),
                if (widget.initial != null && widget.onDelete != null)
                  Center(
                    child: TextButton(
                      key: const Key('todo-delete'),
                      onPressed: _saving ? null : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: HuayanColors.danger,
                      ),
                      child: const Text('删除这条待办'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasSessionForCourse =>
      _sessions.any((session) => session.course.id == _courseId);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '选择待办日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime(bool start) async {
    final initial = start ? _startMin : _endMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      helpText: start ? '选择开始时间' : '选择结束时间',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final value = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        _startMin = value;
        if (_endMin <= _startMin) _endMin = (_startMin + 60).clamp(0, 24 * 60);
      } else {
        _endMin = value;
      }
      _error = null;
    });
  }

  void _useCourseTime() {
    for (final session in _sessions) {
      if (session.course.id != _courseId) continue;
      setState(() {
        _timed = true;
        _startMin = session.startMin;
        _endMin = session.endMin;
      });
      return;
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '先写一下待办内容');
      return;
    }
    if (_timed && _endMin <= _startMin) {
      setState(() => _error = '结束时间要晚于开始时间');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final base =
        widget.initial ??
        TodoItem(
          id: TodoItem.newId(),
          title: title,
          date: plannerDateKey(_date),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
    final item = base.copyWith(
      title: title,
      note: _note.text.trim(),
      date: plannerDateKey(_date),
      courseId: _courseId,
      startMin: _timed ? _startMin : null,
      endMin: _timed ? _endMin : null,
      clearTime: !_timed,
    );
    try {
      await widget.onSave(item);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }

  Future<void> _delete() async {
    final initial = widget.initial;
    final delete = widget.onDelete;
    if (initial == null || delete == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除待办'),
        content: Text('确定删除“${initial.title}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('todo-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await delete(initial.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '删除失败，请重试';
        });
      }
    }
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HuayanColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: HuayanColors.blue),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: HuayanColors.sub),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HuayanColors.ink,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: HuayanColors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
