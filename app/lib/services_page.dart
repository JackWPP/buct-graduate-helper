import 'package:flutter/material.dart';

import 'icons.dart';
import 'schedule.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'widgets.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({
    super.key,
    required this.snap,
    required this.onOpen,
    required this.onGroup,
    required this.onCourse,
  });

  final Snapshot snap;
  final ValueChanged<ServiceItem> onOpen;
  final ValueChanged<ServiceGroup> onGroup;
  final ValueChanged<Course> onCourse;

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    return ListView(
      key: const Key('services-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const PageTitle(title: '服务'),
        TextField(
          key: const Key('service-search'),
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '搜功能、课程、老师',
            hintStyle: const TextStyle(
              color: HuayanColors.placeholder,
              fontSize: 15,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: HuayanIcon(
                'search',
                size: 20,
                color: HuayanColors.placeholder,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 20,
            ),
            filled: true,
            fillColor: HuayanColors.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (query.isEmpty) ...[
          const _Shortcuts(),
          const SizedBox(height: 12),
          if (widget.snap.services.isEmpty)
            const EmptyHint(title: '服务目录是空的', text: '快照里没有功能入口。')
          else
            _GroupGrid(
              groups: widget.snap.services,
              onOpen: widget.onOpen,
              onGroup: widget.onGroup,
            ),
        ] else
          _SearchBody(
            snap: widget.snap,
            query: query,
            onOpen: widget.onOpen,
            onCourse: widget.onCourse,
          ),
      ],
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    return HuayanCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              '常用',
              style: TextStyle(fontSize: 12, color: HuayanColors.faint),
            ),
          ),
          const Row(
            children: [
              Expanded(
                child: _Shortcut(
                  glyph: 'cal',
                  label: '课表',
                  native: 'timetable',
                ),
              ),
              Expanded(
                child: _Shortcut(glyph: 'chart', label: '成绩', native: 'grades'),
              ),
              Expanded(
                child: _Shortcut(
                  glyph: 'check',
                  label: '选课',
                  native: 'selected',
                ),
              ),
              Expanded(
                child: _Shortcut(glyph: 'star', label: '评教', native: 'eval'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.glyph,
    required this.label,
    required this.native,
  });

  final String glyph;
  final String label;
  final String native;

  @override
  Widget build(BuildContext context) {
    final page = context.findAncestorStateOfType<_ServicesPageState>();
    return InkWell(
      key: Key('shortcut-$native'),
      onTap: () => page?.widget.onOpen(
        ServiceItem(id: native, name: label, path: '', native: native),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            HuayanIcon(glyph, color: HuayanColors.blue, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HuayanColors.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupGrid extends StatelessWidget {
  const _GroupGrid({
    required this.groups,
    required this.onOpen,
    required this.onGroup,
  });

  final List<ServiceGroup> groups;
  final ValueChanged<ServiceItem> onOpen;
  final ValueChanged<ServiceGroup> onGroup;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 214,
      ),
      itemBuilder: (context, index) {
        final group = groups[index];
        final shown = group.items.take(4).toList();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: HuayanColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HuayanColors.lineSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: HuayanColors.ink,
                          ),
                        ),
                      ),
                      if (group.items.length > 4)
                        TextButton(
                          onPressed: () => onGroup(group),
                          style: TextButton.styleFrom(
                            foregroundColor: HuayanColors.faint,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '全部',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.15,
                    children: [
                      for (final item in shown)
                        _Mini(item: item, onTap: () => onOpen(item)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.item, required this.onTap});

  final ServiceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('service-${item.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            HuayanIcon(
              serviceGlyph(item.id),
              size: 22,
              color: const Color(0xFF8B93A7),
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: HuayanColors.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.snap,
    required this.query,
    required this.onOpen,
    required this.onCourse,
  });

  final Snapshot snap;
  final String query;
  final ValueChanged<ServiceItem> onOpen;
  final ValueChanged<Course> onCourse;

  @override
  Widget build(BuildContext context) {
    final services = searchServices(snap.services, query);
    final courses = searchCourses(snap.courses, query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '功能',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HuayanColors.faint,
          ),
        ),
        const SizedBox(height: 8),
        if (services.isEmpty)
          Text(
            '没有叫「$query」的功能',
            style: const TextStyle(fontSize: 14, color: HuayanColors.sub),
          )
        else
          for (final hit in services)
            _ServiceRow(hit: hit, onTap: () => onOpen(hit.item)),
        const SizedBox(height: 16),
        const Text(
          '课程和老师',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HuayanColors.faint,
          ),
        ),
        const SizedBox(height: 8),
        if (courses.isEmpty)
          const Text(
            '没有匹配的课',
            style: TextStyle(fontSize: 14, color: HuayanColors.sub),
          )
        else
          for (final course in courses)
            _CourseHit(course: course, onTap: () => onCourse(course)),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.hit, required this.onTap});

  final ServiceHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final where = hit.item.native == null ? '学校网页' : '本机页面';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HuayanColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('service-${hit.item.id}'),
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
                HuayanIcon(
                  serviceGlyph(hit.item.id),
                  color: const Color(0xFF8B93A7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HuayanColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${hit.group} · $where',
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

class _CourseHit extends StatelessWidget {
  const _CourseHit({required this.course, required this.onTap});

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
                  child: Text(
                    course.name,
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
    );
  }
}
