import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'activities/activity_buckets.dart';
import 'activities/activity_format.dart';
import 'activities/activity_models.dart';
import 'activities/activity_monitor.dart';
import 'activities/activity_notifications.dart';
import 'gmis/gmis_exception.dart';
import 'planner/activity_conflict.dart';
import 'planner/day_agenda_sheet.dart';
import 'planner/day_plan.dart';
import 'planner/planner_models.dart';
import 'planner/time_text.dart';
import 'planner/todo_models.dart';
import 'schedule.dart';
import 'webvpn/webvpn_exception.dart';
import 'theme.dart';
import 'ui/feedback.dart';
import 'widgets.dart';

/// 学术报告 / 劳动实践的统一活动页面。
///
/// 顶部是可报名列表，下面是“我的报名”。报名走学校真实的验证码接口，
/// 不做无确认自动提交；自动监测由 [ActivityMonitor] 在登录后统一运行。
class ActivityPage extends StatefulWidget {
  const ActivityPage({
    super.key,
    required this.kind,
    required this.dataSource,
    this.onSessionExpired,
    this.onWebVpnExpired,
    this.monitor,
    this.courses = const <Course>[],
    this.termStart = '',
    this.termStartKnown = true,
    this.todos = const <TodoItem>[],
  });

  final ActivityKind kind;
  final ActivityDataSource dataSource;
  final Future<void> Function()? onSessionExpired;
  final Future<void> Function()? onWebVpnExpired;
  final ActivityMonitor? monitor;
  final List<Course> courses;
  final String termStart;
  final bool termStartKnown;
  final List<TodoItem> todos;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  static const _tabOpen = 0;
  static const _tabPending = 1;
  static const _tabApplied = 2;

  late final ActivityMonitor _monitor;
  int _tab = _tabOpen;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _monitor = widget.monitor ?? ActivityMonitor.instance;
    _monitor.addListener(_onMonitor);
    _monitor.start(
      widget.dataSource,
      onSessionExpired: widget.onSessionExpired,
      onWebVpnExpired: widget.onWebVpnExpired,
    );
    unawaited(ActivityNotificationService.instance.requestPermission());
  }

  @override
  void dispose() {
    _monitor.removeListener(_onMonitor);
    super.dispose();
  }

  void _onMonitor() {
    if (mounted) setState(() {});
  }

  ActivityFeed get _feed => _monitor.feed(widget.kind);

  Future<void> _refresh() async {
    await _monitor.poll();
    if (mounted) setState(() {});
  }

  Future<void> _openDetail(ActivityItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActivityDetailSheet(
        item: item,
        courses: widget.courses,
        termStart: widget.termStart,
        termStartKnown: widget.termStartKnown,
        todos: widget.todos,
        dayActivities: _appliedActivities(),
        onApply:
            !item.applied && item.phaseAt(DateTime.now()) == ActivityPhase.open
            ? () => _register(item)
            : null,
        onCancel: item.applied ? () => _cancel(item) : null,
      ),
    );
    if (action == 'apply') {
      await _register(item);
    } else if (action == 'cancel') {
      await _cancel(item);
    } else if (action == 'day') {
      await _openDay(item);
    }
  }

  List<ActivityItem> _appliedActivities() {
    final seen = <String>{};
    final result = <ActivityItem>[];
    for (final kind in ActivityKind.values) {
      for (final item in _monitor.feed(kind).applied) {
        if (seen.add(item.stableKey)) result.add(item);
      }
    }
    return result;
  }

  Future<void> _openDay(ActivityItem item) async {
    final date = item.activityStart;
    if (date == null) return;
    await showDayAgendaSheet(
      context,
      date: date,
      courses: widget.courses,
      termStart: widget.termStart,
      now: DateTime.now(),
      activities: _appliedActivities(),
      todos: widget.todos,
      candidate: item.applied ? null : item,
      termStartKnown: widget.termStartKnown,
    );
  }

  Future<void> _register(ActivityItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (item.kind == ActivityKind.academicReport) {
        final allowed = await widget.dataSource.canApplyAcademicReport(item.id);
        if (!allowed) {
          if (mounted) AppFeedback.show('当前不在报名时间内，请刷新活动列表。', context: context);
          return;
        }
      }
      if (!mounted) return;
      final captcha = await showDialog<String>(
        context: context,
        builder: (context) => _ActivityCaptchaDialog(
          dataSource: widget.dataSource,
          title: '报名 ${item.kind.label}',
        ),
      );
      if (captcha == null || captcha.trim().isEmpty) return;
      final result = await widget.dataSource.registerActivity(
        id: item.id,
        captcha: captcha,
      );
      if (!mounted) return;
      AppFeedback.show(result.display, context: context);
      if (result.ok) {
        setState(() => _tab = _tabApplied);
        await _refresh();
      }
    } on WebVpnSessionExpired {
      await widget.onWebVpnExpired?.call();
    } on GmisSessionExpired {
      await widget.onSessionExpired?.call();
    } on GmisException catch (error) {
      if (mounted) AppFeedback.show(error.message, context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(ActivityItem item) async {
    if (_busy || item.applicationId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消报名'),
        content: Text('确定取消“${item.title}”的报名吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('再想想'),
          ),
          FilledButton(
            key: const Key('activity-cancel-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final result = await widget.dataSource.cancelActivity(
        kind: item.kind,
        applicationId: item.applicationId,
      );
      if (!mounted) return;
      AppFeedback.show(result.ok ? '已取消报名' : result.display, context: context);
      if (result.ok) await _refresh();
    } on WebVpnSessionExpired {
      await widget.onWebVpnExpired?.call();
    } on GmisSessionExpired {
      await widget.onSessionExpired?.call();
    } on GmisException catch (error) {
      if (mounted) AppFeedback.show(error.message, context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final now = DateTime.now();
    final buckets = partitionAvailableActivities(feed.available, now);
    final items = switch (_tab) {
      _tabOpen => buckets.open,
      _tabPending => buckets.pending,
      _ => feed.applied,
    };
    return Subpage(
      title: widget.kind.label,
      onRefresh: _refresh,
      children: [
        _StatusCard(kind: widget.kind, feed: feed),
        if (widget.kind == ActivityKind.laborPractice)
          HuayanCard(
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: HuayanColors.blue),
                const SizedBox(width: 10),
                const Text(
                  '累计劳动实践',
                  style: TextStyle(fontSize: 14, color: HuayanColors.sub),
                ),
                const Spacer(),
                Text(
                  '${feed.totalHours.toStringAsFixed(feed.totalHours == feed.totalHours.roundToDouble() ? 0 : 1)} 小时',
                  key: const Key('activity-total-hours'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.ink,
                  ),
                ),
              ],
            ),
          ),
        if (feed.error != null)
          OfflineBanner(message: feed.error!, onRetry: _refresh),
        _Tabs(
          tab: _tab,
          openCount: buckets.open.length,
          pendingCount: buckets.pending.length,
          appliedCount: feed.applied.length,
          onChanged: (value) => setState(() => _tab = value),
        ),
        if (_tab == _tabPending && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '还没开放报名、或名额已满的活动；名额释放后会回到“可报名”。',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: HuayanColors.faint,
              ),
            ),
          ),
        if (feed.loading && feed.lastChecked == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          _emptyState(buckets)
        else
          ...items.map(
            (item) => _ActivityCard(
              item: item,
              busy: _busy,
              courses: widget.courses,
              termStart: widget.termStart,
              termStartKnown: widget.termStartKnown,
              onTap: () => _openDetail(item),
              onPrimary: item.applied
                  ? () => _cancel(item)
                  : (item.phaseAt(now) == ActivityPhase.open
                        ? () => _register(item)
                        : null),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _emptyState(ActivityBuckets buckets) {
    switch (_tab) {
      case _tabOpen:
        final pending = buckets.pending.length;
        return EmptyHint(
          key: Key('activity-empty-${widget.kind.serviceId}-open'),
          title: '当前没有正在报名的活动',
          text: pending > 0
              ? '有 $pending 个活动还不能报名，去“待进行”看看开放时间或名额。'
              : '学校发布新活动后会出现在这里；打开自动监测后会在发现新活动时提醒。',
          icon: Icons.event_available_outlined,
          action: TextButton(
            onPressed: pending > 0
                ? () => setState(() => _tab = _tabPending)
                : _refresh,
            child: Text(pending > 0 ? '查看待进行' : '刷新一下'),
          ),
        );
      case _tabPending:
        final open = buckets.open.length;
        return EmptyHint(
          key: Key('activity-empty-${widget.kind.serviceId}-pending'),
          title: '暂时没有待进行活动',
          text: open > 0
              ? '现在有 $open 个活动正在报名。'
              : '还没开放报名、或名额已满的活动会出现在这里；学校未发布的活动无法提前显示。',
          icon: Icons.upcoming_outlined,
          action: TextButton(
            onPressed: open > 0
                ? () => setState(() => _tab = _tabOpen)
                : _refresh,
            child: Text(open > 0 ? '查看可报名' : '刷新一下'),
          ),
        );
      default:
        return EmptyHint(
          key: Key('activity-empty-${widget.kind.serviceId}-applied'),
          title: '还没有报名记录',
          text: '在“可报名”里选择活动，提交后会进入这里。',
          icon: Icons.inbox_outlined,
          action: TextButton(onPressed: _refresh, child: const Text('刷新一下')),
        );
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.kind, required this.feed});

  final ActivityKind kind;
  final ActivityFeed feed;

  @override
  Widget build(BuildContext context) {
    final running = ActivityMonitor.instance.running;
    return HuayanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: running
                      ? const Color(0xE812A05C)
                      : HuayanColors.lineSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  running ? Icons.radar_rounded : Icons.pause_circle_outline,
                  color: running ? Colors.white : HuayanColors.sub,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      running ? '自动监测中' : '自动监测未启动',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HuayanColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      running
                          ? '每 30 秒检查新活动和名额 · 下拉可手动刷新'
                          : '登录后自动开始检查，打开页面即可刷新',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HuayanColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
              UpdateStamp(time: feed.lastChecked),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tab,
    required this.openCount,
    required this.pendingCount,
    required this.appliedCount,
    required this.onChanged,
  });

  final int tab;
  final int openCount;
  final int pendingCount;
  final int appliedCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          _TabButton(
            key: const Key('activity-tab-available'),
            label: '可报名 $openCount',
            selected: tab == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 8),
          _TabButton(
            key: const Key('activity-tab-pending'),
            label: '待进行 $pendingCount',
            selected: tab == 1,
            onTap: () => onChanged(1),
          ),
          const SizedBox(width: 8),
          _TabButton(
            key: const Key('activity-tab-applied'),
            label: '我的报名 $appliedCount',
            selected: tab == 2,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? HuayanColors.blue : HuayanColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : HuayanColors.sub,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.item,
    required this.busy,
    required this.courses,
    required this.termStart,
    required this.termStartKnown,
    required this.onTap,
    required this.onPrimary,
  });

  final ActivityItem item;
  final bool busy;
  final List<Course> courses;
  final String termStart;
  final bool termStartKnown;
  final VoidCallback onTap;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final phase = item.phaseAt(now);
    final open = phase == ActivityPhase.open;
    final phaseColor = open
        ? HuayanColors.ok
        : phase == ActivityPhase.upcoming
        ? HuayanColors.blue
        : phase == ActivityPhase.full
        ? HuayanColors.amberInk
        : HuayanColors.sub;
    final conflict = termStart.isEmpty
        ? null
        : activityConflict(
            activity: item,
            courses: courses,
            termStart: termStart,
            now: now,
            termStartKnown: termStartKnown,
          );
    return HuayanCard(
      key: Key(
        'activity-card-${item.id}-${item.applied ? 'applied' : 'available'}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: HuayanColors.blueSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: HuayanColors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      item.phaseLabel(now),
                      style: TextStyle(
                        fontSize: 12,
                        color: phaseColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title.isEmpty ? '未命名活动' : item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                _MetaLine(
                  icon: Icons.schedule_outlined,
                  text: _activityTime(item),
                ),
                if (item.location.isNotEmpty)
                  _MetaLine(icon: Icons.place_outlined, text: item.location),
                if (conflict != null && conflict.hasConflict)
                  _MetaLine(
                    icon: Icons.event_busy_outlined,
                    text: conflict.summary,
                    color: HuayanColors.amberInk,
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _signupText(item, phase),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: phase == ActivityPhase.upcoming
                              ? HuayanColors.blue
                              : HuayanColors.faint,
                        ),
                      ),
                    ),
                    if (item.capacity > 0)
                      Text(
                        item.remaining >= 0
                            ? '余 ${item.remaining} 位'
                            : '人数以学校为准',
                        style: TextStyle(
                          fontSize: 12,
                          color: item.isFull
                              ? HuayanColors.danger
                              : HuayanColors.sub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.applied
                      ? '${item.auditLabel} · ${item.capacityLabel}'
                      : item.capacityLabel,
                  style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
                ),
              ),
              if (item.applied)
                TextButton(
                  key: Key('activity-primary-${item.id}-cancel'),
                  onPressed: busy ? null : onPrimary,
                  style: TextButton.styleFrom(
                    foregroundColor: HuayanColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('取消报名'),
                )
              else if (open)
                TextButton(
                  key: Key('activity-primary-${item.id}-apply'),
                  onPressed: busy ? null : onPrimary,
                  style: TextButton.styleFrom(
                    foregroundColor: HuayanColors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('立即报名'),
                )
              else
                _TrailingHint(item: item, phase: phase, now: now),
            ],
          ),
        ],
      ),
    );
  }

  String _activityTime(ActivityItem item) {
    if (item.activityStart == null && item.activityEnd == null) {
      return '时间以学校通知为准';
    }
    return activityRangeText(
      item.activityStart,
      item.activityEnd,
      compact: true,
    );
  }

  String _signupText(ActivityItem item, ActivityPhase phase) {
    switch (phase) {
      case ActivityPhase.open:
        return item.signupEnd == null
            ? '报名中'
            : '报名截止 ${activityDateTimeText(item.signupEnd!, compact: true)}';
      case ActivityPhase.upcoming:
        return item.signupStart == null
            ? '报名时间待定'
            : '报名开放 ${activityDateTimeText(item.signupStart!, compact: true)}';
      case ActivityPhase.full:
        return item.signupStart == null && item.signupEnd == null
            ? '报名时间待定'
            : '报名 ${activityRangeText(item.signupStart, item.signupEnd, compact: true)}';
      case ActivityPhase.closed:
        return '报名已截止';
      case ActivityPhase.applied:
        return item.signupStart == null && item.signupEnd == null
            ? '已报名'
            : '报名 ${activityRangeText(item.signupStart, item.signupEnd, compact: true)}';
    }
  }
}

class _TrailingHint extends StatelessWidget {
  const _TrailingHint({
    required this.item,
    required this.phase,
    required this.now,
  });

  final ActivityItem item;
  final ActivityPhase phase;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      ActivityPhase.upcoming => (
        item.signupStart == null
            ? '待开放'
            : '${relativeDayText(item.signupStart!, now)}开放',
        HuayanColors.blue,
      ),
      ActivityPhase.full => ('等待名额', HuayanColors.amberInk),
      ActivityPhase.open ||
      ActivityPhase.closed ||
      ActivityPhase.applied => ('不可报名', HuayanColors.faint),
    };
    return Text(
      label,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    this.color = HuayanColors.faint,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDetailSheet extends StatelessWidget {
  const _ActivityDetailSheet({
    required this.item,
    required this.courses,
    required this.termStart,
    required this.termStartKnown,
    required this.todos,
    required this.dayActivities,
    required this.onApply,
    required this.onCancel,
  });

  final ActivityItem item;
  final List<Course> courses;
  final String termStart;
  final bool termStartKnown;
  final List<TodoItem> todos;
  final List<ActivityItem> dayActivities;
  final Future<void> Function()? onApply;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasAction = onApply != null || onCancel != null;
    final conflict = termStart.isEmpty
        ? null
        : activityConflict(
            activity: item,
            courses: courses,
            termStart: termStart,
            now: now,
            termStartKnown: termStartKnown,
          );
    final day = item.activityStart == null
        ? null
        : buildDayPlan(
            date: item.activityStart!,
            courses: courses,
            termStart: termStart,
            now: now,
            activities: dayActivities,
            todos: todos,
            candidate: item.applied ? null : item,
            termStartKnown: termStartKnown,
          );
    return Container(
      decoration: const BoxDecoration(
        color: HuayanColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title.isEmpty ? '活动详情' : item.title,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${item.kind.label} · ${item.phaseLabel(now)}',
                  style: const TextStyle(fontSize: 13, color: HuayanColors.sub),
                ),
                const SizedBox(height: 16),
                _DetailRow(label: '报名状态', value: _statusText(now)),
                if (conflict != null)
                  _DetailRow(label: '课表冲突', value: conflict.summary),
                if (day != null)
                  _DetailRow(label: '当天空闲', value: _freeText(day)),
                _DetailRow(
                  label: '活动时间',
                  value: _range(item.activityStart, item.activityEnd),
                ),
                _DetailRow(
                  label: '报名时间',
                  value: _range(item.signupStart, item.signupEnd),
                ),
                _DetailRow(label: '地点', value: item.location),
                _DetailRow(
                  label: '主办',
                  value: item.organizer.isEmpty
                      ? item.publisher
                      : item.organizer,
                ),
                _DetailRow(label: '报名方式', value: item.method),
                _DetailRow(label: '人数', value: item.capacityLabel),
                if (item.score.isNotEmpty)
                  _DetailRow(label: '项目化加分', value: item.score),
                if (item.duration.isNotEmpty)
                  _DetailRow(label: '活动时长', value: item.duration),
                if (item.applied)
                  _DetailRow(label: '审核状态', value: item.auditLabel),
                if (item.activityStart != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('activity-view-day'),
                      onPressed: () => Navigator.of(context).pop('day'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        foregroundColor: HuayanColors.blue,
                      ),
                      icon: const Icon(Icons.calendar_month_outlined, size: 17),
                      label: const Text('查看当天日程'),
                    ),
                  ),
                if (hasAction) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (onCancel != null)
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('activity-detail-cancel'),
                            onPressed: () async {
                              Navigator.of(context).pop('cancel');
                            },
                            child: const Text('取消报名'),
                          ),
                        ),
                      if (onCancel != null && onApply != null)
                        const SizedBox(width: 12),
                      if (onApply != null)
                        Expanded(
                          child: FilledButton(
                            key: const Key('activity-detail-apply'),
                            onPressed: () async {
                              Navigator.of(context).pop('apply');
                            },
                            child: const Text('立即报名'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _range(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '以学校通知为准';
    return activityRangeText(start, end, withYear: true);
  }

  String _freeText(DayPlan plan) {
    if (plan.isPast) return '已过去';
    if (!plan.termKnown) return '课表未确认，暂不计算';
    if (!plan.hasCourseData) return '课表未加载，暂不计算';
    if (plan.freeSlots.isEmpty) return '当天没有 30 分钟以上空闲';
    final shown = plan.freeSlots
        .take(2)
        .map((slot) => '${planSlotText(slot)} · ${planSlotDuration(slot)}');
    final more = plan.freeSlots.length > 2
        ? '；另有 ${plan.freeSlots.length - 2} 段'
        : '';
    return '${shown.join('；')}$more';
  }

  String _statusText(DateTime now) {
    switch (item.phaseAt(now)) {
      case ActivityPhase.open:
        return item.signupEnd == null
            ? '报名中'
            : '报名中 · ${activityDateTimeText(item.signupEnd!)} 截止';
      case ActivityPhase.upcoming:
        if (item.signupStart == null) return '报名时间待定';
        return '未开始 · ${activityDateTimeText(item.signupStart!)} 开放'
            '（${relativeDayText(item.signupStart!, now)}）';
      case ActivityPhase.full:
        return '名额已满 · 可等有人取消';
      case ActivityPhase.closed:
        return '报名已截止';
      case ActivityPhase.applied:
        return item.auditLabel;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: HuayanColors.faint),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '以学校通知为准' : value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: HuayanColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 活动验证码弹层：报名和登录/选课验证码互相独立。
class _ActivityCaptchaDialog extends StatefulWidget {
  const _ActivityCaptchaDialog({required this.dataSource, required this.title});

  final ActivityDataSource dataSource;
  final String title;

  @override
  State<_ActivityCaptchaDialog> createState() => _ActivityCaptchaDialogState();
}

class _ActivityCaptchaDialogState extends State<_ActivityCaptchaDialog> {
  final _controller = TextEditingController();
  Uint8List? _image;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.dataSource.activityCaptcha();
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _loading = false;
      });
    } on GmisException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '验证码来自学校活动报名系统，和登录验证码不同。',
            style: TextStyle(fontSize: 12, color: HuayanColors.sub),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_loading)
                const SizedBox(
                  width: 100,
                  height: 42,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_image != null)
                InkWell(
                  onTap: _refresh,
                  child: Image.memory(
                    _image!,
                    key: const Key('activity-captcha-image'),
                    width: 100,
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Text(
                  _error ?? '验证码加载失败',
                  style: const TextStyle(
                    fontSize: 12,
                    color: HuayanColors.danger,
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('activity-captcha-refresh'),
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: '换一张',
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('activity-captcha-input'),
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: '输入验证码',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('activity-captcha-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('提交报名'),
        ),
      ],
    );
  }
}
