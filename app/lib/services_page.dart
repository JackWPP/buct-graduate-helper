import 'package:flutter/material.dart';

import 'icons.dart';
import 'schedule.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'widgets.dart';

/// 全部服务入口：搜索、分组筛选、直接进入原生页面。
/// 不再经过“宫格 → 分组页 → 外跳浏览器”。
class ServicesPage extends StatefulWidget {
  const ServicesPage({
    super.key,
    required this.snap,
    required this.onOpen,
    this.onGroup,
    this.onCourse,
    this.onRefresh,
    this.lastRefreshedAt,
    this.offline = false,
  });

  final Snapshot snap;
  final ValueChanged<ServiceItem> onOpen;
  final ValueChanged<ServiceGroup>? onGroup;
  final ValueChanged<Course>? onCourse;
  final Future<void> Function()? onRefresh;
  final DateTime? lastRefreshedAt;
  final bool offline;

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final _query = TextEditingController();
  String? _group;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final groups = widget.snap.services;
    final filtered = _group == null
        ? groups
        : groups.where((group) => group.id == _group).toList();
    final total = groups.fold<int>(0, (sum, group) => sum + group.items.length);
    final content = ListView(
      key: const Key('services-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const PageTitle(title: '服务'),
        Text(
          '共 $total 项服务，全部在应用内直接打开。',
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: HuayanColors.sub,
          ),
        ),
        if (widget.lastRefreshedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: UpdateStamp(time: widget.lastRefreshedAt),
          ),
        if (widget.offline)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OfflineBanner(
              message: '当前显示缓存服务目录，下拉可重试',
              onRetry: widget.onRefresh,
            ),
          ),
        const SizedBox(height: 14),
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
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    key: const Key('service-search-clear'),
                    tooltip: '清除搜索',
                    onPressed: () {
                      _query.clear();
                      setState(() {});
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: HuayanColors.faint,
                    ),
                  ),
            filled: true,
            fillColor: HuayanColors.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (query.isEmpty) ...[
          _GroupChips(
            groups: groups,
            selected: _group,
            onSelected: (id) => setState(() => _group = id),
          ),
          const SizedBox(height: 14),
          for (final group in filtered) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: HuayanColors.faint,
                      ),
                    ),
                  ),
                  Text(
                    '${group.items.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HuayanColors.placeholder,
                    ),
                  ),
                ],
              ),
            ),
            for (final item in group.items)
              _ServiceRow(
                item: item,
                groupName: group.name,
                onTap: () => widget.onOpen(item),
              ),
            const SizedBox(height: 8),
          ],
          if (groups.isEmpty)
            const EmptyHint(title: '服务目录是空的', text: '学校还没有返回服务菜单。'),
        ] else
          _SearchBody(
            snap: widget.snap,
            query: query,
            onOpen: widget.onOpen,
            onCourse: widget.onCourse,
            onClear: () {
              _query.clear();
              setState(() {});
            },
          ),
      ],
    );
    final refresh = widget.onRefresh;
    if (refresh == null) return content;
    return RefreshIndicator(
      key: const Key('services-refresh'),
      onRefresh: refresh,
      child: content,
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<ServiceGroup> groups;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          label: '全部',
          active: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final group in groups)
          _Chip(
            label: group.name,
            active: selected == group.id,
            onTap: () => onSelected(group.id),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? HuayanColors.blue : HuayanColors.card,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: active ? HuayanColors.blue : HuayanColors.lineSoft,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : HuayanColors.sub,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.item,
    required this.groupName,
    required this.onTap,
  });

  final ServiceItem item;
  final String groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HuayanColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('service-${item.id}'),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: HuayanColors.blueSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: HuayanIcon(
                      serviceGlyph(item.id),
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
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: HuayanColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HuayanColors.faint,
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

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.snap,
    required this.query,
    required this.onOpen,
    required this.onCourse,
    required this.onClear,
  });

  final Snapshot snap;
  final String query;
  final ValueChanged<ServiceItem> onOpen;
  final ValueChanged<Course>? onCourse;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final services = searchServices(snap.services, query);
    final courses = searchCourses(snap.courses, query);
    if (services.isEmpty && courses.isEmpty) {
      return EmptyHint(
        title: '没有找到「$query」',
        text: '换个关键词试试，或清除搜索查看全部服务。',
        action: TextButton(
          key: const Key('service-search-empty-clear'),
          onPressed: onClear,
          child: const Text('清除搜索'),
        ),
      );
    }
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
            _ServiceRow(
              item: hit.item,
              groupName: hit.group,
              onTap: () => onOpen(hit.item),
            ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: HuayanColors.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onCourse == null ? null : () => onCourse!(course),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: HuayanColors.lineSoft),
                    ),
                    child: Row(
                      children: [
                        const HuayanIcon(
                          'book',
                          size: 20,
                          color: HuayanColors.blue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            course.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: HuayanColors.ink,
                            ),
                          ),
                        ),
                        const HuayanChevron(),
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
