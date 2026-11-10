import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'activity_format.dart';
import 'activity_models.dart';

/// 本地通知：活动新发布、报名开始/截止前提醒。
///
/// 这里只负责“把已知活动变成系统提醒”，不做后台抓取；后台抓取由
/// 应用进程内的 ActivityMonitor 和后续的系统任务承担。所有调用都容忍
/// 插件不可用（测试环境/系统关闭通知），不阻塞主流程。
class ActivityNotificationService {
  ActivityNotificationService._();

  static final ActivityNotificationService instance =
      ActivityNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'huayan_activity';
  static const _channelName = '活动报名提醒';
  static const _channelDescription = '学术报告与劳动实践的新活动、报名开始/截止和名额提醒';

  bool _initialized = false;
  bool _permissionAsked = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      }
      const android = AndroidInitializationSettings('ic_stat_huayan');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
      _initialized = true;
    } catch (error) {
      debugPrint('ActivityNotificationService init skipped: $error');
    }
  }

  Future<bool> requestPermission() async {
    await ensureInitialized();
    if (_permissionAsked) return true;
    _permissionAsked = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      if (granted == false) return false;
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return true;
    } catch (error) {
      debugPrint('ActivityNotificationService permission skipped: $error');
      return false;
    }
  }

  Future<void> showNewActivity(ActivityItem item) async {
    try {
      await ensureInitialized();
      await _plugin.show(
        id: _stableId('${item.stableKey}:new'),
        title: '发现新的${item.kind.label}活动',
        body:
            item.title +
            (item.signupStart != null
                ? ' · ${activityDateTimeText(item.signupStart!)} 开始报名'
                : ''),
        notificationDetails: _details(),
        payload: item.stableKey,
      );
    } catch (error) {
      debugPrint('ActivityNotificationService show skipped: $error');
    }
  }

  /// 为活动安排报名开始、报名截止、活动开始三个提醒（只安排未来时间）。
  Future<void> scheduleFor(ActivityItem item) async {
    try {
      await ensureInitialized();
      final now = DateTime.now();
      final events = <(String, DateTime, String)>[
        if (item.signupStart != null && item.signupStart!.isAfter(now))
          ('报名开始', item.signupStart!, '${item.title} 现在可以报名了'),
        if (item.signupEnd != null && item.signupEnd!.isAfter(now))
          (
            '报名即将截止',
            item.signupEnd!.subtract(const Duration(minutes: 10)),
            '${item.title} 将于 ${activityDateTimeText(item.signupEnd!)} 截止报名',
          ),
        if (item.activityStart != null && item.activityStart!.isAfter(now))
          (
            '活动即将开始',
            item.activityStart!.subtract(const Duration(hours: 1)),
            '${item.title} 将于 ${activityDateTimeText(item.activityStart!)} 开始',
          ),
      ];
      for (final (label, at, body) in events) {
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _stableId('${item.stableKey}:$label'),
          title: label,
          body: body,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: item.stableKey,
        );
      }
    } catch (error) {
      debugPrint('ActivityNotificationService schedule skipped: $error');
    }
  }

  /// 已满的活动空出名额时提醒一次；调用方负责去重。
  Future<void> showSlotAvailable(ActivityItem item) async {
    try {
      await ensureInitialized();
      final deadline = item.signupEnd == null
          ? ''
          : '，${activityDateTimeText(item.signupEnd!)} 截止';
      await _plugin.show(
        id: _stableId('${item.stableKey}:slot'),
        title: '有名额了',
        body: '${item.title} 现在可以报名了$deadline',
        notificationDetails: _details(),
        payload: item.stableKey,
      );
    } catch (error) {
      debugPrint('ActivityNotificationService slot skipped: $error');
    }
  }

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_huayan',
    ),
    iOS: DarwinNotificationDetails(),
  );

  int _stableId(String value) {
    var hash = 17;
    for (final unit in value.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    return hash & 0x7fffffff;
  }
}
