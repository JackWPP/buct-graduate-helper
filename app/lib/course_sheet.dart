import 'package:flutter/material.dart';

import 'format.dart';
import 'schedule.dart';
import 'theme.dart';
import 'widgets.dart';

void openCourseSheet(
  BuildContext context, {
  required Course course,
  required int week,
  required DateTime now,
  required String termStart,
}) {
  final navigator = Navigator.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return CourseSheet(
        course: course,
        week: week,
        onDetail: () {
          Navigator.of(sheetContext).pop();
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => CourseDetailPage(
                course: course,
                now: now,
                termStart: termStart,
              ),
            ),
          );
        },
      );
    },
  );
}

class CourseSheet extends StatelessWidget {
  const CourseSheet({
    super.key,
    required this.course,
    required this.week,
    this.onDetail,
  });

  final Course course;
  final int week;
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context) {
    final thisWeek = course.weeks.contains(week) ? '本周有课' : '本周无课';
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: HuayanColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Padding(
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
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                course.name,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: HuayanColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${categoryName(course)} · ${formatNum(course.credits)} 学分',
                style: const TextStyle(fontSize: 12, color: HuayanColors.faint),
              ),
              const SizedBox(height: 8),
              KvRow(label: '上课时间', value: courseTimeText(course)),
              KvRow(
                label: '上课地点',
                value: placeOf(course).isEmpty ? '未安排教室' : placeOf(course),
              ),
              KvRow(
                label: '任课教师',
                value: course.teacher.isEmpty ? '未填写' : course.teacher,
              ),
              KvRow(
                label: '上课周次',
                value: '${course.ksz}–${course.jsz} 周 · $thisWeek',
              ),
              if (onDetail != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: onDetail,
                    style: FilledButton.styleFrom(
                      backgroundColor: HuayanColors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('查看完整详情'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({
    super.key,
    required this.course,
    required this.now,
    required this.termStart,
  });

  final Course course;
  final DateTime now;
  final String termStart;

  @override
  Widget build(BuildContext context) {
    final week = weekIndex(now, termStart);
    final progress = weekProgress(course, week);
    final phase = switch (progress.phase) {
      'upcoming' => '还没开始 · 共 ${progress.total} 周',
      'ended' => '这个上课周期已经结束',
      'current' =>
        '第 $week 周 · ${course.ksz}–${course.jsz} 周 · 还剩 ${progress.remain} 周',
      _ => '这份快照没有排上课周次',
    };
    final thisWeek = course.weeks.contains(week) ? '本周有课' : '本周无课';
    final ratio = progress.total == 0 ? 0.0 : progress.done / progress.total;
    final tone = CourseTone.fromHex(courseColor(course.name));
    return Subpage(
      title: '课程',
      children: [
        Text(
          course.name,
          style: const TextStyle(
            fontSize: 26,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: HuayanColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${course.className} · ${course.teacher}',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: HuayanColors.sub,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${formatNum(course.credits)} 学分${course.hours == null ? '' : ' · ${course.hours} 学时'}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: HuayanColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        HuayanCard(
          child: Column(
            children: [
              KvRow(label: '上课时间', value: courseTimeText(course)),
              KvRow(
                label: '上课地点',
                value: placeOf(course).isEmpty ? '未安排教室' : placeOf(course),
              ),
              KvRow(
                label: '上课周次',
                value:
                    '${course.ksz}–${course.jsz} 周 · ${course.pattern} · $thisWeek',
              ),
              KvRow(
                label: '课程编号',
                value: course.code.isEmpty ? '未填写' : course.code,
              ),
            ],
          ),
        ),
        HuayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '课程进度',
                      style: TextStyle(fontSize: 13, color: HuayanColors.sub),
                    ),
                  ),
                  Text(
                    '${progress.done} / ${progress.total} 周',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HuayanColors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                phase,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: HuayanColors.sub,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      const ColoredBox(
                        color: Color(0xFFE8EDF4),
                        child: SizedBox.expand(),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio.clamp(0, 1).toDouble(),
                        child: ColoredBox(color: tone.foreground),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Text(
          '上课提醒留在设置里。这版不会在后台响铃。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: HuayanColors.faint,
          ),
        ),
      ],
    );
  }
}
