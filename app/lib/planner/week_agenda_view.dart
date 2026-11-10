import 'package:flutter/material.dart';

import '../activities/activity_models.dart';
import '../schedule.dart';
import '../theme.dart';
import 'day_agenda_sheet.dart';
import 'day_plan.dart';
import 'planner_models.dart';
import 'time_text.dart';
import 'todo_models.dart';

/// 课表页的“日程”视图：一周 7 天，每天课程/活动/待办 + 空闲段。
class WeekAgendaView extends StatelessWidget {
  const WeekAgendaView({
    super.key,
    required this.monday,
    required this.now,
    required this.courses,
    required this.termStart,
    this.activities = const <ActivityItem>[],
    this.todos = const <TodoItem>[],
    this.termStartKnown = true,
    this.onCourse,
    this.onOpenDay,
    this.onToggleTodo,
    this.onEditTodo,
    this.onAddTodo,
  });

  final DateTime monday;
  final DateTime now;
  final List<Course> courses;
  final String termStart;
  final List<ActivityItem> activities;
  final List<TodoItem> todos;
  final bool termStartKnown;
  final ValueChanged<Course>? onCourse;
  final ValueChanged<DateTime>? onOpenDay;
  final ValueChanged<TodoItem>? onToggleTodo;
  final Future<void> Function(TodoItem)? onEditTodo;
  final Future<void> Function(DateTime)? onAddTodo;

  @override
  Widget build(BuildContext context) {
    final week = buildWeekPlan(
      monday: monday,
      courses: courses,
      termStart: termStart,
      now: now,
      activities: activities,
      todos: todos,
      termStartKnown: termStartKnown,
    );
    final courseById = {for (final course in courses) course.id: course};
    final todoById = {for (final todo in todos) todo.id: todo};
    return ListView(
      key: const Key('week-agenda-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        if (!week.days.first.termKnown || !week.days.first.hasCourseData)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              !week.days.first.termKnown
                  ? '学期开始日未确认，周次和空闲时间可能不准。'
                  : '课表还没加载，目前只显示活动和待办。',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: HuayanColors.amberInk,
              ),
            ),
          ),
        for (final day in week.days)
          _DayAgendaCard(
            day: day,
            courseById: courseById,
            todoById: todoById,
            onCourse: onCourse,
            onOpenDay: onOpenDay,
            onToggleTodo: onToggleTodo,
            onEditTodo: onEditTodo,
            onAddTodo: onAddTodo,
          ),
      ],
    );
  }
}

class _DayAgendaCard extends StatelessWidget {
  const _DayAgendaCard({
    required this.day,
    required this.courseById,
    required this.todoById,
    this.onCourse,
    this.onOpenDay,
    this.onToggleTodo,
    this.onEditTodo,
    this.onAddTodo,
  });

  final DayPlan day;
  final Map<String, Course> courseById;
  final Map<String, TodoItem> todoById;
  final ValueChanged<Course>? onCourse;
  final ValueChanged<DateTime>? onOpenDay;
  final ValueChanged<TodoItem>? onToggleTodo;
  final Future<void> Function(TodoItem)? onEditTodo;
  final Future<void> Function(DateTime)? onAddTodo;

  @override
  Widget build(BuildContext context) {
    final weekday = planWeekday(day.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: HuayanColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: day.isToday ? HuayanColors.blue : HuayanColors.lineSoft,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onOpenDay == null ? null : () => onOpenDay!(day.date),
                child: Row(
                  children: [
                    Text(
                      weekday,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: day.isToday
                            ? HuayanColors.blue
                            : HuayanColors.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${day.date.month}/${day.date.day}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HuayanColors.faint,
                      ),
                    ),
                    if (day.isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HuayanColors.blueSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          '今天',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: HuayanColors.blue,
                          ),
                        ),
                      ),
                    ],
                    if (day.isPast) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '已过去',
                        style: TextStyle(
                          fontSize: 10,
                          color: HuayanColors.faint,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (onAddTodo != null)
                      IconButton(
                        tooltip: '新增待办',
                        onPressed: () => onAddTodo!(day.date),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 19,
                          color: HuayanColors.blue,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                      ),
                    if (onOpenDay != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: HuayanColors.faint,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _summary(day),
              style: const TextStyle(fontSize: 11, color: HuayanColors.sub),
            ),
            if (day.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  day.isPast ? '没有课程和日程。' : '没有课程和日程，全天空闲。',
                  style: const TextStyle(
                    fontSize: 12,
                    color: HuayanColors.faint,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 4),
              for (final item in day.items)
                PlanItemTile(
                  item: item,
                  compact: true,
                  onTap: _itemTap(item),
                  onToggleTodo: _todoToggle(item),
                ),
            ],
            const SizedBox(height: 6),
            if (day.isPast)
              const Text(
                '已过去，不计算空闲。',
                style: TextStyle(fontSize: 12, color: HuayanColors.faint),
              )
            else
              FreeSlotChips(slots: day.freeSlots),
          ],
        ),
      ),
    );
  }

  VoidCallback? _itemTap(PlanItem item) {
    if (item.kind == PlanItemKind.course && onCourse != null) {
      final course = courseById[item.sourceId];
      return course == null ? null : () => onCourse!(course);
    }
    if (item.kind == PlanItemKind.todo && onEditTodo != null) {
      final todo = todoById[item.sourceId];
      return todo == null ? null : () => onEditTodo!(todo);
    }
    return null;
  }

  VoidCallback? _todoToggle(PlanItem item) {
    if (item.kind != PlanItemKind.todo || onToggleTodo == null) return null;
    final todo = todoById[item.sourceId];
    return todo == null ? null : () => onToggleTodo!(todo);
  }

  String _summary(DayPlan day) {
    final parts = <String>[
      if (day.courseCount > 0) '${day.courseCount} 节课',
      if (day.activityCount > 0) '${day.activityCount} 个活动',
      if (day.pendingTodoCount > 0) '${day.pendingTodoCount} 个待办',
      if (day.doneTodoCount > 0) '${day.doneTodoCount} 个已完成',
    ];
    if (parts.isEmpty) {
      return day.isPast ? '已过去 · 不计算空闲' : '没有安排';
    }
    if (day.isPast) return '${parts.join(' · ')} · 已过去';
    final free = day.freeSlots.isEmpty
        ? '无整段空闲'
        : '空闲 ${day.freeSlots.length} 段';
    return '${parts.join(' · ')} · $free';
  }
}
