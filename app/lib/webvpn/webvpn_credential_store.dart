import 'dart:convert';

import '../storage/secure_key_value_store.dart';
import '../storage/secure_session_store.dart';
import 'webvpn_credential.dart';

/// 只读写 WebVPN ticket 的安全存储。
///
/// 旧版本把 ticket 混在 `AuthSession` JSON 里，read() 会识别并迁移成
/// [WebVpnCredential]；迁移失败按“没有 ticket”处理，不影响启动。
class WebVpnCredentialStore {
  WebVpnCredentialStore({SecureKeyValueStore? store})
    : _store = store ?? FlutterSecureKeyValueStore();

  static const key = SecureSessionStore.webVpnTicketKey;

  final SecureKeyValueStore _store;

  Future<WebVpnCredential?> read() async {
    try {
      final raw = await _store.read(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      final isCredential =
          json['ticketName'] != null && json['ticketValue'] != null;
      final credential = isCredential
          ? WebVpnCredential.fromJson(json)
          : WebVpnCredential.fromLegacySession(json);
      if (credential == null || !credential.isValid) return null;
      if (!isCredential) {
        // 迁移到新格式，旧格式里的 userId 等字段不再保留；写失败也先
        // 用内存里的 credential 继续本次启动。
        try {
          await write(credential);
        } catch (_) {
          // ignore: 下一次保存会重试迁移。
        }
      }
      return credential;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(WebVpnCredential credential) {
    return _store.write(key, jsonEncode(credential.toJson()));
  }

  Future<void> clear() => _store.delete(key);
}
