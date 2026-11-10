import 'dart:convert';

import '../storage/secure_key_value_store.dart';

/// 本机保存的 GMIS 登录凭据，仅用于会话过期后的密码预填。
///
/// 密码只写入系统安全存储（Android Keystore 支持的
/// `flutter_secure_storage`），不写普通偏好、不写日志。用户可在登录页取消
/// “保持登录”，或在设置里清除；退出登录会一并删除。
class SavedGmisLogin {
  const SavedGmisLogin({
    required this.userId,
    required this.password,
    required this.savedAt,
  });

  final String userId;
  final String password;
  final DateTime savedAt;

  @override
  String toString() => 'SavedGmisLogin(userId: $userId, password: <redacted>)';
}

class GmisPasswordVault {
  GmisPasswordVault({
    SecureKeyValueStore? store,
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 180),
  }) : _store = store ?? FlutterSecureKeyValueStore(),
       _clock = clock ?? DateTime.now;

  static const key = 'huayan_gmis_password';

  final SecureKeyValueStore _store;
  final DateTime Function() _clock;
  final Duration maxAge;

  Future<SavedGmisLogin?> read() async {
    try {
      final raw = await _store.read(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      final userId = '${json['userId'] ?? ''}'.trim();
      final password = '${json['password'] ?? ''}';
      if (userId.isEmpty || password.isEmpty) {
        await clear();
        return null;
      }
      final savedAt = DateTime.tryParse('${json['savedAt'] ?? ''}');
      if (savedAt == null || _clock().difference(savedAt) > maxAge) {
        await clear();
        return null;
      }
      return SavedGmisLogin(
        userId: userId,
        password: password,
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, String password) {
    final id = userId.trim();
    if (id.isEmpty || password.isEmpty) return clear();
    return _store.write(
      key,
      jsonEncode({
        'version': 1,
        'userId': id,
        'password': password,
        'savedAt': _clock().toIso8601String(),
      }),
    );
  }

  Future<void> clear() => _store.delete(key);
}
