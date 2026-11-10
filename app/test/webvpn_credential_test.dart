import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/storage/secure_key_value_store.dart';
import 'package:huayan/storage/secure_session_store.dart';
import 'package:huayan/webvpn/webvpn_credential.dart';
import 'package:huayan/webvpn/webvpn_credential_store.dart';

class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  final issued = DateTime(2026, 11, 10, 10);
  const ticketName = 'wengine_vpn_ticketw_buct_edu_cn';

  test('credential json round trip keeps metadata but redacts toString', () {
    final credential = WebVpnCredential(
      ticketName: ticketName,
      ticketValue: 'opaque-ticket',
      issuedAt: issued,
      lastUsedAt: issued,
      lastValidatedAt: issued,
      source: WebVpnCredential.sourceNativeSso,
    );
    final restored = WebVpnCredential.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(credential.toJson())) as Map,
      ),
    );

    expect(restored.ticketName, ticketName);
    expect(restored.ticketValue, 'opaque-ticket');
    expect(restored.lastValidatedAt, issued);
    expect(restored.source, WebVpnCredential.sourceNativeSso);
    expect(restored.cookieHeader, '$ticketName=opaque-ticket');
    expect(restored.toString(), isNot(contains('opaque-ticket')));
    expect(restored.toJson().containsKey('userId'), isFalse);
  });

  test('legacy AuthSession json migrates only the ticket', () {
    final legacy = {
      'userId': '2026000001',
      'savedAt': issued.toIso8601String(),
      'baseUrl': 'https://w.buct.edu.cn/https/token/',
      'cookies': {
        ticketName: 'legacy-ticket',
        'ASP.NET_SessionId': 'gmis-cookie',
      },
    };
    final credential = WebVpnCredential.fromLegacySession(legacy);

    expect(credential, isNotNull);
    expect(credential!.ticketValue, 'legacy-ticket');
    expect(credential.source, WebVpnCredential.sourceLegacy);
    expect(credential.issuedAt, issued);
    expect(credential.toJson().containsKey('userId'), isFalse);
    expect(credential.toJson().containsKey('cookies'), isFalse);
  });

  test('credential store reads and rewrites legacy format', () async {
    final memory = _MemoryStore();
    memory.values[WebVpnCredentialStore.key] = jsonEncode({
      'userId': '2026000001',
      'savedAt': issued.toIso8601String(),
      'cookies': {ticketName: 'legacy-ticket'},
    });
    final store = WebVpnCredentialStore(store: memory);

    final credential = await store.read();
    expect(credential?.ticketValue, 'legacy-ticket');
    final rewritten =
        jsonDecode(memory.values[WebVpnCredentialStore.key]!) as Map;
    expect(rewritten['ticketValue'], 'legacy-ticket');
    expect(rewritten['cookies'], isNull);
    expect(rewritten['userId'], isNull);
  });

  test('credential store rejects missing or invalid tickets', () async {
    final memory = _MemoryStore();
    final store = WebVpnCredentialStore(store: memory);
    expect(await store.read(), isNull);

    memory.values[WebVpnCredentialStore.key] = jsonEncode({
      'ticketName': 'other-cookie',
      'ticketValue': 'x',
    });
    expect(await store.read(), isNull);

    await store.write(
      WebVpnCredential(
        ticketName: ticketName,
        ticketValue: 'ticket',
        issuedAt: issued,
        lastUsedAt: issued,
      ),
    );
    expect((await store.read())?.ticketValue, 'ticket');
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('SecureSessionStore accepts an injected secure store', () async {
    final memory = _MemoryStore();
    final store = SecureSessionStore(
      store: memory,
      key: SecureSessionStore.directKey,
    );
    expect(await store.read(), isNull);
  });
}
