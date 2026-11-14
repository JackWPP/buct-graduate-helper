import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/auth/login_flow.dart';
import 'package:huayan/gmis/gmis_exception.dart';
import 'package:huayan/webvpn/sso_login_page.dart';
import 'package:huayan/webvpn/webvpn_auth_client.dart';
import 'package:huayan/webvpn/webvpn_credential.dart';
import 'package:huayan/webvpn/webvpn_session.dart';

WebVpnSession _session() {
  final at = DateTime(2026, 11, 10);
  return WebVpnSession(
    baseUrl: 'https://w.buct.edu.cn/https/token/',
    credential: WebVpnCredential(
      ticketName: 'wengine_vpn_ticketw_buct_edu_cn',
      ticketValue: 'ticket',
      issuedAt: at,
      lastUsedAt: at,
    ),
  );
}

class _SuccessClient extends WebVpnAuthClient {
  var calls = 0;

  @override
  Future<WebVpnLoginResult> login({
    required String userId,
    required String password,
  }) async {
    calls++;
    return WebVpnLoginResult.session(_session());
  }
}

class _FailureClient extends WebVpnAuthClient {
  var calls = 0;

  @override
  Future<WebVpnLoginResult> login({
    required String userId,
    required String password,
  }) async {
    calls++;
    throw const GmisAuthException('密码错误');
  }
}

void main() {
  testWidgets('autoSubmit fills the saved password and logs in once', (
    tester,
  ) async {
    final client = _SuccessClient();
    SsoLoginSuccess? result;
    await tester.pumpWidget(
      MaterialApp(
        home: SsoLoginPage(
          client: client,
          initialSid: '2026000001',
          initialPassword: 'secret-password',
          autoSubmit: true,
          onSuccess: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.calls, 1);
    expect(result, isNotNull);
    expect(result!.prefill.password, 'secret-password');

    await tester.pump();
    expect(client.calls, 1, reason: '重建页面不应再次自动提交');
  });

  testWidgets('auto failure reports once and keeps the page editable', (
    tester,
  ) async {
    final client = _FailureClient();
    var failures = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SsoLoginPage(
          client: client,
          initialSid: '2026000001',
          initialPassword: 'wrong-password',
          autoSubmit: true,
          onSuccess: (_) {},
          onAutoLoginFailed: () => failures++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.calls, 1);
    expect(failures, 1);
    expect(find.byKey(const Key('sso-error')), findsOneWidget);
    expect(find.byKey(const Key('sso-pwd')), findsOneWidget);
  });

  testWidgets('updated notice is shown after an automatic attempt fails', (
    tester,
  ) async {
    var notice = '';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SsoLoginPage(
              client: _FailureClient(),
              initialSid: '2026000001',
              initialPassword: 'wrong-password',
              notice: notice,
              onSuccess: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    update(() => notice = '自动登录没有成功，请检查密码后重试');
    await tester.pump();

    expect(find.textContaining('自动登录没有成功'), findsOneWidget);
  });
}
