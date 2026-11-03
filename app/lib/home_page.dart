import 'package:flutter/material.dart';

import 'format.dart';
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
  });

  final Snapshot snap;
  final DateTime now;
  final ValueChanged<Course> onCourse;
  final VoidCallback onProgress;
  final VoidCallback onNotices;

  @override
  Widget build(BuildContext context) {
    final week = weekIndex(now, snap.termStart);
    final day = sessionsOn(snap.courses, now, snap.termStart);
    final hero = pickHero(day.items, now);
    return ListView(
      key: const Key('home-scroll'),
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
              icon: const Icon(
                Icons.notifications_none,
                color: HuayanColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _HeroCard(now: now, hero: hero, items: day.items, onCourse: onCourse),
        if (snap.credits != null) _CreditCard(snap: snap, onTap: onProgress),
      ],
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
            '还差 ${formatNum(credits.requiredCredits - credits.selected)} 学分 · 本学期 ${snap.courses.length} 门课',
            style: const TextStyle(fontSize: 12, color: HuayanColors.faint),
          ),
        ],
      ),
    );
  }
}
