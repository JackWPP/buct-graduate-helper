import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/main.dart';
import 'package:huayan/prefs.dart';
import 'package:huayan/snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final snap = Snapshot.fromJson(
    jsonDecode(File('assets/snapshot.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final now = DateTime(2026, 11, 3, 11, 37);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  String readCaptcha(WidgetTester tester) {
    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(const Key('captcha')),
        matching: find.byType(Text),
      ),
    );
    return texts.map((text) => text.data ?? '').join();
  }

  Future<void> openLogin(WidgetTester tester) async {
    await phone(tester);
    await tester.pumpWidget(HuayanApp(now: now, snapshot: snap));
    await tester.pumpAndSettle();
    expect(find.textContaining('一张表看清'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('剩下的事它帮你盯着'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-sid')), findsOneWidget);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tab-me')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('me-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('me-settings')));
    await tester.pumpAndSettle();
  }

  Future<void> submitLogin(
    WidgetTester tester, {
    String? code,
    String password = 'snapshot-only',
  }) async {
    await tester.enterText(find.byKey(const Key('login-pwd')), password);
    await tester.enterText(
      find.byKey(const Key('login-code')),
      code ?? readCaptcha(tester),
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('first launch shows the guide and can skip to login', (
    tester,
  ) async {
    await openLogin(tester);
    expect(find.text('密码不会保存'), findsNothing);
    expect(find.textContaining('密码不会保存'), findsOneWidget);
  });

  testWidgets('a wrong captcha stays on the login page', (tester) async {
    await openLogin(tester);
    final code = readCaptcha(tester);
    await submitLogin(tester, code: code == '0000' ? '1111' : '0000');
    expect(find.text('验证码错误'), findsOneWidget);
    expect(find.text('上午好，王海翔'), findsNothing);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });

  testWidgets('demo login reaches home and the eval card', (tester) async {
    await openLogin(tester);
    await submitLogin(tester);
    expect(find.text('上午好，王海翔'), findsOneWidget);
    expect(find.text('最要紧的一件事'), findsOneWidget);
    expect(
      find.text('还有 ${pendingEvalCount(snap.evaluations)} 门课没评'),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs
        .getKeys()
        .map((key) => '$key=${prefs.get(key)}')
        .join('\n');
    expect(stored.contains('snapshot-only'), isFalse);
    expect(stored.toLowerCase().contains('password'), isFalse);
    expect(prefs.getString(PrefsStore.sidKey), '2026201060');

    await tester.tap(find.text('去评教'));
    await tester.pumpAndSettle();
    expect(find.text('课程评教'), findsOneWidget);
  });

  testWidgets('swiping the timetable changes week inside the same bounds', (
    tester,
  ) async {
    await openLogin(tester);
    await submitLogin(tester);
    await tester.tap(find.byKey(const Key('tab-timetable')));
    await tester.pumpAndSettle();
    expect(find.text('第 10 周'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('timetable-scroll')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 11 周'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('timetable-scroll')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 10 周'), findsOneWidget);
  });

  testWidgets('the reminder switch survives a new session', (tester) async {
    await openLogin(tester);
    await submitLogin(tester);
    await openSettings(tester);
    final before = tester.widget<Switch>(
      find.byKey(const Key('switch-reminder')),
    );
    expect(before.value, isTrue);
    await tester.tap(find.byKey(const Key('switch-reminder')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(HuayanApp(now: now, snapshot: snap));
    await tester.pumpAndSettle();
    await submitLogin(tester);
    await openSettings(tester);
    final after = tester.widget<Switch>(
      find.byKey(const Key('switch-reminder')),
    );
    expect(after.value, isFalse);
  });

  testWidgets('logout returns to login and keeps the student id', (
    tester,
  ) async {
    await openLogin(tester);
    await submitLogin(tester);
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('logout-button')));
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(find.text('退出登录？'), findsOneWidget);
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-sid')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('login-sid')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller?.text, '2026201060');
    expect(find.text('上午好，王海翔'), findsNothing);
  });
}
