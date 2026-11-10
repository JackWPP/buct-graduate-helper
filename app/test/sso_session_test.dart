import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/storage/secure_key_value_store.dart';
import 'package:huayan/webvpn/sso_session.dart';
import 'package:huayan/webvpn/sso_session_store.dart';

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
  final now = DateTime(2026, 11, 10, 22);

  test('SsoSession round-trips cookies and redacts toString', () {
    final session = SsoSession(
      cookies: const {'SOURCEID_TGC': 'tgc-value', 'SESSION': 'session-value'},
      savedAt: now,
    );
    final restored = SsoSession.fromJson(session.toJson())!;
    expect(restored.cookies, session.cookies);
    expect(restored.savedAt, now);
    expect(session.toString(), isNot(contains('tgc-value')));
    expect(session.toString(), isNot(contains('session-value')));
  });

  test('SsoSessionStore drops sessions older than maxAge', () async {
    final memory = _MemoryStore();
    var clock = now;
    final store = SsoSessionStore(
      store: memory,
      clock: () => clock,
      maxAge: const Duration(days: 7),
    );
    await store.write(SsoSession(cookies: const {'TGC': 'x'}, savedAt: now));
    expect(await store.read(), isNotNull);
    clock = now.add(const Duration(days: 8));
    expect(await store.read(), isNull);
    expect(memory.values, isEmpty);
  });

  test('SsoSessionStore clears malformed payloads', () async {
    final memory = _MemoryStore();
    memory.values[SsoSessionStore.key] = '{"cookies":{}}';
    final store = SsoSessionStore(store: memory);
    expect(await store.read(), isNull);
    expect(memory.values, isEmpty);
  });
}
