import 'package:flutter/material.dart';

import '../activities/activity_models.dart';
import '../schedule.dart';
import '../theme.dart';
import 'day_plan.dart';
import 'planner_models.dart';
import 'time_text.dart';
import 'todo_models.dart';

/// 当天日程弹层：课程、活动、待办和空闲段共用一套时间线。
Future<void> showDayAgendaSheet(
  BuildContext context, {
  required DateTime date,
  required List<Course> courses,
  required String termStart,
  required DateTime now,
  List<ActivityItem> activities = const <ActivityItem>[],
  List<TodoItem> todos = const <TodoItem>[],
  ActivityItem? candidate,
  bool termStartKnown = true,
  ValueChanged<Course>? onCourse,
  ValueChanged<TodoItem>? onToggleTodo,
  Future<void> Function(TodoItem)? onEditTodo,
  Future<void> Function(DateTime, Course?)? onAddTodo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DayAgendaSheet(
      date: date,
      courses: courses,
      termStart: termStart,
      now: now,
      activities: activities,
      todos: todos,
      candidate: candidate,
      termStartKnown: termStartKnown,
      onCourse: onCourse,
      onToggleTodo: onToggleTodo,
      onEditTodo: onEditTodo,
      onAddTodo: onAddTodo,
    ),
  );
}

class DayAgendaSheet extends StatefulWidget {
  const DayAgendaSheet({
    super.key,
    required this.date,
    required this.courses,
    required this.termStart,
    required this.now,
    this.activities = const <ActivityItem>[],
    this.todos = const <TodoItem>[],
    this.candidate,
    this.termStartKnown = true,
    this.onCourse,
    this.onToggleTodo,
    this.onEditTodo,
    this.onAddTodo,
  });

  final DateTime date;
  final List<Course> courses;
  final String termStart;
  final DateTime now;
  final List<ActivityItem> activities;
  final List<TodoItem> todos;
  final ActivityItem? candidate;
  final bool termStartKnown;
  final ValueChanged<Course>? onCourse;
  final ValueChanged<TodoItem>? onToggleTodo;
  final Future<void> Function(TodoItem)? onEditTodo;
  final Future<void> Function(DateTime, Course?)? onAddTodo;

  @override
  State<DayAgendaSheet> createState() => _DayAgendaSheetState();
}

class _DayAgendaSheetState extends State<DayAgendaSheet> {
  late List<TodoItem> _todos;

  @override
  void initState() {
    super.initState();
    _todos = List<TodoItem>.from(widget.todos);
  }

  DayPlan get _plan => buildDayPlan(
    date: widget.date,
    courses: widget.courses,
    termStart: widget.termStart,
    now: widget.now,
    activities: widget.activities,
    todos: _todos,
    candidate: widget.candidate,
    termStartKnown: widget.termStartKnown,
  );

  Map<String, Course> get _coursesById => {
    for (final course in widget.courses) course.id: course,
  };

  Map<String, TodoItem> get _todosById => {
    for (final todo in _todos) todo.id: todo,
  };

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Material(
      color: HuayanColors.bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        planDateLabel(plan.date),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: HuayanColors.ink,
                        ),
                      ),
                    ),
                    if (plan.isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: HuayanColors.blueSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          '今天',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: HuayanColors.blue,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      plan.week > 0 ? '第 ${plan.week} 周' : '学期外',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HuayanColors.faint,
                      ),
                    ),
                    if (widget.onAddTodo != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        key: const Key('day-agenda-add-todo'),
                        tooltip: '新增待办',
                        onPressed: () => _add(plan.date, null),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 21,
                          color: HuayanColors.blue,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _summary(plan),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: HuayanColors.sub,
                  ),
                ),
                if (!plan.termKnown || !plan.hasCourseData) ...[
                  const SizedBox(height: 8),
                  Text(
                    !plan.termKnown
                        ? '学期开始日未确认，周次和空闲时间可能不准。'
                        : '课表还没加载，目前只显示活动和待办。',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: HuayanColors.amberInk,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (plan.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '这天没有课程和日程。',
                      style: TextStyle(fontSize: 14, color: HuayanColors.sub),
                    ),
                  )
                else
                  for (var index = 0; index < plan.items.length; index++) ...[
                    PlanItemTile(
                      item: plan.items[index],
                      onTap: _itemTap(plan.items[index]),
                      onToggleTodo: _todoToggle(plan.items[index]),
                      onAddTodo: _courseAddTodo(plan.items[index], plan.date),
                    ),
                    if (index != plan.items.length - 1)
                      const Divider(height: 1, color: HuayanColors.lineSoft),
                  ],
                if (widget.candidate != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '“待报名”活动按已占用计算空闲，仅用于报名前预览。',
                    style: TextStyle(fontSize: 11, color: HuayanColors.faint),
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  '当天空闲',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (plan.isPast)
                  const Text(
                    '已过去，不计算空闲。',
                    style: TextStyle(fontSize: 12, color: HuayanColors.faint),
                  )
                else
                  FreeSlotChips(slots: plan.freeSlots),
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? _itemTap(PlanItem item) {
    if (item.kind == PlanItemKind.course && widget.onCourse != null) {
      final course = _coursesById[item.sourceId];
      if (course == null) return null;
      return () {
        Navigator.of(context).pop();
        widget.onCourse!(course);
      };
    }
    if (item.kind == PlanItemKind.todo && widget.onEditTodo != null) {
      final todo = _todosById[item.sourceId];
      if (todo == null) return null;
      return () => _edit(todo);
    }
    return null;
  }

  VoidCallback? _todoToggle(PlanItem item) {
    if (item.kind != PlanItemKind.todo || widget.onToggleTodo == null) {
      return null;
    }
    final todo = _todosById[item.sourceId];
    if (todo == null) return null;
    return () {
      widget.onToggleTodo!(todo);
      setState(() {
        _todos = [
          for (final existing in _todos)
            existing.id == todo.id
                ? existing.copyWith(done: !existing.done)
                : existing,
        ];
      });
    };
  }

  VoidCallback? _courseAddTodo(PlanItem item, DateTime date) {
    if (item.kind != PlanItemKind.course || widget.onAddTodo == null) {
      return null;
    }
    final course = _coursesById[item.sourceId];
    return course == null ? null : () => _add(date, course);
  }

  Future<void> _add(DateTime date, Course? course) async {
    final callback = widget.onAddTodo;
    if (callback == null) return;
    Navigator.of(context).pop();
    await callback(date, course);
  }

  Future<void> _edit(TodoItem todo) async {
    final callback = widget.onEditTodo;
    if (callback == null) return;
    Navigator.of(context).pop();
    await callback(todo);
  }

  String _summary(DayPlan plan) {
    final parts = <String>[
      if (plan.courseCount > 0) '${plan.courseCount} 节课',
      if (plan.activityCount > 0) '${plan.activityCount} 个活动',
      if (plan.pendingTodoCount > 0) '${plan.pendingTodoCount} 个待办',
      if (plan.doneTodoCount > 0) '${plan.doneTodoCount} 个已完成',
    ];
    final busy = parts.isEmpty ? '没有安排' : parts.join(' · ');
    if (plan.isPast) return '$busy · 已过去，不计算空闲';
    final free = plan.freeSlots.isEmpty
        ? '没有整段空闲'
        : '空闲 ${plan.freeSlots.length} 段 · 共 ${formatDuration(plan.freeMinutes)}';
    return '$busy · $free';
  }
}

class PlanItemTile extends StatelessWidget {
  const PlanItemTile({
    super.key,
    required this.item,
    this.compact = false,
    this.onTap,
    this.onToggleTodo,
    this.onAddTodo,
  });

  final PlanItem item;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onToggleTodo;
  final VoidCallback? onAddTodo;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.kind) {
      PlanItemKind.course => HuayanColors.blue,
      PlanItemKind.activity =>
        item.candidate ? HuayanColors.amberInk : HuayanColors.ok,
      PlanItemKind.todo =>
        item.done ? HuayanColors.faint : HuayanColors.amberInk,
    };
    final badge = switch (item.kind) {
      PlanItemKind.activity => item.candidate ? '待报名' : '已报名',
      PlanItemKind.todo when item.done => '已完成',
      PlanItemKind.todo when item.overdue => '已逾期',
      _ => '',
    };
    final titleStyle = TextStyle(
      fontSize: compact ? 13 : 15,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: item.done ? HuayanColors.faint : HuayanColors.ink,
      decoration: item.done ? TextDecoration.lineThrough : null,
    );
    final meta = [
      if (item.subtitle.isNotEmpty) item.subtitle,
      if (item.location.isNotEmpty) item.location,
    ].join(' · ');
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 7 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.allDay
                      ? '全天'
                      : item.startMin == null
                      ? '待定'
                      : planClock(item.startMin!),
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (item.timed)
                  Text(
                    planClock(item.endMin!),
                    style: const TextStyle(
                      fontSize: 10,
                      color: HuayanColors.faint,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 3,
            height: compact ? 28 : 36,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (!compact && meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: HuayanColors.sub,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (badge.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: item.candidate
                    ? HuayanColors.amberSoft
                    : HuayanColors.blueSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: item.candidate
                      ? HuayanColors.amberInk
                      : HuayanColors.blue,
                ),
              ),
            ),
          ],
          if (item.kind == PlanItemKind.course && onAddTodo != null) ...[
            const SizedBox(width: 2),
            IconButton(
              key: Key('plan-course-add-todo-${item.sourceId}'),
              tooltip: '给这门课加待办',
              onPressed: onAddTodo,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: const Icon(
                Icons.add_circle_outline,
                size: 18,
                color: HuayanColors.blue,
              ),
            ),
          ],
          if (item.kind == PlanItemKind.todo && onToggleTodo != null) ...[
            const SizedBox(width: 2),
            SizedBox(
              width: 34,
              height: 34,
              child: Checkbox(
                key: Key('plan-todo-check-${item.sourceId}'),
                value: item.done,
                onChanged: onToggleTodo == null ? null : (_) => onToggleTodo!(),
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }
}

class FreeSlotChips extends StatelessWidget {
  const FreeSlotChips({super.key, required this.slots});

  final List<FreeSlot> slots;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Text(
        '没有 30 分钟以上的整段空闲。',
        style: TextStyle(fontSize: 12, color: HuayanColors.faint),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final slot in slots)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: HuayanColors.blueSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${planSlotText(slot)} · ${planSlotDuration(slot)}',
              style: const TextStyle(
                fontSize: 11,
                color: HuayanColors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
