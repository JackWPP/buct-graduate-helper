import 'package:flutter/material.dart';

import 'format.dart';
import 'icons.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'widgets.dart';

/// 学业总览：把成绩、考试、培养进度和评教集中在一个主 Tab。
class AcademicsPage extends StatelessWidget {
  const AcademicsPage({
    super.key,
    required this.snap,
    required this.onGrades,
    required this.onExams,
    required this.onProgress,
    required this.onEval,
    required this.onSelected,
  });

  final Snapshot snap;
  final VoidCallback onGrades;
  final VoidCallback onExams;
  final VoidCallback onProgress;
  final VoidCallback onEval;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final credits = snap.credits;
    final pending = pendingEvalCount(snap.evaluations);
    return ListView(
      key: const Key('academics-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const PageTitle(title: '学业'),
        const Text(
          '成绩、考试、培养进度和评教，都在这里一站式查看。',
          style: TextStyle(fontSize: 13, height: 1.5, color: HuayanColors.sub),
        ),
        const SizedBox(height: 14),
        HuayanCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _Metric(
                      label: '培养方案学分',
                      value: credits == null
                          ? '—'
                          : '${formatNum(credits.selected)} / ${formatNum(credits.requiredCredits)}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  _Metric(
                    label: '总 GPA',
                    value: credits?.gpa == null
                        ? '—'
                        : formatNum(credits!.gpa!),
                    alignEnd: true,
                  ),
                ],
              ),
              if (credits != null) ...[
                const SizedBox(height: 14),
                CreditBar(
                  fraction: credits.requiredCredits == 0
                      ? 0
                      : credits.selected / credits.requiredCredits,
                ),
                const SizedBox(height: 10),
                Text(
                  credits.requiredCredits == 0
                      ? '还没有培养方案学分要求'
                      : '还差 ${formatNum((credits.requiredCredits - credits.selected).clamp(0, double.infinity))} 学分',
                  style: const TextStyle(
                    fontSize: 12,
                    color: HuayanColors.faint,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                key: const Key('academics-exams'),
                icon: 'clipboard',
                label: '考试安排',
                value: snap.examItems.isEmpty
                    ? '暂无安排'
                    : '${snap.examItems.length} 场',
                onTap: onExams,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoTile(
                key: const Key('academics-eval'),
                icon: 'star',
                label: '课程评教',
                value: pending == 0 ? '已完成' : '$pending 门待评',
                tone: pending == 0 ? HuayanColors.ok : HuayanColors.amberInk,
                onTap: onEval,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ActionRow(
          icon: 'chart',
          title: '成绩单',
          subtitle: '按学期查看课程成绩和学分',
          onTap: onGrades,
        ),
        _ActionRow(
          icon: 'book',
          title: '培养进度',
          subtitle: '方案完成度、课程分类和缺分项',
          onTap: onProgress,
        ),
        _ActionRow(
          icon: 'check',
          title: '选课结果',
          subtitle: '本学期已选课程和学分',
          onTap: onSelected,
        ),
        const SizedBox(height: 18),
        const Text(
          '最近成绩',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: HuayanColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (snap.grades.isEmpty)
          const EmptyHint(
            title: '还没有成绩',
            text: '学校还没有返回成绩记录。出分后会显示在这里。',
            glyph: 'chart',
          )
        else
          for (final grade in snap.grades.take(5))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: HuayanColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HuayanColors.lineSoft),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          grade.courseName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: HuayanColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${grade.termName} · ${formatNum(grade.credits)} 学分',
                          style: const TextStyle(
                            fontSize: 12,
                            color: HuayanColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    grade.score.isEmpty ? '—' : grade.score,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: HuayanColors.ink,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: HuayanColors.faint),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: HuayanColors.ink,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.tone = HuayanColors.blue,
  });

  final String icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return HuayanCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: HuayanIcon(icon, size: 20, color: tone)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: HuayanColors.sub),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HuayanColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HuayanColors.lineSoft),
            ),
            child: Row(
              children: [
                HuayanIcon(icon, size: 22, color: HuayanColors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HuayanColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HuayanColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                const HuayanChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
