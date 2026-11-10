import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/auth/gmis_password_vault.dart';
import 'package:huayan/storage/secure_key_value_store.dart';

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
  final now = DateTime(2026, 11, 10, 23);

  test('password vault round-trips and redacts toString', () async {
    final memory = _MemoryStore();
    final vault = GmisPasswordVault(store: memory, clock: () => now);
    await vault.write('2026000001', 'secret-password');
    final saved = await vault.read();
    expect(saved?.userId, '2026000001');
    expect(saved?.password, 'secret-password');
    expect('$saved', isNot(contains('secret-password')));
  });

  test('password vault drops entries older than maxAge', () async {
    final memory = _MemoryStore();
    var clock = now;
    final vault = GmisPasswordVault(
      store: memory,
      clock: () => clock,
      maxAge: const Duration(days: 7),
    );
    await vault.write('2026000001', 'secret-password');
    clock = now.add(const Duration(days: 8));
    expect(await vault.read(), isNull);
    expect(memory.values, isEmpty);
  });

  test('password vault clears malformed payloads', () async {
    final memory = _MemoryStore();
    memory.values[GmisPasswordVault.key] = '{"userId":"","password":""}';
    final vault = GmisPasswordVault(store: memory);
    expect(await vault.read(), isNull);
    expect(memory.values, isEmpty);
  });
}
