import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:huayan/schedule.dart';

void main() {
  runApp(const HuayanApp());
}

class HuayanApp extends StatelessWidget {
  const HuayanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '化研助手',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6BFF)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  Snapshot? _snap;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/snapshot.json');
      setState(() => _snap = Snapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (error) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    final pages = snap == null
        ? const <Widget>[
            _Status(text: '正在读取课表'),
            _Status(text: '正在读取课表'),
            _Status(text: '正在读取课表'),
          ]
        : [
            TimetablePage(snap: snap),
            EmptyExport(title: '考试', count: snap.exams, hint: '考场和调课导出是空的，这里不编倒计时。'),
            EmptyExport(title: '通知', count: snap.notices, hint: '通知列表还没有学校数据，这里保持空态。'),
          ];
    return Scaffold(
      body: SafeArea(
        child: _error != null ? _Status(text: '课表没有载入') : pages[_tab],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: '课表'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: '考试'),
          NavigationDestination(icon: Icon(Icons.notifications_none), label: '通知'),
        ],
      ),
    );
  }
}

class Snapshot {
  Snapshot({
    required this.termName,
    required this.termStart,
    required this.studentName,
    required this.courses,
    required this.notices,
    required this.exams,
  });

  final String termName;
  final String termStart;
  final String studentName;
  final List<Course> courses;
  final int notices;
  final int exams;

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    final term = Map<String, dynamic>.from(json['term'] as Map);
    final student = Map<String, dynamic>.from(json['student'] as Map);
    final courses = (json['courses'] as List)
        .map((item) => decorateCourse(Course.fromJson(Map<String, dynamic>.from(item as Map))))
        .toList();
    return Snapshot(
      termName: '${term['name'] ?? ''}',
      termStart: '${term['start']}',
      studentName: '${student['xm'] ?? ''}',
      courses: courses,
      notices: (json['notices'] as List?)?.length ?? 0,
      exams: (json['exams'] as List?)?.length ?? 0,
    );
  }
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key, required this.snap, this.initialWeek});

  final Snapshot snap;
  final int? initialWeek;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late int _week;

  @override
  void initState() {
    super.initState();
    final week = widget.initialWeek ?? weekIndex(DateTime.now(), widget.snap.termStart);
    _week = week < 1 ? 1 : week;
  }

  @override
  Widget build(BuildContext context) {
    final days = visibleWeekdays(widget.snap.courses);
    final blocks = blocksForWeek(widget.snap.courses, _week);
    final monday = weekMonday(_week, widget.snap.termStart);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(widget.snap.studentName, style: const TextStyle(color: Color(0xFF5B6273), fontSize: 13)),
        const SizedBox(height: 4),
        const Text('课表', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(widget.snap.termName, style: const TextStyle(color: Color(0xFF5B6273))),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(onPressed: _week <= 1 ? null : () => setState(() => _week -= 1), icon: const Icon(Icons.chevron_left)),
            Text('第 $_week 周', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            IconButton(onPressed: () => setState(() => _week += 1), icon: const Icon(Icons.chevron_right)),
            const Spacer(),
            Text('${monday.month}月${monday.day}日起', style: const TextStyle(color: Color(0xFF5B6273))),
          ],
        ),
        for (final day in days) ...[
          const SizedBox(height: 8),
          Text(weekdayLabel[day], style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ..._dayBlocks(blocks, day),
        ],
      ],
    );
  }

  List<Widget> _dayBlocks(List<Block> blocks, int day) {
    final items = blocks.where((block) => block.weekday == day).toList();
    if (items.isEmpty) {
      return const [Text('这天没有线下课', style: TextStyle(color: Color(0xFF9AA1B2)))];
    }
    return [
      for (final block in items)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(block.name),
            subtitle: Text('${block.startTime}–${block.endTime} · ${block.room}'),
          ),
        ),
    ];
  }
}

class EmptyExport extends StatelessWidget {
  const EmptyExport({super.key, required this.title, required this.count, required this.hint});

  final String title;
  final int count;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(count == 0 ? hint : '$count 条', style: const TextStyle(color: Color(0xFF5B6273), height: 1.5)),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text));
  }
}
