import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/activities/activity_models.dart';
import 'package:huayan/planner/todo_models.dart';
import 'package:huayan/schedule.dart';
import 'package:huayan/settings.dart';
import 'package:huayan/snapshot.dart';
import 'package:huayan/theme.dart';
import 'package:huayan/timetable_page.dart';

Course _course(String id, String name, String sjms) {
  return decorateCourse(
    Course.fromJson({
      'id': id,
      'name': name,
      'className': '1班',
      'code': id,
      'credits': 3,
      'teacher': '老师',
      'room': '科303',
      'online': false,
      'ksz': 1,
      'jsz': 20,
      'pattern': '连续周',
      'sjms': sjms,
    }),
  );
}

ActivityItem _activity() {
  return ActivityItem(
    kind: ActivityKind.academicReport,
    id: 'a1',
    applicationId: 'hd-a1',
    title: '学术报告：计算化学',
    category: '学术报告',
    publisher: '研究生院',
    organizer: '',
    location: '报告厅',
    method: '线下',
    activityStart: DateTime(2026, 11, 10, 10),
    activityEnd: DateTime(2026, 11, 10, 11),
    signupStart: DateTime(2026, 11, 1),
    signupEnd: DateTime(2026, 11, 9),
    capacity: 50,
    enrolled: 10,
    score: '',
    duration: '',
    auditStatus: '1',
    applied: true,
  );
}

TodoItem _todo() {
  return TodoItem(
    id: 't1',
    title: '交报告',
    date: '2026-11-10',
    startMin: 12 * 60,
    endMin: 12 * 60 + 30,
    createdAt: 0,
  );
}

void main() {
  final now = DateTime(2026, 11, 10, 7);
  final snap = Snapshot(
    termName: '2026-2027秋季学期',
    termStart: '2026-08-31',
    student: const Student(name: '测试', id: '2026000001'),
    courses: [
      _course('c1', '数值分析', '星期二 上午1 -上午2'),
      _course('c2', '催化化学', '星期二 下午6 -下午7'),
    ],
  );

  Future<void> phone(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('timetable switches between grid and week agenda', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: TimetablePage(
          snap: snap,
          now: now,
          settings: AppSettings(),
          initialWeek: 11,
          activities: [_activity()],
          todos: [_todo()],
          onCourse: (_, _) {},
          onOnline: () {},
          onSaveTodo: (_) async {},
          onToggleTodo: (_) {},
          onDeleteTodo: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timetable-scroll')), findsOneWidget);
    expect(find.text('数值分析'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timetable-view-agenda')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('week-agenda-scroll')), findsOneWidget);
    expect(find.text('数值分析'), findsOneWidget);
    expect(find.text('学术报告：计算化学'), findsOneWidget);
    expect(find.text('交报告'), findsOneWidget);
    expect(find.textContaining('空闲'), findsWidgets);
  });

  testWidgets('day header opens the day agenda and exposes add todo', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: TimetablePage(
          snap: snap,
          now: now,
          settings: AppSettings(),
          initialWeek: 11,
          activities: [_activity()],
          todos: [_todo()],
          onCourse: (_, _) {},
          onOnline: () {},
          onSaveTodo: (_) async {},
          onToggleTodo: (_) {},
          onDeleteTodo: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('day-head-1')));
    await tester.pumpAndSettle();

    expect(find.text('当天空闲'), findsOneWidget);
    expect(find.byKey(const Key('day-agenda-add-todo')), findsOneWidget);
    expect(find.text('学术报告：计算化学'), findsOneWidget);
    expect(find.text('交报告'), findsOneWidget);
  });

  testWidgets('todo checkbox and editor callbacks work', (tester) async {
    await phone(tester);
    final saved = <TodoItem>[];
    final toggled = <TodoItem>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: TimetablePage(
          snap: snap,
          now: now,
          settings: AppSettings(),
          initialWeek: 11,
          todos: [_todo()],
          onCourse: (_, _) {},
          onOnline: () {},
          onSaveTodo: (todo) async => saved.add(todo),
          onToggleTodo: toggled.add,
          onDeleteTodo: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('timetable-view-agenda')));
    await tester.pumpAndSettle();
    final checkbox = find.byKey(const Key('plan-todo-check-t1'));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(toggled, hasLength(1));
    expect(toggled.single.id, 't1');

    await tester.tap(find.byKey(const Key('timetable-add-todo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-title')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('todo-title')), '复习');
    final save = find.byKey(const Key('todo-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.title, '复习');
    expect(saved.single.date, '2026-11-10');
  });

  testWidgets('course row can prefill a todo with the class time', (
    tester,
  ) async {
    await phone(tester);
    final saved = <TodoItem>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: TimetablePage(
          snap: snap,
          now: now,
          settings: AppSettings(),
          initialWeek: 11,
          onCourse: (_, _) {},
          onOnline: () {},
          onSaveTodo: (todo) async => saved.add(todo),
          onToggleTodo: (_) {},
          onDeleteTodo: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('day-head-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-course-add-todo-c1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-title')), findsOneWidget);
    expect(find.text('开始 08:00'), findsOneWidget);
    expect(find.text('结束 09:35'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('todo-title')), '带作业');
    final save = find.byKey(const Key('todo-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.courseId, 'c1');
    expect(saved.single.startMin, 8 * 60);
    expect(saved.single.endMin, 9 * 60 + 35);
  });

  testWidgets('todo can be edited and deleted from the agenda', (tester) async {
    await phone(tester);
    final deleted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: TimetablePage(
          snap: snap,
          now: now,
          settings: AppSettings(),
          initialWeek: 11,
          todos: [_todo()],
          onCourse: (_, _) {},
          onOnline: () {},
          onSaveTodo: (_) async {},
          onToggleTodo: (_) {},
          onDeleteTodo: (id) async => deleted.add(id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timetable-view-agenda')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('交报告'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-title')), findsOneWidget);
    expect(
      (tester
              .widget<TextField>(find.byKey(const Key('todo-title')))
              .controller!)
          .text,
      '交报告',
    );

    final delete = find.byKey(const Key('todo-delete'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-delete-confirm')));
    await tester.pumpAndSettle();
    expect(deleted, ['t1']);
  });

  testWidgets('agenda does not overflow on a 360px phone', (tester) async {
    await phone(tester, size: const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: TimetablePage(
          snap: snap,
          now: now,
          settings: AppSettings(),
          initialWeek: 11,
          activities: [_activity()],
          todos: [_todo()],
          onCourse: (_, _) {},
          onOnline: () {},
          onSaveTodo: (_) async {},
          onToggleTodo: (_) {},
          onDeleteTodo: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timetable-view-agenda')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('week-agenda-scroll')), findsOneWidget);
  });
}
