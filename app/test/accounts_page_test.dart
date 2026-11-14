import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/accounts/account_models.dart';
import 'package:huayan/accounts/accounts_page.dart';

AccountProfile _account(String id, String name, int usedDay) => AccountProfile(
  id: id,
  name: name,
  college: '信息学院',
  major: '计算机',
  storageKey: '',
  addedAt: DateTime(2026, 11, 1),
  lastUsedAt: DateTime(2026, 11, usedDay),
);

void main() {
  testWidgets('accounts page switches, adds and confirms removal', (
    tester,
  ) async {
    AccountProfile? switched;
    AccountProfile? removed;
    var added = 0;
    final accounts = [
      _account('2026000001', '李华', 1),
      _account('2026000002', '王明', 2),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: AccountsPage(
          accounts: accounts,
          activeId: '2026000001',
          switching: false,
          onSwitch: (account) => switched = account,
          onAdd: () => added++,
          onRemove: (account) async => removed = account,
        ),
      ),
    );

    expect(find.text('李华'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-2026000002')));
    expect(switched?.id, '2026000002');

    await tester.tap(find.byKey(const Key('account-add')));
    expect(added, 1);

    await tester.tap(find.byKey(const Key('account-remove-2026000001')));
    await tester.pumpAndSettle();
    expect(find.text('移除这个账号？'), findsOneWidget);
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    expect(removed?.id, '2026000001');
  });
}
