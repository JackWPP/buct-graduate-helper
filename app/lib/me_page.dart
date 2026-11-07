import 'package:flutter/material.dart';

import 'format.dart';
import 'icons.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'widgets.dart';

class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.snap,
    required this.onProfile,
    required this.onProgress,
    required this.onApplications,
    required this.onGrades,
    required this.onSelected,
    required this.onEval,
    required this.onExams,
    required this.onNotices,
    required this.onSettings,
    this.onRefresh,
    this.lastRefreshedAt,
  });

  final Snapshot snap;
  final VoidCallback onProfile;
  final VoidCallback onProgress;
  final VoidCallback onApplications;
  final VoidCallback onGrades;
  final VoidCallback onSelected;
  final VoidCallback onEval;
  final VoidCallback onExams;
  final VoidCallback onNotices;
  final VoidCallback onSettings;
  final Future<void> Function()? onRefresh;
  final DateTime? lastRefreshedAt;

  @override
  Widget build(BuildContext context) {
    final student = snap.student;
    final credits = snap.credits;
    final apps = previewApplications(snap.applications);
    final pending = pendingEvalCount(snap.evaluations);
    final content = ListView(
      key: const Key('me-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const PageTitle(title: '我的'),
        if (lastRefreshedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: UpdateStamp(time: lastRefreshedAt),
          ),
        HuayanCard(
          onTap: onProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: HuayanColors.blueSoft,
                child: Text(
                  student.name.isEmpty ? '研' : student.name.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HuayanColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${student.id}${student.college.isEmpty ? '' : ' · ${student.college}'}\n${student.major}${student.advisor.isEmpty ? '' : ' · 导师 ${student.advisor}'}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: HuayanColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (credits != null)
          HuayanCard(
            onTap: onProgress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        '培养进度',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: HuayanColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '查看明细',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: HuayanColors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatNum(credits.selected),
                      style: const TextStyle(
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: HuayanColors.ink,
                      ),
                    ),
                    Text(
                      ' / ${formatNum(credits.requiredCredits)} 学分',
                      style: const TextStyle(
                        fontSize: 15,
                        color: HuayanColors.faint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CreditBar(
                  fraction: credits.requiredCredits == 0
                      ? 0
                      : credits.selected / credits.requiredCredits,
                ),
                const SizedBox(height: 10),
                Text(
                  '还差 ${formatNum((credits.requiredCredits - credits.selected).clamp(0, double.infinity))} 学分',
                  style: const TextStyle(
                    fontSize: 12,
                    color: HuayanColors.faint,
                  ),
                ),
              ],
            ),
          ),
        if (apps.isNotEmpty)
          HuayanCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '我的申请',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: HuayanColors.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onApplications,
                      style: TextButton.styleFrom(
                        foregroundColor: HuayanColors.blue,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        '全部 ${snap.applications.length} 项',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                for (final item in apps) _AppRow(item: item),
              ],
            ),
          ),
        _MenuGroup(
          children: [
            _MenuRow(
              title: '成绩单',
              value: snap.grades.isEmpty ? '本学期未出分' : '${snap.grades.length} 条',
              onTap: onGrades,
            ),
            _MenuRow(
              title: '已修课程',
              value: credits == null
                  ? '${snap.courses.length} 门'
                  : '${snap.courses.length} 门 · ${formatNum(credits.selected)} 学分',
              onTap: onSelected,
            ),
            _MenuRow(title: '我的评价', value: '$pending 门未评', onTap: onEval),
            _MenuRow(
              title: '考试与调课',
              value: snap.exams == 0 ? '还没有安排' : '${snap.exams} 条',
              onTap: onExams,
            ),
            _MenuRow(
              title: '消息与提醒',
              value: snap.notices == 0 ? '暂无通知' : '${snap.notices} 条',
              onTap: onNotices,
            ),
            _MenuRow(
              key: const Key('me-settings'),
              title: '设置',
              value: '提醒与课表',
              onTap: onSettings,
            ),
          ],
        ),
      ],
    );
    final refresh = onRefresh;
    if (refresh == null) return content;
    return RefreshIndicator(
      key: const Key('me-refresh'),
      onRefresh: refresh,
      child: content,
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.item});

  final ApplicationItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.tone == 'ok' ? HuayanColors.ok : HuayanColors.amberInk;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HuayanColors.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: HuayanColors.ink,
                  ),
                ),
                if (item.time.isNotEmpty)
                  Text(
                    item.time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HuayanColors.sub,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HuayanCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(children: children),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, color: HuayanColors.ink),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, color: HuayanColors.faint),
            ),
            const HuayanChevron(),
          ],
        ),
      ),
    );
  }
}
