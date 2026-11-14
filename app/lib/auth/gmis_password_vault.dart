import 'dart:convert';

import '../storage/secure_key_value_store.dart';

/// 密码来源：从统一身份认证带回的密码才可以自动尝试 SSO；
/// 直接填 GMIS 密码的旧记录只用于 GMIS 验证码预填。
enum SavedCredentialSource { sso, gmis, unknown }

SavedCredentialSource _sourceFromJson(Object? raw) {
  return switch ('${raw ?? ''}'.trim().toLowerCase()) {
    'sso' => SavedCredentialSource.sso,
    'gmis' => SavedCredentialSource.gmis,
    _ => SavedCredentialSource.unknown,
  };
}

String _sourceToJson(SavedCredentialSource source) => switch (source) {
  SavedCredentialSource.sso => 'sso',
  SavedCredentialSource.gmis => 'gmis',
  SavedCredentialSource.unknown => 'unknown',
};

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
    this.source = SavedCredentialSource.unknown,
    DateTime? lastUsedAt,
    this.autoFailedAt,
  }) : lastUsedAt = lastUsedAt ?? savedAt;

  final String userId;
  final String password;
  final DateTime savedAt;
  final SavedCredentialSource source;

  /// 最近一次被读取/使用的时间；滚动过期用它，而不是固定 savedAt。
  final DateTime lastUsedAt;

  /// 自动 SSO 失败时间，用于 15 分钟冷却。
  final DateTime? autoFailedAt;

  bool get canAutoSso => source != SavedCredentialSource.gmis;

  bool autoFailedRecently(
    DateTime now, {
    Duration cooldown = const Duration(minutes: 15),
  }) {
    final failedAt = autoFailedAt;
    if (failedAt == null) return false;
    return now.difference(failedAt) < cooldown;
  }

  SavedGmisLogin copyWith({
    String? userId,
    String? password,
    DateTime? savedAt,
    SavedCredentialSource? source,
    DateTime? lastUsedAt,
    DateTime? autoFailedAt,
    bool clearAutoFailure = false,
  }) {
    return SavedGmisLogin(
      userId: userId ?? this.userId,
      password: password ?? this.password,
      savedAt: savedAt ?? this.savedAt,
      source: source ?? this.source,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      autoFailedAt: clearAutoFailure
          ? null
          : (autoFailedAt ?? this.autoFailedAt),
    );
  }

  Map<String, Object?> toJson() => {
    'version': 2,
    'userId': userId,
    'password': password,
    'savedAt': savedAt.toIso8601String(),
    'source': _sourceToJson(source),
    'lastUsedAt': lastUsedAt.toIso8601String(),
    if (autoFailedAt != null) 'autoFailedAt': autoFailedAt!.toIso8601String(),
  };

  @override
  String toString() => 'SavedGmisLogin(userId: $userId, password: <redacted>)';
}

class GmisPasswordVault {
  GmisPasswordVault({
    SecureKeyValueStore? store,
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 180),
    String namespace = '',
  }) : _store = store ?? FlutterSecureKeyValueStore(),
       _clock = clock ?? DateTime.now,
       _key = namespace.isEmpty ? key : '${key}_$namespace';

  static const key = 'huayan_gmis_password';

  final SecureKeyValueStore _store;
  final DateTime Function() _clock;
  final Duration maxAge;
  final String _key;

  String get storageKey => _key;

  Future<SavedGmisLogin?> read({bool touch = false}) async {
    try {
      final raw = await _store.read(_key);
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
      final lastUsedAt = DateTime.tryParse('${json['lastUsedAt'] ?? ''}');
      final autoFailedAt = DateTime.tryParse('${json['autoFailedAt'] ?? ''}');
      final now = _clock();
      final activeSince = lastUsedAt ?? savedAt;
      if (savedAt == null ||
          activeSince == null ||
          now.difference(activeSince) > maxAge) {
        await clear();
        return null;
      }
      var login = SavedGmisLogin(
        userId: userId,
        password: password,
        savedAt: savedAt,
        source: _sourceFromJson(json['source']),
        lastUsedAt: activeSince,
        autoFailedAt: autoFailedAt,
      );
      if (touch) {
        login = login.copyWith(lastUsedAt: now);
        await _write(login);
      }
      return login;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String userId,
    String password, {
    SavedCredentialSource source = SavedCredentialSource.unknown,
  }) async {
    final id = userId.trim();
    if (id.isEmpty || password.isEmpty) return clear();
    final now = _clock();
    await _write(
      SavedGmisLogin(
        userId: id,
        password: password,
        savedAt: now,
        source: source,
        lastUsedAt: now,
      ),
    );
  }

  /// 会话过期后读取时调用，滚动延长凭据有效期。
  Future<void> touch() async {
    final saved = await read();
    if (saved == null) return;
    await _write(saved.copyWith(lastUsedAt: _clock()));
  }

  Future<void> markAutoFailure() async {
    final saved = await read();
    if (saved == null) return;
    await _write(saved.copyWith(autoFailedAt: _clock()));
  }

  Future<void> clearAutoFailure() async {
    final saved = await read();
    if (saved == null) return;
    await _write(saved.copyWith(clearAutoFailure: true));
  }

  Future<void> clear() => _store.delete(_key);

  Future<void> _write(SavedGmisLogin login) {
    return _store.write(_key, jsonEncode(login.toJson()));
  }
}
