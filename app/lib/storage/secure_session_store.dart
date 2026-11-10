import 'dart:convert';

import '../auth/auth_gateway.dart';
import 'secure_key_value_store.dart';

/// Cookie 和学号用系统安全存储保存；密码永远不在这里。
class SecureSessionStore {
  SecureSessionStore({SecureKeyValueStore? store, String? key})
    : _store = store ?? FlutterSecureKeyValueStore(),
      _key = key ?? directKey;

  static const directKey = 'huayan_gmis_session';
  static const webVpnKey = 'huayan_gmis_webvpn_session';
  static const webVpnTicketKey = 'huayan_webvpn_ticket';

  final SecureKeyValueStore _store;
  final String _key;

  Future<AuthSession?> read() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || raw.isEmpty) return null;
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 安全存储在少数设备上可能抛平台异常；按“没有会话”处理，
      // 让用户重新登录，而不是让启动页永远卡住。
      return null;
    }
  }

  Future<void> write(AuthSession session) {
    return _store.write(_key, jsonEncode(session.toJson()));
  }

  Future<void> clear() => _store.delete(_key);
}
