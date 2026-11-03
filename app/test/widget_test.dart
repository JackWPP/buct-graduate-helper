import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/main.dart';
import 'package:huayan/schedule.dart';

void main() {
  testWidgets('week 10 lists the tuesday classes and keeps exams empty', (tester) async {
    final snap = Snapshot(
      termName: '2026-2027秋季学期',
      termStart: '2026-08-31',
      studentName: '测试',
      notices: 0,
      exams: 0,
      courses: [
        decorateCourse(Course.fromJson(const {
          'id': 'a',
          'name': '数值分析',
          'room': '科303',
          'teacher': '甲',
          'online': false,
          'ksz': 1,
          'jsz': 16,
          'pattern': '连续周',
          'sjms': '星期二 上午1 -上午2',
          'credits': 3,
        })),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: TimetablePage(snap: snap, initialWeek: 10),
    ));
    await tester.pump();
    expect(find.text('第 10 周'), findsOneWidget);
    expect(find.text('数值分析'), findsOneWidget);
    expect(find.text('08:00–09:35 · 科303'), findsOneWidget);
  });
}
