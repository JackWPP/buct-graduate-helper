import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/settings.dart';
import 'package:huayan/snapshot.dart';
import 'package:huayan/subpages.dart';

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
  Future<void> pumpSettings(
    WidgetTester tester, {
    required AppSettings settings,
    int accountCount = 1,
    VoidCallback? onManageAccounts,
    VoidCallback? onLogout,
    ValueChanged<AppSettings>? onChanged,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          snap: _snapshot(),
          settings: settings,
          now: DateTime(2026, 11, 10, 12),
          onChanged: () => onChanged?.call(settings),
          onLogout: onLogout ?? () {},
          isLive: true,
          accountCount: accountCount,
          onManageAccounts: onManageAccounts,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('account management entry shows the account count', (
    tester,
  ) async {
    var opened = 0;
    await pumpSettings(
      tester,
      settings: AppSettings(),
      accountCount: 2,
      onManageAccounts: () => opened++,
    );

    expect(find.textContaining('本机保存了 2 个账号'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-accounts')));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('auto reconnect switch updates the setting', (tester) async {
    final settings = AppSettings();
    var changes = 0;
    await pumpSettings(tester, settings: settings, onChanged: (_) => changes++);

    final switchFinder = find.byKey(const Key('switch-auto-reconnect'));
    await tester.scrollUntilVisible(switchFinder, 200);
    await tester.tap(switchFinder);
    await tester.pump();

    expect(settings.autoReconnect, isFalse);
    expect(changes, 1);

    await tester.tap(switchFinder);
    await tester.pump();
    expect(settings.autoReconnect, isTrue);
    expect(changes, 2);
  });

  testWidgets('logout explains that account data is retained', (tester) async {
    var loggedOut = 0;
    await pumpSettings(
      tester,
      settings: AppSettings(),
      onLogout: () => loggedOut++,
    );

    final logoutFinder = find.byKey(const Key('logout-button'));
    await tester.scrollUntilVisible(logoutFinder, 300);
    await tester.tap(logoutFinder);
    await tester.pumpAndSettle();

    expect(find.text('退出当前账号？'), findsOneWidget);
    expect(find.textContaining('账号资料和本机待办保留'), findsOneWidget);
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    expect(loggedOut, 1);
  });
}
