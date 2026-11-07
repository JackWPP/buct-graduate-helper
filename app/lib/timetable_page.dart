import 'package:flutter/material.dart';

import 'icons.dart';
import 'schedule.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'widgets.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({
    super.key,
    required this.snap,
    required this.now,
    required this.settings,
    required this.onCourse,
    required this.onOnline,
    this.initialWeek,
    this.onRefresh,
    this.lastRefreshedAt,
    this.offline = false,
  });

  final Snapshot snap;
  final DateTime now;
  final AppSettings settings;
  final void Function(Course course, int week) onCourse;
  final VoidCallback onOnline;
  final int? initialWeek;
  final Future<void> Function()? onRefresh;
  final DateTime? lastRefreshedAt;
  final bool offline;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late int _week;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    _week = _clamped(
      widget.initialWeek ?? weekIndex(widget.now, widget.snap.termStart),
    );
  }

  int get _max =>
      termMaxWeek(widget.snap.courses, widget.now, widget.snap.termStart);

  int _clamped(int week) => clampWeek(week, _max);

  void _shift(int delta) => setState(() => _week = _clamped(_week + delta));

  Future<void> _pickWeek() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 360,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '选择周次',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _max,
                  itemBuilder: (context, index) {
                    final week = index + 1;
                    final active = week == _week;
                    return Material(
                      color: active ? HuayanColors.blue : HuayanColors.card,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        key: Key('week-option-$week'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(week),
                        child: Center(
                          child: Text(
                            '$week',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : HuayanColors.ink,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _week = _clamped(picked));
    }
  }

  Course? _course(String id) {
    for (final course in widget.snap.courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final days = visibleWeekdays(widget.snap.courses);
    final blocks = blocksForWeek(
      widget.snap.courses,
      _week,
      showOffWeek: widget.settings.showOffWeek,
    );
    final monday = weekMonday(_week, widget.snap.termStart);
    final sunday = addDays(monday, 6);
    final todayWeek = weekIndex(widget.now, widget.snap.termStart);
    final todayIndex = (widget.now.weekday + 6) % 7;
    final online = widget.snap.courses.where((course) => course.online).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '课表',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: HuayanColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('back-today'),
                    onPressed: () => setState(
                      () => _week = _clamped(todayWeek < 1 ? 1 : todayWeek),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: HuayanColors.blue,
                      backgroundColor: HuayanColors.blueSoft,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      '回到今天',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  IconButton(
                    key: const Key('week-prev'),
                    onPressed: _week <= 1 ? null : () => _shift(-1),
                    tooltip: '上一周',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const RotatedBox(
                      quarterTurns: 2,
                      child: HuayanIcon(
                        'chev',
                        size: 22,
                        color: HuayanColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('week-picker'),
                    onPressed: _pickWeek,
                    style: TextButton.styleFrom(
                      foregroundColor: HuayanColors.ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '第 $_week 周',
                          key: const Key('week-label'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HuayanColors.ink,
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: HuayanColors.faint,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('week-next'),
                    onPressed: _week >= _max ? null : () => _shift(1),
                    tooltip: '下一周',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const HuayanIcon(
                      'chev',
                      size: 22,
                      color: HuayanColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${formatMonthDay(monday)} – ${formatMonthDay(sunday)}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: HuayanColors.sub,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: SizedBox(
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 28),
                for (final day in days)
                  Expanded(
                    child: _DayHead(
                      day: day,
                      date: addDays(monday, day),
                      today: _week == todayWeek && day == todayIndex,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.lastRefreshedAt != null || widget.offline)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                if (widget.offline)
                  Expanded(
                    child: OfflineBanner(
                      message: '当前显示缓存课表，下拉可重试',
                      onRetry: widget.onRefresh,
                    ),
                  )
                else
                  UpdateStamp(time: widget.lastRefreshedAt),
              ],
            ),
          ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragStart: (_) => _dragDx = 0,
            onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final dx = _dragDx;
              if (dx.abs() < 56 && velocity.abs() < 240) return;
              final forward = dx.abs() >= 56 ? dx < 0 : velocity < 0;
              _shift(forward ? 1 : -1);
            },
            child: widget.onRefresh == null
                ? _grid(days, blocks, online)
                : RefreshIndicator(
                    key: const Key('timetable-refresh'),
                    onRefresh: widget.onRefresh!,
                    child: _grid(days, blocks, online),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _grid(List<int> days, List<Block> blocks, int online) {
    return ListView(
      key: const Key('timetable-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      children: [
        SizedBox(
          height: gridHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: gridHeight,
                child: _TimeAxis(periods: widget.snap.periods),
              ),
              for (final day in days)
                Expanded(
                  child: _DayColumn(
                    blocks: blocks
                        .where((block) => block.weekday == day)
                        .toList(),
                    colors: widget.settings.colors,
                    courseOf: _course,
                    onCourse: (course) => widget.onCourse(course, _week),
                  ),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: online == 0 ? null : widget.onOnline,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '线上课程 $online 门 · 不占课时',
              style: const TextStyle(
                fontSize: 13,
                color: HuayanColors.sub,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHead extends StatelessWidget {
  const _DayHead({required this.day, required this.date, required this.today});

  final int day;
  final DateTime date;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final color = today ? HuayanColors.blue : HuayanColors.faint;
    final dateColor = today ? HuayanColors.blue : HuayanColors.ink;
    return Column(
      children: [
        Text(
          weekdayLabel[day],
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
            letterSpacing: -0.4,
          ),
        ),
        Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: dateColor,
          ),
        ),
      ],
    );
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.periods});

  final List<Period> periods;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final period in periods)
          Positioned(
            top: periodTop(period.n),
            left: 0,
            right: 0,
            child: Text(
              period.start,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 8,
                height: 1,
                color: HuayanColors.faint,
                letterSpacing: -0.3,
              ),
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.blocks,
    required this.colors,
    required this.courseOf,
    required this.onCourse,
  });

  final List<Block> blocks;
  final Map<String, String> colors;
  final Course? Function(String id) courseOf;
  final ValueChanged<Course> onCourse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFEEF1F6))),
      ),
      child: SizedBox(
        height: gridHeight,
        child: Stack(
          children: [
            for (final block in blocks)
              Positioned(
                top: periodTop(block.startPeriod),
                height: spanHeight(block.startPeriod, block.endPeriod),
                left: 1,
                right: 1,
                child: _CourseBlock(
                  block: block,
                  course: courseOf(block.courseId),
                  colors: colors,
                  onCourse: onCourse,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.block,
    required this.course,
    required this.colors,
    required this.onCourse,
  });

  final Block block;
  final Course? course;
  final Map<String, String> colors;
  final ValueChanged<Course> onCourse;

  @override
  Widget build(BuildContext context) {
    final tone = CourseTone.fromHex(courseColor(block.name, colors));
    final height = spanHeight(block.startPeriod, block.endPeriod);
    final nameLines = ((height - 16) / 11).floor().clamp(1, 6);
    return Opacity(
      opacity: block.active ? 1 : 0.45,
      child: Material(
        color: tone.background,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          key: Key('block-${block.id}'),
          onTap: course == null ? null : () => onCourse(course!),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tone.border),
            ),
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.name,
                  maxLines: nameLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: tone.foreground,
                  ),
                ),
                if (block.room.isNotEmpty && height > 28)
                  Text(
                    block.room,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                      color: tone.foreground.withValues(alpha: 0.82),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
