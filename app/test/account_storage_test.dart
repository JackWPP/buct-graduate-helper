import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/accounts/account_models.dart';
import 'package:huayan/accounts/account_storage.dart';
import 'package:huayan/auth/auth_gateway.dart';
import 'package:huayan/auth/gmis_password_vault.dart';
import 'package:huayan/snapshot.dart';
import 'package:huayan/storage/secure_key_value_store.dart';
import 'package:huayan/storage/secure_session_store.dart';
import 'package:huayan/storage/snapshot_cache.dart';

class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

AccountProfile _profile(String id, {String storageKey = ''}) {
  return AccountProfile(
    id: id,
    name: '李华',
    college: '信息学院',
    major: '计算机',
    storageKey: storageKey,
    addedAt: DateTime(2026, 11, 1),
    lastUsedAt: DateTime(2026, 11, 10),
  );
}

Snapshot _snapshot() {
  return Snapshot(
    termName: '2026-2027 秋季学期',
    termStart: '2026-08-31',
    student: const Student(
      name: '李华',
      id: '2026000001',
      college: '信息学院',
      major: '计算机',
    ),
    courses: const [],
  );
}

void main() {
  late Directory temp;
  final now = DateTime(2026, 11, 10, 12);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('huayan-account-test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('account store saves and loads an account book', () async {
    final memory = _MemoryStore();
    final store = AccountStore(store: memory, clock: () => now);
    await store.save(
      AccountBook(
        accounts: [_profile('2026000001', storageKey: '2026000001')],
        activeId: '2026000001',
      ),
    );
    final loaded = await store.load();
    expect(loaded?.active?.id, '2026000001');
    expect(memory.values.keys, contains(AccountStore.key));
  });

  test('two accounts use different secure storage keys', () async {
    final memory = _MemoryStore();
    final first = AccountStorage(
      profile: _profile('2026000001', storageKey: '2026000001'),
      secureStore: memory,
      cacheDirectory: temp,
    );
    final second = AccountStorage(
      profile: _profile('2026000002', storageKey: '2026000002'),
      secureStore: memory,
      cacheDirectory: temp,
    );
    await first.passwordVault.write('2026000001', 'p1');
    await second.passwordVault.write('2026000002', 'p2');
    await first.sessionStore().write(
      AuthSession(
        userId: '2026000001',
        cookies: const {'a': '1'},
        savedAt: now,
      ),
    );
    await second.sessionStore().write(
      AuthSession(
        userId: '2026000002',
        cookies: const {'b': '2'},
        savedAt: now,
      ),
    );

    expect((await first.passwordVault.read())?.password, 'p1');
    expect((await second.passwordVault.read())?.password, 'p2');
    expect((await first.sessionStore().read())?.userId, '2026000001');
    expect((await second.sessionStore().read())?.userId, '2026000002');
    expect(memory.values.keys, contains('huayan_gmis_password_2026000001'));
    expect(memory.values.keys, contains('huayan_gmis_password_2026000002'));
    expect(memory.values.keys, contains('huayan_gmis_session_2026000001'));
    expect(second.snapshotCache.fileName, 'snapshot_v2_2026000002.json');
  });

  test('legacy migration uses old keys and snapshot fields', () async {
    final memory = _MemoryStore();
    await GmisPasswordVault(
      store: memory,
      clock: () => now,
    ).write('2026000001', 'secret');
    final cache = SnapshotCache(directory: temp);
    await cache.save(_snapshot());
    final book = await migrateLegacyAccountBook(
      vault: GmisPasswordVault(store: memory, clock: () => now),
      cache: cache,
      directSession: SecureSessionStore(store: memory),
      webVpnSession: SecureSessionStore(
        store: memory,
        key: SecureSessionStore.webVpnKey,
      ),
      clock: () => now,
    );
    expect(book?.activeId, '2026000001');
    expect(book?.active?.isLegacy, isTrue);
    expect(book?.active?.name, '李华');
    expect(book?.active?.college, '信息学院');
  });

  test(
    'session data clear keeps the account and other accounts intact',
    () async {
      final memory = _MemoryStore();
      final first = AccountStorage(
        profile: _profile('2026000001', storageKey: '2026000001'),
        secureStore: memory,
        cacheDirectory: temp,
      );
      final second = AccountStorage(
        profile: _profile('2026000002', storageKey: '2026000002'),
        secureStore: memory,
        cacheDirectory: temp,
      );
      await first.passwordVault.write('2026000001', 'p1');
      await second.passwordVault.write('2026000002', 'p2');
      await first.snapshotCache.save(_snapshot());
      await first.clearSessionData();
      expect(await first.passwordVault.read(), isNull);
      expect(await first.snapshotCache.load(), isNull);
      expect((await second.passwordVault.read())?.password, 'p2');
    },
  );

  test('snapshot cache sanitizes namespace in file name', () {
    expect(
      SnapshotCache(directory: temp, namespace: '../bad').fileName,
      'snapshot_v2____bad.json',
    );
    expect(SnapshotCache(directory: temp).fileName, 'snapshot_v2.json');
  });
}
