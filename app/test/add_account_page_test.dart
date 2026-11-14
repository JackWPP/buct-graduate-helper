import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/accounts/add_account_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    Set<String> existingIds = const {},
    required Future<void> Function(String sid) onContinue,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AddAccountPage(existingIds: existingIds, onContinue: onContinue),
      ),
    );
  }

  testWidgets('empty student id shows an error and does not continue', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpPage(tester, onContinue: (sid) async => calls.add(sid));

    await tester.tap(find.byKey(const Key('add-account-continue')));
    await tester.pump();

    expect(find.text('请输入学号'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('existing id shows a switch hint and still continues', (
    tester,
  ) async {
    final calls = <String>[];
    await pumpPage(
      tester,
      existingIds: {'2026000001'},
      onContinue: (sid) async => calls.add(sid),
    );

    await tester.enterText(
      find.byKey(const Key('add-account-sid')),
      '2026000001',
    );
    await tester.pump();
    expect(find.textContaining('已经保存在本机'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-account-continue')));
    await tester.pump();

    expect(calls, ['2026000001']);
  });

  testWidgets('continue shows loading while the callback runs', (tester) async {
    final completer = Completer<void>();
    await pumpPage(tester, onContinue: (_) => completer.future);

    await tester.enterText(
      find.byKey(const Key('add-account-sid')),
      '2026000002',
    );
    await tester.tap(find.byKey(const Key('add-account-continue')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pump();
  });

  testWidgets('callback failure is shown on the page', (tester) async {
    await pumpPage(tester, onContinue: (_) async => throw StateError('网络异常'));

    await tester.enterText(
      find.byKey(const Key('add-account-sid')),
      '2026000003',
    );
    await tester.tap(find.byKey(const Key('add-account-continue')));
    await tester.pumpAndSettle();

    expect(find.textContaining('添加账号失败'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
