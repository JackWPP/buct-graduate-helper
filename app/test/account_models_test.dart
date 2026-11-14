import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/accounts/account_models.dart';

AccountProfile _profile(
  String id, {
  String name = '',
  String storageKey = '',
  int usedDay = 1,
}) {
  return AccountProfile(
    id: id,
    name: name,
    college: '信息学院',
    major: '计算机',
    storageKey: storageKey,
    addedAt: DateTime(2026, 11, 1),
    lastUsedAt: DateTime(2026, 11, usedDay),
  );
}

void main() {
  test('account book round-trips through JSON', () {
    final book = AccountBook(
      accounts: [
        _profile('2026000001', name: '李华'),
        _profile('2026000002', name: '王明', storageKey: '2026000002'),
      ],
      activeId: '2026000002',
    );
    final decoded = AccountBook.decode(book.encode());
    expect(decoded.accounts, hasLength(2));
    expect(decoded.active?.name, '王明');
    expect(decoded.byId('2026000001')?.isLegacy, isTrue);
    expect(decoded.byId('2026000002')?.storageKey, '2026000002');
  });

  test('upsert keeps the original addedAt and storageKey', () {
    final book = AccountBook(
      accounts: [_profile('2026000001', name: '旧名字')],
      activeId: '2026000001',
    );
    final next = book.upsert(
      _profile('2026000001', name: '新名字', storageKey: 'new-key'),
    );
    expect(next.accounts.single.name, '新名字');
    expect(next.accounts.single.addedAt, DateTime(2026, 11, 1));
    expect(next.accounts.single.storageKey, legacyAccountStorageKey);
  });

  test('removing the active account falls back to most recently used', () {
    final book = AccountBook(
      accounts: [
        _profile('2026000001', usedDay: 1),
        _profile('2026000002', usedDay: 5),
        _profile('2026000003', usedDay: 3),
      ],
      activeId: '2026000001',
    );
    final next = book.remove('2026000001');
    expect(next.activeId, '2026000002');
    expect(next.accounts, hasLength(2));
  });

  test('removing the last account clears activeId', () {
    final book = AccountBook(
      accounts: [_profile('2026000001')],
      activeId: '2026000001',
    );
    final next = book.remove('2026000001');
    expect(next.isEmpty, isTrue);
    expect(next.activeId, isNull);
  });

  test('normalized drops empty/duplicate ids and repairs activeId', () {
    final book = AccountBook(
      accounts: [
        _profile(''),
        _profile('2026000001'),
        _profile('2026000001'),
        _profile('bad/id', storageKey: 'bad/id'),
      ],
      activeId: 'missing',
    ).normalized();
    expect(book.accounts.map((account) => account.id), [
      '2026000001',
      'bad/id',
    ]);
    expect(book.activeId, '2026000001');
    expect(book.byId('bad/id')?.storageKey, 'bad_id');
  });

  test('storage key sanitizes path separators', () {
    expect(accountStorageKeyFor('../abc'), '___abc');
    expect(accountStorageKeyFor('a/b c'), 'a_b_c');
    expect(accountStorageKeyFor(''), legacyAccountStorageKey);
  });
}
