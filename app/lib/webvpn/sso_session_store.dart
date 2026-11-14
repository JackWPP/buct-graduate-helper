import 'dart:convert';

import '../storage/secure_key_value_store.dart';
import 'sso_session.dart';

/// 统一身份认证会话的安全存储。
///
/// 只在原生 SSO 成功后写入；退出登录、续签被拒或超过 [maxAge] 时清除。
/// 读取失败按“没有会话”处理，不阻塞启动。
class SsoSessionStore {
  SsoSessionStore({
    SecureKeyValueStore? store,
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 30),
    String namespace = '',
  }) : _store = store ?? FlutterSecureKeyValueStore(),
       _clock = clock ?? DateTime.now,
       _key = namespace.isEmpty ? key : '${key}_$namespace';

  static const key = 'huayan_sso_session';

  final SecureKeyValueStore _store;
  final DateTime Function() _clock;
  final Duration maxAge;
  final String _key;

  String get storageKey => _key;

  Future<SsoSession?> read() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final session = SsoSession.fromJson(Map<String, dynamic>.from(decoded));
      if (session == null) {
        await clear();
        return null;
      }
      if (_clock().difference(session.savedAt) > maxAge) {
        await clear();
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(SsoSession session) {
    return _store.write(_key, jsonEncode(session.toJson()));
  }

  Future<void> clear() => _store.delete(_key);
}
