import 'dart:async';

import 'package:flutter/foundation.dart';

import '../gmis/gmis_exception.dart';
import '../ui/feedback.dart';
import 'activity_models.dart';
import 'activity_notifications.dart';

/// 登录后在前台运行的活动监测器。
///
/// 每 [interval] 拉一次两个服务的可报名列表；第一次只建立基线，之后出现
/// 的新活动会发本地通知和全局提示。它不负责系统后台常驻（Android 的
/// 后台任务需要单独的原生调度），但应用在前台时是真正自动探测的。
class ActivityMonitor extends ChangeNotifier {
  ActivityMonitor._();

  static final ActivityMonitor instance = ActivityMonitor._();

  static const interval = Duration(seconds: 30);

  final Map<ActivityKind, ActivityFeed> _feeds = {
    ActivityKind.academicReport: const ActivityFeed(),
    ActivityKind.laborPractice: const ActivityFeed(),
  };
  final Set<String> _knownKeys = <String>{};
  final Set<String> _scheduledKeys = <String>{};
  final Set<ActivityKind> _seededKinds = <ActivityKind>{};
  ActivityDataSource? _api;
  Future<void> Function()? _onSessionExpired;
  Timer? _timer;
  bool _polling = false;
  bool _paused = false;
  bool _sessionExpiredNotified = false;

  ActivityFeed feed(ActivityKind kind) => _feeds[kind] ?? const ActivityFeed();

  bool get running => _timer != null && !_paused;

  void start(
    ActivityDataSource api, {
    Future<void> Function()? onSessionExpired,
  }) {
    final changed = !identical(_api, api);
    _api = api;
    _onSessionExpired = onSessionExpired;
    if (changed) {
      _knownKeys.clear();
      _scheduledKeys.clear();
      _seededKinds.clear();
      _feeds[ActivityKind.academicReport] = const ActivityFeed();
      _feeds[ActivityKind.laborPractice] = const ActivityFeed();
      _sessionExpiredNotified = false;
      _paused = false;
    }
    final newlyStarted = _timer == null;
    _timer ??= Timer.periodic(interval, (_) => poll());
    if ((changed || newlyStarted) && !_paused) {
      unawaited(poll(notifyNew: true));
    }
  }

  void pause() {
    _paused = true;
  }

  void resume() {
    if (_paused) {
      _paused = false;
      unawaited(poll());
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _api = null;
    _onSessionExpired = null;
    _paused = false;
  }

  Future<void> poll({bool notifyNew = true}) async {
    final api = _api;
    if (api == null || _polling || _paused) return;
    _polling = true;
    try {
      for (final kind in ActivityKind.values) {
        await _pollKind(api, kind, notifyNew: notifyNew);
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollKind(
    ActivityDataSource api,
    ActivityKind kind, {
    required bool notifyNew,
  }) async {
    final hadData = feed(kind).lastChecked != null;
    _feeds[kind] = feed(kind).copyWith(loading: true, clearError: true);
    notifyListeners();
    try {
      final availableFuture = api.activityAvailable(kind);
      final appliedFuture = api.activityApplied(kind);
      final hoursFuture = kind == ActivityKind.laborPractice
          ? api.laborPracticeHours()
          : Future<double>.value(0);
      final results = await Future.wait<Object>([
        availableFuture,
        appliedFuture,
        hoursFuture,
      ]);
      final available = results[0] as List<ActivityItem>;
      final applied = results[1] as List<ActivityItem>;
      final hours = results[2] as double;
      final seeded = _seededKinds.contains(kind);
      final newItems = <ActivityItem>[];
      for (final item in available) {
        if (seeded && !_knownKeys.contains(item.stableKey)) {
          newItems.add(item);
        }
        _knownKeys.add(item.stableKey);
      }
      _seededKinds.add(kind);
      _feeds[kind] = ActivityFeed(
        available: available,
        applied: applied,
        totalHours: hours,
        lastChecked: DateTime.now(),
      );
      notifyListeners();
      if (notifyNew && hadData) {
        for (final item in newItems) {
          unawaited(ActivityNotificationService.instance.showNewActivity(item));
          AppFeedback.show('发现新的${kind.label}：${item.title}');
        }
      }
      for (final item in available) {
        final scheduleKey = [
          item.stableKey,
          item.signupStart?.millisecondsSinceEpoch,
          item.signupEnd?.millisecondsSinceEpoch,
          item.activityStart?.millisecondsSinceEpoch,
        ].join(':');
        if (_scheduledKeys.add(scheduleKey)) {
          unawaited(ActivityNotificationService.instance.scheduleFor(item));
        }
      }
    } on GmisSessionExpired {
      _feeds[kind] = feed(kind).copyWith(loading: false, error: '登录已过期，请重新登录');
      notifyListeners();
      if (!_sessionExpiredNotified) {
        _sessionExpiredNotified = true;
        final callback = _onSessionExpired;
        if (callback != null) unawaited(callback());
      }
    } catch (error) {
      _feeds[kind] = feed(kind).copyWith(
        loading: false,
        error: error is GmisException ? error.message : '活动列表加载失败',
      );
      notifyListeners();
    }
  }
}
