import 'package:flutter/foundation.dart';

import 'auth/auth_gateway.dart';
import 'gmis/gmis_api.dart';
import 'gmis/gmis_exception.dart';
import 'gmis/live_snapshot_builder.dart';
import 'storage/secure_session_store.dart';
import 'snapshot.dart';
import 'storage/snapshot_cache.dart';
import 'term_calendar.dart';

enum AppPhase { booting, signedOut, restoring, ready, offline, sessionExpired }

/// 应用级状态机：登录、恢复会话、刷新真实快照、离线缓存和退出。
class AppController extends ChangeNotifier {
  AppController({
    required this.gateway,
    required this.api,
    required this.sessionStore,
    required this.cache,
    TermCalendar? calendar,
  }) : calendar = calendar ?? const TermCalendar() {
    _builder = LiveSnapshotBuilder(api: api, calendar: this.calendar);
  }

  final AuthGateway gateway;
  final GmisApi api;
  final SecureSessionStore sessionStore;
  final SnapshotCache cache;
  final TermCalendar calendar;

  late final LiveSnapshotBuilder _builder;

  AppPhase _phase = AppPhase.booting;
  Snapshot? _snapshot;
  String? _error;
  CaptchaChallenge? _captcha;
  String? _notice;
  bool _refreshing = false;
  bool _disposed = false;
  DateTime? _lastRefreshedAt;

  AppPhase get phase => _phase;
  Snapshot? get snapshot => _snapshot;
  String? get error => _error;
  CaptchaChallenge? get captcha => _captcha;
  String? get notice => _notice;
  bool get refreshing => _refreshing;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;
  bool get termStartKnown => _snapshot?.termStartKnown ?? true;

  Future<void> bootstrap() async {
    final cached = await cache.load();
    final session = await sessionStore.read();
    if (session == null) {
      _phase = AppPhase.signedOut;
      _notify();
      return;
    }
    // 只有本机存在登录会话时才展示缓存，避免未登录状态泄露课表。
    if (cached != null) _snapshot = cached;
    _phase = AppPhase.restoring;
    _notify();
    try {
      await gateway.restore(session);
      await _refreshFromLive();
    } on GmisSessionExpired {
      await expireSession();
    } catch (error) {
      _error = _messageOf(error);
      _phase = _snapshot == null ? AppPhase.signedOut : AppPhase.offline;
      _notify();
    }
  }

  /// 会话过期：只清 GMIS 会话，保留缓存和已加载的 snapshot，供登录页回跳使用。
  Future<void> expireSession() async {
    await sessionStore.clear();
    _phase = AppPhase.sessionExpired;
    _error = '登录已过期，请重新登录';
    _notify();
  }

  Future<CaptchaChallenge?> fetchCaptcha() async {
    _error = null;
    try {
      final challenge = await gateway.fetchCaptcha();
      _captcha = challenge;
      _notify();
      return challenge;
    } catch (error) {
      _error = _messageOf(error);
      _notify();
      return null;
    }
  }

  /// 返回 null 表示登录并刷新成功；否则返回给登录页显示的失败原因。
  Future<String?> login({
    required String userId,
    required String password,
    required String captcha,
  }) async {
    _error = null;
    _notify();
    try {
      final session = await gateway.login(
        userId: userId,
        password: password,
        captcha: captcha,
      );
      await sessionStore.write(session);
      await _refreshFromLive();
      return null;
    } on GmisSessionExpired catch (error) {
      await sessionStore.clear();
      _phase = AppPhase.sessionExpired;
      _error = error.message;
      _notify();
      return error.message;
    } catch (error) {
      final message = _messageOf(error);
      _error = message;
      _phase = AppPhase.signedOut;
      _notify();
      return message;
    }
  }

  Future<bool> refresh() async {
    if (_refreshing) return _phase == AppPhase.ready;
    _refreshing = true;
    _error = null;
    _notify();
    try {
      await _refreshFromLive();
      return true;
    } on GmisSessionExpired catch (error) {
      await sessionStore.clear();
      _phase = AppPhase.sessionExpired;
      _error = error.message;
      _notify();
    } catch (error) {
      _error = _messageOf(error);
      _phase = _snapshot == null ? AppPhase.signedOut : AppPhase.offline;
      _notify();
    } finally {
      _refreshing = false;
      _notify();
    }
    return false;
  }

  Future<void> logout() async {
    try {
      await gateway.logout();
    } catch (_) {
      // 退出时网络失败也要清本地状态。
    }
    await sessionStore.clear();
    await cache.clear();
    _snapshot = null;
    _captcha = null;
    _error = null;
    _notice = null;
    _lastRefreshedAt = null;
    _phase = AppPhase.signedOut;
    _notify();
  }

  Future<void> _refreshFromLive() async {
    final result = await _builder.build(
      fallbackServices: _snapshot?.services ?? const [],
    );
    _snapshot = result.snapshot;
    _notice = result.termStartKnown
        ? null
        : '没有找到 ${result.snapshot.termName} 的开学日期，周次可能不准确。';
    try {
      await cache.save(result.snapshot);
    } catch (_) {
      // 缓存失败不影响本次登录后的页面；下次打开重新拉取即可。
    }
    _lastRefreshedAt = DateTime.now();
    _phase = AppPhase.ready;
    _error = null;
    _notify();
  }

  String _messageOf(Object error) {
    if (error is GmisException) return error.message;
    return '操作失败，请稍后重试';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
