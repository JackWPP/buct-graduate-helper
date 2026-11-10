import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'activities/activity_models.dart';
import 'activities/activity_monitor.dart';
import 'activities/activity_notifications.dart';
import 'gmis/gmis_exception.dart';
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
  });

  final ActivityKind kind;
  final ActivityDataSource dataSource;
  final Future<void> Function()? onSessionExpired;
  final Future<void> Function()? onWebVpnExpired;
  final ActivityMonitor? monitor;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late final ActivityMonitor _monitor;
  int _tab = 0;
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
    }
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
        setState(() => _tab = 1);
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
    final items = _tab == 0 ? feed.available : feed.applied;
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
          availableCount: feed.available.length,
          appliedCount: feed.applied.length,
          onChanged: (value) => setState(() => _tab = value),
        ),
        if (feed.loading && feed.lastChecked == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          EmptyHint(
            key: Key('activity-empty-${widget.kind.serviceId}'),
            title: _tab == 0 ? '暂无可报名活动' : '还没有报名记录',
            text: _tab == 0
                ? '学校发布新活动后会出现在这里；打开自动监测后会在发现新活动时提醒。'
                : '在“可报名”里选择活动，提交后会进入这里。',
            icon: _tab == 0
                ? Icons.event_available_outlined
                : Icons.inbox_outlined,
            action: TextButton(onPressed: _refresh, child: const Text('刷新一下')),
          )
        else
          ...items.map(
            (item) => _ActivityCard(
              item: item,
              busy: _busy,
              onTap: () => _openDetail(item),
              onPrimary: item.applied
                  ? () => _cancel(item)
                  : (item.phaseAt(DateTime.now()) == ActivityPhase.open
                        ? () => _register(item)
                        : null),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
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
                          ? '每 30 秒检查一次新活动 · 下拉可手动刷新'
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
    required this.availableCount,
    required this.appliedCount,
    required this.onChanged,
  });

  final int tab;
  final int availableCount;
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
            label: '可报名 $availableCount',
            selected: tab == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 10),
          _TabButton(
            key: const Key('activity-tab-applied'),
            label: '我的报名 $appliedCount',
            selected: tab == 1,
            onTap: () => onChanged(1),
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
              style: TextStyle(
                fontSize: 14,
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
    required this.onTap,
    required this.onPrimary,
  });

  final ActivityItem item;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final phase = item.phaseAt(DateTime.now());
    final open = phase == ActivityPhase.open;
    final phaseColor = open
        ? HuayanColors.ok
        : phase == ActivityPhase.upcoming
        ? HuayanColors.blue
        : HuayanColors.sub;
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
                      item.phaseLabel(DateTime.now()),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '报名 ${_shortTime(item.signupStart)} - ${_shortTime(item.signupEnd)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HuayanColors.faint,
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
              TextButton(
                key: Key(
                  'activity-primary-${item.id}-${item.applied ? 'cancel' : 'apply'}',
                ),
                onPressed: busy ? null : onPrimary,
                style: TextButton.styleFrom(
                  foregroundColor: item.applied
                      ? HuayanColors.danger
                      : HuayanColors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  item.applied
                      ? '取消报名'
                      : open
                      ? '立即报名'
                      : phase == ActivityPhase.upcoming
                      ? '未开始'
                      : '不可报名',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _activityTime(ActivityItem item) {
    final start = _shortTime(item.activityStart);
    final end = _shortTime(item.activityEnd);
    if (start.isEmpty && end.isEmpty) return '时间以学校通知为准';
    return '$start - $end';
  }

  String _shortTime(DateTime? value) {
    if (value == null) return '待定';
    return '${value.month}/${value.day} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: HuayanColors.faint),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
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
    required this.onApply,
    required this.onCancel,
  });

  final ActivityItem item;
  final Future<void> Function()? onApply;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HuayanColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
                '${item.kind.label} · ${item.phaseLabel(DateTime.now())}',
                style: const TextStyle(fontSize: 13, color: HuayanColors.sub),
              ),
              const SizedBox(height: 16),
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
                value: item.organizer.isEmpty ? item.publisher : item.organizer,
              ),
              _DetailRow(label: '报名方式', value: item.method),
              _DetailRow(label: '人数', value: item.capacityLabel),
              if (item.score.isNotEmpty)
                _DetailRow(label: '项目化加分', value: item.score),
              if (item.duration.isNotEmpty)
                _DetailRow(label: '活动时长', value: item.duration),
              if (item.applied)
                _DetailRow(label: '审核状态', value: item.auditLabel),
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
          ),
        ),
      ),
    );
  }

  String _range(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '以学校通知为准';
    String format(DateTime? value) => value == null
        ? '待定'
        : '${value.year}/${value.month}/${value.day} '
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '${format(start)} - ${format(end)}';
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
