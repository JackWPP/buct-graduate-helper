import 'package:flutter/material.dart';

import 'format.dart';
import 'icons.dart';
import 'schedule.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.snap,
    required this.now,
    required this.onCourse,
    required this.onProgress,
    required this.onNotices,
    required this.onEval,
    required this.onGrades,
    required this.onExams,
    required this.onSelected,
    this.onActivities,
    this.onRefresh,
    this.lastRefreshedAt,
    this.offline = false,
  });

  final Snapshot snap;
  final DateTime now;
  final ValueChanged<Course> onCourse;
  final VoidCallback onProgress;
  final VoidCallback onNotices;
  final VoidCallback onEval;
  final VoidCallback onGrades;
  final VoidCallback onExams;
  final VoidCallback onSelected;
  final VoidCallback? onActivities;
  final Future<void> Function()? onRefresh;
  final DateTime? lastRefreshedAt;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final week = weekIndex(now, snap.termStart);
    final day = sessionsOn(snap.courses, now, snap.termStart);
    final hero = pickHero(day.items, now);
    final content = ListView(
      key: const Key('home-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${greeting(now)}，${snap.studentName}',
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: HuayanColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snap.termName} · ${weekText(week)}${snap.updatedLabel.isEmpty ? '' : '\n更新于 ${snap.updatedLabel}'}',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: HuayanColors.sub,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('notices-button'),
              onPressed: onNotices,
              tooltip: '通知',
              icon: const HuayanIcon('bell', size: 22, color: HuayanColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (lastRefreshedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: UpdateStamp(time: lastRefreshedAt),
          ),
        if (offline)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OfflineBanner(
              message: '当前显示上次缓存的数据，下拉可重试',
              onRetry: onRefresh,
            ),
          ),
        _HeroCard(now: now, hero: hero, items: day.items, onCourse: onCourse),
        if (onActivities != null) _ActivityEntry(onTap: onActivities!),
        const SizedBox(height: 4),
        _QuickActions(
          onGrades: onGrades,
          onExams: onExams,
          onNotices: onNotices,
          onSelected: onSelected,
          onEval: onEval,
          onProgress: onProgress,
          pendingEval: pendingEvalCount(snap.evaluations),
        ),
        if (snap.examItems.isNotEmpty)
          _ExamCard(exam: snap.examItems.first, onTap: onExams),
        if (pendingEvalCount(snap.evaluations) > 0)
          _EvalCard(count: pendingEvalCount(snap.evaluations), onTap: onEval),
        if (snap.credits != null) _CreditCard(snap: snap, onTap: onProgress),
      ],
    );
    final refresh = onRefresh;
    if (refresh == null) return content;
    return RefreshIndicator(
      key: const Key('home-refresh'),
      onRefresh: refresh,
      child: content,
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onTap});

  final ExamItem exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil(exam.date);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: HuayanColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: HuayanColors.lineSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: HuayanColors.blueSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Center(
                    child: HuayanIcon(
                      'clipboard',
                      size: 21,
                      color: HuayanColors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '最近考试',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HuayanColors.sub,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        exam.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: HuayanColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          exam.date,
                          exam.startTime,
                          exam.room,
                        ].where((value) => value.isNotEmpty).join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: HuayanColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (days != null)
                  Text(
                    days < 0 ? '已结束' : (days == 0 ? '今天' : '还有 $days 天'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: HuayanColors.amberInk,
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

int? _daysUntil(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(parsed.year, parsed.month, parsed.day);
  return day.difference(today).inDays;
}

class _ActivityEntry extends StatelessWidget {
  const _ActivityEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: HuayanCard(
        key: const Key('home-activities'),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HuayanColors.amberSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                color: HuayanColors.amberInk,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '活动报名',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: HuayanColors.ink,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '学术报告 · 劳动实践 · 自动监测',
                    style: TextStyle(fontSize: 12, color: HuayanColors.sub),
                  ),
                ],
              ),
            ),
            const HuayanChevron(),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onGrades,
    required this.onExams,
    required this.onNotices,
    required this.onSelected,
    required this.onEval,
    required this.onProgress,
    required this.pendingEval,
  });

  final VoidCallback onGrades;
  final VoidCallback onExams;
  final VoidCallback onNotices;
  final VoidCallback onSelected;
  final VoidCallback onEval;
  final VoidCallback onProgress;
  final int pendingEval;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      children: [
        _QuickAction(icon: 'chart', label: '成绩', onTap: onGrades),
        _QuickAction(icon: 'clipboard', label: '考试', onTap: onExams),
        _QuickAction(icon: 'bell', label: '通知', onTap: onNotices),
        _QuickAction(icon: 'grid', label: '选课', onTap: onSelected),
        _QuickAction(
          icon: 'star',
          label: pendingEval > 0 ? '评教 · $pendingEval' : '评教',
          onTap: onEval,
        ),
        _QuickAction(icon: 'book', label: '培养', onTap: onProgress),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HuayanColors.card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: HuayanColors.lineSoft),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HuayanIcon(icon, size: 22, color: HuayanColors.blue),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HuayanColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.now,
    required this.hero,
    required this.items,
    required this.onCourse,
  });

  final DateTime now;
  final HeroPick hero;
  final List<Session> items;
  final ValueChanged<Course> onCourse;

  @override
  Widget build(BuildContext context) {
    final weekday = weekdayLabel[(now.weekday + 6) % 7];
    final head = Row(
      children: [
        Expanded(
          child: Text(
            '今天 · $weekday',
            style: const TextStyle(fontSize: 13, color: HuayanColors.sub),
          ),
        ),
        Text(
          formatMonthDay(now),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: HuayanColors.faint,
          ),
        ),
      ],
    );
    final item = hero.item;
    if (hero.kind == 'empty' || item == null) {
      return HuayanCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            head,
            const SizedBox(height: 12),
            const Text(
              '今天没有线下课',
              style: TextStyle(
                fontSize: 22,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: HuayanColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '线上课不占教室，收在课表最下面。',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: HuayanColors.sub,
              ),
            ),
          ],
        ),
      );
    }
    final course = item.course;
    if (hero.kind == 'done') {
      return HuayanCard(
        onTap: () => onCourse(course),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            head,
            const SizedBox(height: 12),
            const Text(
              '今天的课上完了',
              style: TextStyle(
                fontSize: 22,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: HuayanColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${course.name} · ${item.seg.endTime} 结束',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: HuayanColors.sub,
              ),
            ),
          ],
        ),
      );
    }
    final live = hero.kind == 'ongoing';
    final remain = live
        ? '还剩 ${formatDuration(hero.minutes)}'
        : '还有 ${formatDuration(hero.minutes)}';
    return HuayanCard(
      onTap: () => onCourse(course),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: live
                            ? HuayanColors.amberSoft
                            : HuayanColors.blueSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        live ? '正在上' : '下一节',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: live
                              ? HuayanColors.amberInk
                              : HuayanColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.seg.startTime,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: HuayanColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                remain,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HuayanColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            course.name,
            style: const TextStyle(
              fontSize: 22,
              height: 1.3,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: HuayanColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${placeOf(course)} · ${course.teacher} · ${course.ksz}–${course.jsz} 周 · ${formatNum(course.credits)} 学分',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: HuayanColors.sub,
            ),
          ),
          _HeroFoot(now: now, hero: hero, items: items),
        ],
      ),
    );
  }
}

class _HeroFoot extends StatelessWidget {
  const _HeroFoot({required this.now, required this.hero, required this.items});

  final DateTime now;
  final HeroPick hero;
  final List<Session> items;

  @override
  Widget build(BuildContext context) {
    final nowMin = now.hour * 60 + now.minute;
    final rest = items.where((item) => item != hero.item);
    final later = rest.where((item) => item.startMin > nowMin).toList();
    final earlier = rest.where((item) => item.endMin <= nowMin).toList();
    final bits = <String>[];
    if (later.isNotEmpty) {
      bits.add(
        '今天还有 ${later.length} 门${later.map((item) => ' · ${item.seg.startTime} ${item.course.name}').join()}',
      );
    }
    if (earlier.isNotEmpty) {
      bits.add('已上完 ${earlier.map((item) => item.course.name).join('、')}');
    }
    if (bits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HuayanColors.lineSoft)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            bits.join(' · '),
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: HuayanColors.sub,
            ),
          ),
        ),
      ),
    );
  }
}

class _EvalCard extends StatelessWidget {
  const _EvalCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HuayanColors.amberSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFF4E3C4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('eval-card'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '最要紧的一件事',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HuayanColors.amberInk,
                        ),
                      ),
                    ),
                    Text(
                      '去评教',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: HuayanColors.amberInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '还有 $count 门课没评',
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '课程结束后一个月内需要评完，否则可能影响查成绩。学校没有返回具体截止日期。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: Color(0xFF6F5424),
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

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.snap, required this.onTap});

  final Snapshot snap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final credits = snap.credits!;
    final ratio = credits.requiredCredits == 0
        ? 0.0
        : credits.selected / credits.requiredCredits;
    return HuayanCard(
      key: const Key('credit-card'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '培养方案学分',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.ink,
                  ),
                ),
              ),
              Text(
                '${formatNum(credits.selected)} / ${formatNum(credits.requiredCredits)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HuayanColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CreditBar(fraction: ratio),
          const SizedBox(height: 10),
          Text(
            '还差 ${formatNum((credits.requiredCredits - credits.selected).clamp(0, double.infinity))} 学分 · 本学期 ${snap.courses.length} 门课',
            style: const TextStyle(fontSize: 12, color: HuayanColors.faint),
          ),
        ],
      ),
    );
  }
}
