import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/auth/login_flow.dart';
import 'package:huayan/webvpn/sso_login_page.dart';
import 'package:huayan/webvpn/webvpn_auth_client.dart';
import 'package:huayan/webvpn/webvpn_session.dart';

class _FakeSsoClient extends WebVpnAuthClient {
  var sent = 0;

  @override
  Future<WebVpnLoginResult> login({
    required String userId,
    required String password,
  }) async {
    return const WebVpnLoginResult.smsRequired(
      WebVpnSmsChallenge(
        userId: '2026201060',
        phoneNumber: '13800138000',
        execution: 'flow-2',
      ),
    );
  }

  @override
  Future<SmsCodeSent> sendSmsCode() async {
    sent++;
    return const SmsCodeSent(intervalSeconds: 120);
  }

  @override
  Future<WebVpnSession> verifySmsCode(String code) async {
    return const WebVpnSession(
      baseUrl: 'https://w.buct.edu.cn/https/token/',
      cookies: {'wengine_vpn_ticketw_buct_edu_cn': 'ticket'},
    );
  }
}

void main() {
  testWidgets('SSO SMS flow keeps the password and passes a redacted prefill', (
    tester,
  ) async {
    final client = _FakeSsoClient();
    SsoLoginSuccess? result;
    await tester.pumpWidget(
      MaterialApp(
        home: SsoLoginPage(
          client: client,
          onSuccess: (value) => result = value,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('sso-sid')), '2026201060');
    await tester.enterText(find.byKey(const Key('sso-pwd')), 'dummy-secret');
    await tester.tap(find.byKey(const Key('sso-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sso-sms-code')), findsOneWidget);
    expect(find.byKey(const Key('sso-info')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sso-sms-send')));
    await tester.pump();
    expect(client.sent, 1);
    expect(find.textContaining('重新获取'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('sso-sms-code')), '123456');
    await tester.tap(find.byKey(const Key('sso-sms-submit')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.prefill.userId, '2026201060');
    expect(result!.prefill.password, 'dummy-secret');
    expect(result!.prefill.toString(), isNot(contains('dummy-secret')));
  });
}
