import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/accounts/account_models.dart';
import 'package:huayan/accounts/account_session.dart';
import 'package:huayan/accounts/account_storage.dart';
import 'package:huayan/app_controller.dart';
import 'package:huayan/auth/gmis_password_vault.dart';
import 'package:huayan/storage/secure_key_value_store.dart';
import 'package:huayan/webvpn/webvpn_credential.dart';
import 'package:huayan/webvpn/webvpn_session.dart';
import 'package:huayan/webvpn/webvpn_session_manager.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late _MemoryStore memory;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('huayan-session-test');
    memory = _MemoryStore();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  AccountSession sessionFor(
    AccountProfile profile, {
    void Function(String)? onStage,
  }) {
    final storage = AccountStorage(
      profile: profile,
      secureStore: memory,
      cacheDirectory: temp,
    );
    return AccountSession(
      profile: profile,
      storage: storage,
      onWebVpnExpired: () async {},
      onStage: onStage,
    );
  }

  test('boot with no saved session routes to SSO and signs out', () async {
    final stages = <String>[];
    final session = sessionFor(_profile('2026000001'), onStage: stages.add);
    addTearDown(session.dispose);

    await session.boot();

    expect(session.route, WebVpnStartupRoute.ssoLogin);
    expect(session.savedLogin, isNull);
    expect(session.initialSid, '2026000001');
    expect(session.usingWebVpn, isFalse);
    expect(session.needsWebVpnLogin, isTrue);
    expect(session.controller, isNotNull);
    expect(session.controller!.phase, AppPhase.signedOut);
    expect(stages, isNotEmpty);
  });

  test('saved SSO login is loaded for auto SSO', () async {
    final storage = AccountStorage(
      profile: _profile('2026000001'),
      secureStore: memory,
      cacheDirectory: temp,
    );
    await storage.passwordVault.write(
      '2026000001',
      'secret-password',
      source: SavedCredentialSource.sso,
    );
    final session = sessionFor(_profile('2026000001'));
    addTearDown(session.dispose);

    await session.boot();

    expect(session.savedLogin?.userId, '2026000001');
    expect(session.savedLogin?.password, 'secret-password');
    expect(session.savedLogin?.source, SavedCredentialSource.sso);
    expect(session.savedLogin?.canAutoSso, isTrue);
    expect(session.initialSid, '2026000001');
    expect(session.route, WebVpnStartupRoute.ssoLogin);
  });

  test('account sessions do not share saved passwords', () async {
    final firstStorage = AccountStorage(
      profile: _profile('2026000001', storageKey: '2026000001'),
      secureStore: memory,
      cacheDirectory: temp,
    );
    await firstStorage.passwordVault.write(
      '2026000001',
      'first-password',
      source: SavedCredentialSource.sso,
    );
    final first = sessionFor(_profile('2026000001', storageKey: '2026000001'));
    final second = sessionFor(_profile('2026000002', storageKey: '2026000002'));
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await first.boot();
    await second.boot();

    expect(first.savedLogin?.password, 'first-password');
    expect(second.savedLogin, isNull);
    expect(memory.values.keys, contains('huayan_gmis_password_2026000001'));
    expect(
      memory.values.keys,
      isNot(contains('huayan_gmis_password_2026000002')),
    );
  });

  test('useDirectLogin rebuilds a non-WebVPN controller', () async {
    final session = sessionFor(_profile('2026000001'));
    addTearDown(session.dispose);
    await session.boot();
    final before = session.controller;

    await session.useDirectLogin();

    expect(session.controller, isNot(same(before)));
    expect(session.usingWebVpn, isFalse);
    expect(session.needsWebVpnLogin, isFalse);
    expect(session.controller!.phase, AppPhase.signedOut);
  });

  test('acceptWebVpnSession rebuilds and marks the WebVPN route', () async {
    final session = sessionFor(_profile('2026000001'));
    addTearDown(session.dispose);
    await session.boot();
    final before = session.controller;
    final now = DateTime(2026, 11, 10);
    final credential = WebVpnCredential(
      ticketName: 'wengine_vpn_ticketw_buct_edu_cn',
      ticketValue: 'ticket-value',
      issuedAt: now,
      lastUsedAt: now,
    );

    await session.acceptWebVpnSession(
      WebVpnSession(
        credential: credential,
        baseUrl: 'https://w.buct.edu.cn/https/token/',
      ),
    );

    expect(session.controller, isNot(same(before)));
    expect(session.usingWebVpn, isTrue);
    expect(session.needsWebVpnLogin, isFalse);
    expect(session.controller!.phase, AppPhase.signedOut);
  });
}
