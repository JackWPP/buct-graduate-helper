import 'dart:io';

import '../auth/gmis_password_vault.dart';
import '../prefs.dart';
import '../storage/secure_key_value_store.dart';
import '../storage/secure_session_store.dart';
import '../storage/snapshot_cache.dart';
import '../term_calendar.dart';
import '../webvpn/sso_session_store.dart';
import '../webvpn/webvpn_credential_store.dart';
import 'account_models.dart';

/// 账号册的安全存储。只保存展示信息，不保存密码、Cookie、票据或验证码。
class AccountStore {
  AccountStore({SecureKeyValueStore? store, DateTime Function()? clock})
    : _store = store ?? FlutterSecureKeyValueStore(),
      _clock = clock ?? DateTime.now;

  static const key = 'huayan_accounts_v1';

  final SecureKeyValueStore _store;
  final DateTime Function() _clock;

  Future<AccountBook?> load() async {
    try {
      final raw = await _store.read(key);
      if (raw == null || raw.isEmpty) return null;
      return AccountBook.decode(raw);
    } catch (_) {
      // 账号册损坏不阻塞启动；调用方会按旧单账号数据重建。
      return null;
    }
  }

  Future<void> save(AccountBook book) {
    return _store.write(key, book.normalized().encode());
  }

  Future<void> clear() => _store.delete(key);

  DateTime now() => _clock();
}

/// 首次升级时，把旧单账号的学号/缓存/会话整理成一个 storageKey='' 的账号。
///
/// 只写账号册，不搬旧 key；旧账号继续使用原来的存储位置，避免迁移失败
/// 导致用户被登出。返回 null 表示本机确实没有可识别的旧账号。
Future<AccountBook?> migrateLegacyAccountBook({
  required GmisPasswordVault vault,
  required SnapshotCache cache,
  required SecureSessionStore directSession,
  required SecureSessionStore webVpnSession,
  PrefsStore? prefs,
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)();
  final saved = await vault.read();
  final snapshot = await cache.load();
  final direct = await directSession.read();
  final webVpn = await webVpnSession.read();
  final id =
      [
            saved?.userId,
            snapshot?.student.id,
            direct?.userId,
            webVpn?.userId,
            prefs?.sid,
          ]
          .map((value) => (value ?? '').trim())
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  if (id.isEmpty) return null;
  final addedAt = saved?.savedAt ?? now;
  return AccountBook(
    accounts: [
      AccountProfile(
        id: id,
        name: snapshot?.student.name ?? '',
        college: snapshot?.student.college ?? '',
        major: snapshot?.student.major ?? '',
        storageKey: legacyAccountStorageKey,
        addedAt: addedAt,
        lastUsedAt: now,
      ),
    ],
    activeId: id,
  );
}

/// 一个账号的存储命名空间。所有持久化都从这里取，避免业务层直接 new
/// 无后缀的 store 导致串号。
class AccountStorage {
  AccountStorage({
    required this.profile,
    SecureKeyValueStore? secureStore,
    this.cacheDirectory,
  }) : secureStore = secureStore ?? FlutterSecureKeyValueStore();

  final AccountProfile profile;
  final SecureKeyValueStore secureStore;
  final Directory? cacheDirectory;

  String get namespace => profile.storageKey;
  bool get isLegacy => profile.isLegacy;

  GmisPasswordVault get passwordVault =>
      GmisPasswordVault(store: secureStore, namespace: namespace);

  SsoSessionStore get ssoSessionStore =>
      SsoSessionStore(store: secureStore, namespace: namespace);

  WebVpnCredentialStore get webVpnCredentialStore =>
      WebVpnCredentialStore(store: secureStore, namespace: namespace);

  SecureSessionStore sessionStore({bool webVpn = false}) => SecureSessionStore(
    store: secureStore,
    key: webVpn ? SecureSessionStore.webVpnKey : null,
    namespace: namespace,
  );

  SnapshotCache get snapshotCache =>
      SnapshotCache(directory: cacheDirectory, namespace: namespace);

  TermCalendar termCalendar({PrefsStore? prefs}) =>
      TermCalendar(prefs: prefs, accountId: namespace);

  /// 退出当前账号：只清会话、密码、票据和缓存，保留账号资料与待办。
  Future<void> clearSessionData() async {
    await passwordVault.clear();
    await ssoSessionStore.clear();
    await webVpnCredentialStore.clear();
    await sessionStore().clear();
    await sessionStore(webVpn: true).clear();
    await snapshotCache.clear();
  }
}
