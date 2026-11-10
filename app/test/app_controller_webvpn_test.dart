import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/app_controller.dart';
import 'package:huayan/auth/auth_gateway.dart';
import 'package:huayan/gmis/gmis_api.dart';
import 'package:huayan/gmis/gmis_client.dart';
import 'package:huayan/gmis/gmis_exception.dart';
import 'package:huayan/gmis/gmis_transport.dart';
import 'package:huayan/storage/secure_key_value_store.dart';
import 'package:huayan/storage/secure_session_store.dart';
import 'package:huayan/storage/snapshot_cache.dart';
import 'package:huayan/webvpn/webvpn_exception.dart';

class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeGateway implements AuthGateway {
  _FakeGateway({this.restoreError});

  final Object? restoreError;

  @override
  Future<CaptchaChallenge> fetchCaptcha() async =>
      const CaptchaChallenge(demoCode: '0000');

  @override
  Future<AuthSession> login({
    required String userId,
    required String password,
    required String captcha,
  }) async {
    return AuthSession(
      userId: userId,
      cookies: const {},
      savedAt: DateTime(2026, 11, 10),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> restore(AuthSession session) async {
    final error = restoreError;
    if (error != null) throw error;
  }
}

class _NoopTransport implements GmisTransport {
  @override
  Future<GmisResponse> send(GmisRequest request) async {
    return GmisResponse(
      statusCode: 200,
      headers: const {},
      body: '{}',
      bytes: Uint8List(0),
    );
  }
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('huayan_webvpn_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<AuthSession> seedSession(SecureKeyValueStore memory) async {
    final session = AuthSession(
      userId: '2026000001',
      cookies: const {'ASP.NET_SessionId': 'gmis-cookie'},
      savedAt: DateTime(2026, 11, 10),
      baseUrl: 'https://w.buct.edu.cn/https/token/',
    );
    await SecureSessionStore(store: memory, key: SecureSessionStore.webVpnKey)
        .write(session);
    return session;
  }

  test('WebVPN 过期进入 webVpnExpired，且不清 GMIS 会话', () async {
    final memory = _MemoryStore();
    await seedSession(memory);
    var expiredCallbacks = 0;
    final gateway = _FakeGateway(restoreError: const WebVpnSessionExpired());
    final client = GmisClient(transport: _NoopTransport());
    final controller = AppController(
      gateway: gateway,
      api: GmisApi(client),
      sessionStore: SecureSessionStore(
        store: memory,
        key: SecureSessionStore.webVpnKey,
      ),
      cache: SnapshotCache(directory: temp),
      onWebVpnExpired: () async => expiredCallbacks++,
    );

    await controller.bootstrap();

    expect(controller.phase, AppPhase.webVpnExpired);
    expect(controller.error, contains('校外访问'));
    expect(expiredCallbacks, 1);
    expect(
      await SecureSessionStore(
        store: memory,
        key: SecureSessionStore.webVpnKey,
      ).read(),
      isNotNull,
    );
  });

  test('GMIS 过期保持 sessionExpired 并清 GMIS 会话', () async {
    final memory = _MemoryStore();
    await seedSession(memory);
    final gateway = _FakeGateway(restoreError: const GmisSessionExpired());
    final client = GmisClient(transport: _NoopTransport());
    final controller = AppController(
      gateway: gateway,
      api: GmisApi(client),
      sessionStore: SecureSessionStore(
        store: memory,
        key: SecureSessionStore.webVpnKey,
      ),
      cache: SnapshotCache(directory: temp),
    );

    await controller.bootstrap();

    expect(controller.phase, AppPhase.sessionExpired);
    expect(
      await SecureSessionStore(
        store: memory,
        key: SecureSessionStore.webVpnKey,
      ).read(),
      isNull,
    );
  });
}
