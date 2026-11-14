import 'package:flutter/material.dart';

import 'export_ics.dart';
import 'format.dart';
import 'icons.dart';
import 'schedule.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'ui/feedback.dart';
import 'widgets.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key, required this.snap});

  final Snapshot snap;

  @override
  Widget build(BuildContext context) {
    final credits = snap.credits;
    if (credits == null) {
      return const Subpage(
        title: '培养进度',
        children: [EmptyHint(title: '还没有学分数据', text: '这份快照没有培养方案学分。')],
      );
    }
    final frontier = credits.categories.where((item) => item.name == '前沿课程');
    final frontierNote = frontier.isEmpty || frontier.first.got != 0
        ? ''
        : ' · 前沿课程 ${formatNum(frontier.first.need)} 学分未开始';
    return Subpage(
      title: '培养进度',
      children: [
        HuayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 10),
              CreditBar(
                fraction: credits.requiredCredits == 0
                    ? 0
                    : credits.selected / credits.requiredCredits,
              ),
              const SizedBox(height: 10),
              Text(
                '还差 ${formatNum((credits.requiredCredits - credits.selected).clamp(0, double.infinity))} 学分$frontierNote',
                style: const TextStyle(fontSize: 12, color: HuayanColors.faint),
              ),
            ],
          ),
        ),
        HuayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '学分构成',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: HuayanColors.ink,
                ),
              ),
              for (final item in credits.categories) _CategoryRow(item: item),
            ],
          ),
        ),
        if (credits.orphans.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HuayanColors.amberSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF3E2BC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${credits.orphans.length} 门线上课未对应培养方案条目',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${credits.orphans.map((item) => '${item.name} ${formatNum(item.credits)} 学分').join('、')}。已计入总学分，但不属于任何一类。',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: Color(0xFF6F5424),
                  ),
                ),
              ],
            ),
          ),
        Text(
          '这是已选学分，不是已出成绩。${snap.updatedLabel.isEmpty ? '' : '更新于 ${snap.updatedLabel}。'}',
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: HuayanColors.faint,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item});

  final CreditCategory item;

  @override
  Widget build(BuildContext context) {
    final done = item.need > 0 && item.got >= item.need;
    final color = done
        ? HuayanColors.ok
        : (item.got == 0 ? const Color(0xFFC4841D) : HuayanColors.ink);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HuayanColors.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 15, color: HuayanColors.ink),
            ),
          ),
          Text(
            '${formatNum(item.got)} / ${formatNum(item.need)}${done ? ' 已完成' : ''}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class GradesPage extends StatelessWidget {
  const GradesPage({super.key, required this.snap});

  final Snapshot snap;

  @override
  Widget build(BuildContext context) {
    final credits = snap.credits;
    if (snap.grades.isNotEmpty) {
      return Subpage(
        title: '成绩单',
        children: [
          Text(
            '共 ${snap.grades.length} 门课程。成绩以学校系统为准。',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: HuayanColors.sub,
            ),
          ),
          const SizedBox(height: 10),
          for (final grade in snap.grades)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: HuayanColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HuayanColors.lineSoft),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(height: 3),
                        Text(
                          '${grade.termName} · ${formatNum(grade.credits)} 学分${grade.category.isEmpty ? '' : ' · ${grade.category}'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: HuayanColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    grade.score.isEmpty ? '—' : grade.score,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: grade.score.isEmpty
                          ? HuayanColors.faint
                          : HuayanColors.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Subpage(
      title: '成绩单',
      children: [
        EmptyHint(
          title: '本学期还没有成绩',
          text: credits == null
              ? '成绩单是空的。'
              : '成绩单是空的。已选的 ${formatNum(credits.selected)} 学分在培养进度里，先不要把它当成已出分。',
          icon: Icons.bar_chart_outlined,
        ),
        if (credits != null)
          HuayanCard(
            child: Column(
              children: [
                KvRow(
                  label: '记录学分',
                  value:
                      '${formatNum(credits.recorded)} / ${formatNum(credits.requiredCredits)}',
                ),
                KvRow(
                  label: '学位课',
                  value:
                      '${formatNum(credits.degreeRecorded)} / ${formatNum(credits.degreeRequired)}',
                ),
                KvRow(
                  label: '非学位课',
                  value:
                      '${formatNum(credits.nonDegreeRecorded)} / ${formatNum(credits.nonDegreeRequired)}',
                ),
                KvRow(
                  label: '总 GPA',
                  value: credits.gpa == null
                      ? '学校还没返回'
                      : formatNum(credits.gpa!),
                ),
                KvRow(
                  label: '学位 GPA',
                  value: credits.degreeGpa == null
                      ? '学校还没返回'
                      : formatNum(credits.degreeGpa!),
                ),
              ],
            ),
          ),
        const Text(
          '毕业要求以学校公布的规则为准。这里没有自行换算 GPA。',
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

class ExamsPage extends StatelessWidget {
  const ExamsPage({super.key, required this.count, this.items = const []});

  final int count;
  final List<ExamItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Subpage(
        title: '考试',
        children: [
          Text(
            count == 0 ? '考场和调课导出是空的，这里不编倒计时。' : '$count 条',
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: HuayanColors.sub,
            ),
          ),
        ],
      );
    }
    return Subpage(
      title: '考试',
      children: [
        for (final exam in items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HuayanColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HuayanColors.lineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.courseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: HuayanColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    exam.date,
                    exam.startTime,
                    exam.room,
                  ].where((value) => value.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
                ),
                if (exam.seatNo.isNotEmpty)
                  Text(
                    '座位 ${exam.seatNo}${exam.seats == null ? '' : ' · ${exam.seats} 人考场'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HuayanColors.faint,
                    ),
                  ),
                if (_daysUntil(exam.date) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _countdownLabel(_daysUntil(exam.date)!),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HuayanColors.amberInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
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

String _countdownLabel(int days) {
  if (days < 0) return '已结束';
  if (days == 0) return '今天';
  if (days == 1) return '明天';
  return '还有 $days 天';
}

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key, required this.count, this.items = const []});

  final int count;
  final List<NoticeItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Subpage(
        title: '通知',
        children: [
          Text(
            count == 0 ? '通知列表还没有学校数据，这里保持空态。' : '$count 条',
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: HuayanColors.sub,
            ),
          ),
        ],
      );
    }
    return Subpage(
      title: '通知',
      children: [for (final notice in items) _NoticeTile(notice: notice)],
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice});

  final NoticeItem notice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HuayanColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NoticeDetailPage(notice: notice)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HuayanColors.lineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!notice.read)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(top: 6, right: 7),
                        decoration: const BoxDecoration(
                          color: HuayanColors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        notice.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HuayanColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    notice.department,
                    notice.publisher,
                    notice.publishedAt,
                  ].where((value) => value.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoticeDetailPage extends StatelessWidget {
  const NoticeDetailPage({super.key, required this.notice});

  final NoticeItem notice;

  @override
  Widget build(BuildContext context) {
    final meta = [
      notice.department,
      notice.publisher,
      notice.publishedAt,
    ].where((value) => value.isNotEmpty).join(' · ');
    return Subpage(
      title: '通知详情',
      children: [
        HuayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notice.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: HuayanColors.ink,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meta,
                  style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                notice.content.isEmpty
                    ? '学校通知正文暂未返回。这里展示通知列表中的标题和发布信息，不编造正文。'
                    : notice.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.75,
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

class UnavailablePage extends StatelessWidget {
  const UnavailablePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Subpage(
      title: title,
      children: [
        EmptyHint(
          title: '这个入口还在接入学校字段',
          text: '「$title」的页面不再外跳。学校返回字段后直接在应用内展示，不编造表单，也不代你提交。',
        ),
      ],
    );
  }
}

class EvalPage extends StatelessWidget {
  const EvalPage({super.key, required this.snap});

  final Snapshot snap;

  @override
  Widget build(BuildContext context) {
    final items = snap.evaluations;
    final pending = pendingEvalCount(items);
    return Subpage(
      title: '课程评教',
      children: [
        if (items.isEmpty)
          const EmptyHint(
            title: '评教名单是空的',
            text: '这份快照没有评教记录，这里不编待办。',
            icon: Icons.star_outline,
          )
        else ...[
          Text(
            '$pending 门未评，${items.length - pending} 门已评。评教提交接口尚未开放，当前只展示名单，不代填。',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: HuayanColors.sub,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: HuayanColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HuayanColors.lineSoft),
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
                        const SizedBox(height: 3),
                        Text(
                          '${item.teacher} · ${formatNum(item.credits)} 学分',
                          style: const TextStyle(
                            fontSize: 12,
                            color: HuayanColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.rated ? '已评' : '未评',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: item.rated
                          ? HuayanColors.ok
                          : HuayanColors.amberInk,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class SelectedPage extends StatelessWidget {
  const SelectedPage({
    super.key,
    required this.snap,
    required this.now,
    required this.onCourse,
  });

  final Snapshot snap;
  final DateTime now;
  final ValueChanged<Course> onCourse;

  @override
  Widget build(BuildContext context) {
    final credits = snap.credits;
    return Subpage(
      title: '选课',
      children: [
        Text(
          '这里是本学期已选课程${credits == null ? '' : '，共 ${formatNum(credits.selected)} 学分'}。选课或退课请从服务页进入「选课」，提交前需要二次确认和验证码。',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: HuayanColors.sub,
          ),
        ),
        const SizedBox(height: 14),
        if (snap.courses.isEmpty)
          const EmptyHint(title: '没有已选课程', text: '快照里没有课程。')
        else
          for (final course in snap.courses)
            _CourseLine(course: course, onTap: () => onCourse(course)),
      ],
    );
  }
}

class CourseCatalogPage extends StatefulWidget {
  const CourseCatalogPage({super.key, required this.snap});

  final Snapshot snap;

  @override
  State<CourseCatalogPage> createState() => _CourseCatalogPageState();
}

class _CourseCatalogPageState extends State<CourseCatalogPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final courses = widget.snap.selectionCourses.where((course) {
      if (query.isEmpty) return true;
      return [
        course.name,
        course.code,
        course.teacher,
        course.className,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    return Subpage(
      title: '课程目录',
      children: [
        TextField(
          key: const Key('catalog-search'),
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '搜索课程名、课程号或教师',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: HuayanColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '共 ${courses.length} 门课程。选课提交和退选还需要设计稿与学校接口确认，这里只读展示。',
          style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
        ),
        const SizedBox(height: 10),
        if (courses.isEmpty)
          const EmptyHint(title: '没有匹配的课程', text: '换个关键词试试。')
        else
          for (final course in courses) _SelectionLine(course: course),
      ],
    );
  }
}

class _SelectionLine extends StatelessWidget {
  const _SelectionLine({required this.course});

  final SelectionCourse course;

  @override
  Widget build(BuildContext context) {
    final status = course.selected
        ? '已选'
        : (course.selectable == 1
              ? '已选'
              : (course.selectable == 2 ? '可退选' : '可选'));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                  course.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HuayanColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    course.teacher,
                    course.room,
                    course.weeks,
                    if ((course.capacity ?? 0) > 0) '容量 ${course.capacity}',
                  ].where((value) => value.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: course.selected ? HuayanColors.ok : HuayanColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}

class OnlinePage extends StatelessWidget {
  const OnlinePage({super.key, required this.snap, required this.onCourse});

  final Snapshot snap;
  final ValueChanged<Course> onCourse;

  @override
  Widget build(BuildContext context) {
    final courses = snap.courses.where((course) => course.online).toList();
    return Subpage(
      title: '线上课程',
      children: [
        Text(
          '${courses.length} 门课的节次是占位，和线下课叠在同一格。这里单独列出，不占课表。',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: HuayanColors.sub,
          ),
        ),
        const SizedBox(height: 12),
        for (final course in courses)
          _CourseLine(course: course, onTap: () => onCourse(course)),
      ],
    );
  }
}

class _CourseLine extends StatelessWidget {
  const _CourseLine({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = CourseTone.fromHex(courseColor(course.name));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tone.foreground,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HuayanColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatNum(course.credits)} 学分 · ${course.teacher} · ${course.ksz}–${course.jsz} 周',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HuayanColors.sub,
                        ),
                      ),
                    ],
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

class GroupPage extends StatelessWidget {
  const GroupPage({super.key, required this.group, required this.onOpen});

  final ServiceGroup group;
  final ValueChanged<ServiceItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Subpage(
      title: group.name,
      children: [
        for (final item in group.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: HuayanColors.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: Key('group-service-${item.id}'),
                onTap: () => onOpen(item),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HuayanColors.lineSoft),
                  ),
                  child: Row(
                    children: [
                      HuayanIcon(
                        serviceGlyph(item.id),
                        color: const Color(0xFF8B93A7),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: HuayanColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({
    super.key,
    required this.snap,
    this.title = '我的申请',
    this.applicationIds,
  });

  final Snapshot snap;
  final String title;
  final List<String>? applicationIds;

  @override
  Widget build(BuildContext context) {
    final items = applicationIds == null
        ? snap.applications
        : snap.applications
              .where((item) => applicationIds!.contains(item.id))
              .toList();
    return Subpage(
      title: title,
      children: [
        const Text(
          '状态来自学校流程。未提交的事项学校没有给截止日期，这里不编一个。',
          style: TextStyle(fontSize: 13, height: 1.5, color: HuayanColors.sub),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const EmptyHint(
            title: '暂时没有记录',
            text: '学校还没有返回这一项。',
            glyph: 'clipboard',
          )
        else
          HuayanCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: HuayanColors.lineSoft),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: HuayanColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: item.tone == 'ok'
                                ? HuayanColors.ok
                                : HuayanColors.amberInk,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['姓名', student.name],
      ['学号', student.id],
      ['学院', student.college],
      ['专业', student.major],
      ['学生类别', student.kind],
      ['年级', student.grade],
      ['导师', student.advisor],
    ];
    return Subpage(
      title: '个人资料',
      children: [
        HuayanCard(
          child: Column(
            children: [
              for (final row in rows)
                KvRow(label: row[0], value: row[1].isEmpty ? '未填写' : row[1]),
            ],
          ),
        ),
        const Text(
          '界面只读。证件号、手机号、家庭住址和邮箱不写入快照；密码仅在开启“保持登录”时加密保存在本机。',
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.snap,
    required this.settings,
    required this.now,
    required this.onChanged,
    required this.onLogout,
    this.isLive = false,
    this.hasSavedPassword = false,
    this.onClearSavedPassword,
    this.onRefresh,
    this.termCode,
    this.onTermStart,
    this.accountCount = 1,
    this.onManageAccounts,
  });

  final Snapshot snap;
  final AppSettings settings;
  final DateTime now;
  final VoidCallback onChanged;
  final VoidCallback onLogout;
  final bool isLive;

  /// 本机是否保存了 GMIS 密码（只影响设置里的清除入口）。
  final bool hasSavedPassword;
  final int accountCount;
  final VoidCallback? onManageAccounts;
  final Future<void> Function()? onClearSavedPassword;
  final Future<bool> Function()? onRefresh;
  final String? termCode;
  final Future<void> Function(String firstMonday)? onTermStart;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings get settings => widget.settings;

  void _toggle(void Function() change) {
    change();
    widget.onChanged();
    setState(() {});
  }

  Future<void> _copyIcs() {
    return shareIcs(
      context,
      courses: widget.snap.courses,
      termStart: widget.snap.termStart,
      filename: '化研助手课表.ics',
      calendarName: '化研助手课表',
      successMessage: '已导出线下课日历，线上课已跳过',
    );
  }

  void _toast(String message) {
    AppFeedback.show(message, context: context);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出当前账号？'),
        content: const Text(
          '会清除这个账号的登录状态和加密保存的密码，账号资料和本机待办保留，可以随时切换回来。要删除账号请用“账号管理”。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '退出',
              style: TextStyle(color: HuayanColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) widget.onLogout();
  }

  Future<void> _pickTermStart() async {
    final callback = widget.onTermStart;
    if (callback == null) return;
    final current = DateTime.tryParse(widget.snap.termStart) ?? widget.now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '选择本学期第 1 周周一',
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    await callback(iso);
    if (context.mounted) _toast('学期开始日已保存');
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理本机偏好？'),
        content: const Text('提醒开关和课程颜色会恢复默认。登录状态和快照还在。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    settings.reset();
    widget.onChanged();
    setState(() {});
    _toast('本机偏好已清除');
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.snap.student;
    return Subpage(
      title: '设置',
      children: [
        _Group(
          label: '账号',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('个人资料'),
              subtitle: Text('${student.name} · ${student.id}'),
              trailing: const HuayanChevron(),
              onTap: () =>
                  Navigator.of(context)
                      .push(huayanRoute<void>(ProfilePage(student: student))),
            ),
            if (widget.onManageAccounts != null)
              ListTile(
                key: const Key('settings-accounts'),
                contentPadding: EdgeInsets.zero,
                title: const Text('账号管理'),
                subtitle: Text(
                  widget.accountCount > 1
                      ? '本机保存了 ${widget.accountCount} 个账号，可快速切换'
                      : '添加另一个账号，登录后可随时切换',
                ),
                trailing: const HuayanChevron(),
                onTap: widget.onManageAccounts,
              ),
            if (widget.isLive)
              _SwitchRow(
                title: '自动重连校外访问',
                subtitle: '统一身份认证过期时用加密保存的密码自动尝试；短信验证仍会提示。',
                value: settings.autoReconnect,
                switchKey: const Key('switch-auto-reconnect'),
                onChanged: (value) =>
                    _toggle(() => settings.autoReconnect = value),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('登录状态', style: TextStyle(fontSize: 15)),
              subtitle: Text(
                widget.isLive
                    ? widget.hasSavedPassword
                          ? '已登录学校系统；Cookie 和加密保存的密码都在系统安全存储。'
                          : '已登录学校系统，Cookie 存在系统安全存储。'
                    : '这版直接读本机快照，没有学校登录会话。',
              ),
            ),
            if (widget.isLive && widget.onRefresh != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('刷新学校数据'),
                subtitle: const Text('课表、成绩、考试和通知都会重新拉取'),
                trailing: const HuayanChevron(),
                onTap: () async {
                  final ok = await widget.onRefresh!();
                  if (context.mounted) {
                    _toast(ok ? '学校数据已刷新' : '刷新失败，请查看提示后重试');
                  }
                },
              ),
            if (widget.hasSavedPassword && widget.onClearSavedPassword != null)
              ListTile(
                key: const Key('clear-saved-password'),
                contentPadding: EdgeInsets.zero,
                title: const Text('清除已保存的登录密码', style: TextStyle(fontSize: 15)),
                subtitle: const Text('清除后，下次会话过期需要重新输入密码'),
                trailing: const HuayanChevron(),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('清除保存的密码？'),
                      content: const Text('只删除本机加密保存的密码，不影响当前登录。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await widget.onClearSavedPassword!();
                  if (context.mounted) _toast('已清除保存的密码');
                },
              ),
            ListTile(
              key: const Key('logout-button'),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '退出当前账号',
                style: TextStyle(color: HuayanColors.danger, fontSize: 15),
              ),
              onTap: _confirmLogout,
            ),
          ],
        ),
        _Group(
          label: '提醒',
          children: [
            _SwitchRow(
              title: '上课提醒',
              subtitle: '提前 ${settings.reminderMin} 分钟。应用打开时提醒；后台提醒还在接入。',
              value: settings.reminder,
              switchKey: const Key('switch-reminder'),
              onChanged: (value) => _toggle(() => settings.reminder = value),
            ),
            _SwitchRow(
              title: '截止提醒',
              subtitle: '评教和未提交事项。学校没给日期的不编截止日。',
              value: settings.deadline,
              onChanged: (value) => _toggle(() => settings.deadline = value),
            ),
            _SwitchRow(
              title: '免打扰',
              subtitle: '22:00–07:00 不提示',
              value: settings.dnd,
              onChanged: (value) => _toggle(() => settings.dnd = value),
            ),
          ],
        ),
        _Group(
          label: '课表',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('每周起始日'),
              trailing: Text(
                settings.weekStart == 'mon' ? '周一' : '周日',
                style: const TextStyle(color: HuayanColors.faint),
              ),
              onTap: () => _toggle(
                () => settings.weekStart = settings.weekStart == 'mon'
                    ? 'sun'
                    : 'mon',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('学期第 1 周'),
              subtitle: Text(
                widget.snap.termStartKnown
                    ? '已确认 · ${widget.snap.termStart}'
                    : '按当前日期估算 · ${widget.snap.termStart}',
              ),
              trailing: widget.onTermStart == null
                  ? null
                  : const HuayanChevron(),
              onTap: widget.onTermStart == null ? null : _pickTermStart,
            ),
            _SwitchRow(
              title: '显示非本周课程',
              value: settings.showOffWeek,
              switchKey: const Key('switch-offweek'),
              onChanged: (value) => _toggle(() => settings.showOffWeek = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('课程外观'),
              subtitle: const Text('配色跟着课走，不跟着格子走'),
              trailing: const HuayanChevron(),
              onTap: () => Navigator.of(context).push(
                huayanRoute<void>(
                  CourseLookPage(
                    snap: widget.snap,
                    settings: settings,
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('导出全部线下课'),
              subtitle: const Text('生成 ICS 文件，线上课会跳过'),
              onTap: _copyIcs,
            ),
          ],
        ),
        _Group(
          label: '通用与隐私',
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('深色模式'),
              subtitle: Text('跟随系统的深色模式还在设计中，当前为浅色'),
              trailing: Text(
                '跟随系统',
                style: TextStyle(color: HuayanColors.faint),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('桌面小组件'),
              subtitle: const Text('今日课程、下一节课'),
              trailing: const HuayanChevron(),
              onTap: () => Navigator.of(context).push(
                huayanRoute<void>(
                  WidgetPreviewPage(snap: widget.snap, now: widget.now),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('清理本机偏好'),
              subtitle: const Text('不清除课表快照'),
              onTap: _confirmReset,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('我们读取了哪些数据'),
              trailing: const HuayanChevron(),
              onTap: () =>
                  Navigator.of(context)
                      .push(huayanRoute<void>(DataPage(snap: widget.snap))),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('版本'),
              trailing: Text(
                appVersionLabel,
                style: TextStyle(color: HuayanColors.faint),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HuayanCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: HuayanColors.faint),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.switchKey,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, color: HuayanColors.ink),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: HuayanColors.faint,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Switch(
          key: switchKey,
          value: value,
          activeThumbColor: Colors.white,
          activeTrackColor: HuayanColors.blue,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class CourseLookPage extends StatefulWidget {
  const CourseLookPage({
    super.key,
    required this.snap,
    required this.settings,
    required this.onChanged,
  });

  final Snapshot snap;
  final AppSettings settings;
  final VoidCallback onChanged;

  @override
  State<CourseLookPage> createState() => _CourseLookPageState();
}

class _CourseLookPageState extends State<CourseLookPage> {
  @override
  Widget build(BuildContext context) {
    final courses = widget.snap.courses
        .where((course) => !course.online)
        .toList();
    return Subpage(
      title: '课程外观',
      children: [
        const Text(
          '点一下换颜色。同一门课在所有周都用这个颜色。',
          style: TextStyle(fontSize: 13, height: 1.5, color: HuayanColors.sub),
        ),
        const SizedBox(height: 12),
        for (final course in courses)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: CourseTone.fromHex(
                          courseColor(course.name, widget.settings.colors),
                        ).foreground,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final color in coursePalette)
                      GestureDetector(
                        onTap: () {
                          widget.settings.colors[course.name] = color;
                          widget.onChanged();
                          setState(() {});
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: parseHex(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  courseColor(
                                        course.name,
                                        widget.settings.colors,
                                      ) ==
                                      color
                                  ? HuayanColors.ink
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class DataPage extends StatelessWidget {
  const DataPage({super.key, required this.snap});

  final Snapshot snap;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['学号、姓名、学院、专业、导师', '用来显示你是谁'],
      ['课表、已选课、培养计划', '用来排课和算学分'],
      ['成绩统计', '这次导出没有具体分数'],
      ['评教是否完成、申请走到哪一步', '用来显示已有状态'],
    ];
    return Subpage(
      title: '我们读取了哪些数据',
      children: [
        HuayanCard(
          child: Column(
            children: [
              for (final row in rows) KvRow(label: row[0], value: row[1]),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HuayanColors.amberSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('没有读取的', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text(
                '密码、证件号、手机号、家庭住址、邮箱。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFF6F5424),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${snap.campusNote} 学期第一周周一按 ${snap.termStart} 计算。',
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: HuayanColors.faint,
          ),
        ),
      ],
    );
  }
}

class WidgetPreviewPage extends StatelessWidget {
  const WidgetPreviewPage({super.key, required this.snap, required this.now});

  final Snapshot snap;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final day = sessionsOn(snap.courses, now, snap.termStart);
    final hero = pickHero(day.items, now);
    final course = hero.item?.course;
    final time = hero.item?.seg.startTime;
    final place = course == null ? '' : placeOf(course);
    return Subpage(
      title: '桌面小组件',
      children: [
        HuayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '下一节',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HuayanColors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                course?.name ?? '今天没有课',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: HuayanColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                course == null ? '小组件会显示这句话' : '$time · $place',
                style: const TextStyle(fontSize: 14, color: HuayanColors.sub),
              ),
            ],
          ),
        ),
        const Text(
          '桌面小组件还不能放到主屏幕。上面是今天会显示的内容。',
          style: TextStyle(fontSize: 13, height: 1.5, color: HuayanColors.sub),
        ),
      ],
    );
  }
}
