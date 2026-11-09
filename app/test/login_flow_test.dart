import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/auth/login_flow.dart';
import 'package:huayan/webvpn/webvpn_session.dart';

void main() {
  test('SSO prefill is kept in memory until login completes', () {
    final state = LoginFlowState();
    state.acceptSso(
      const SsoLoginSuccess(
        session: WebVpnSession(
          baseUrl: 'https://w.buct.edu.cn/https/token/',
          cookies: {'wengine_vpn_ticketw_buct_edu_cn': 'ticket'},
        ),
        prefill: LoginPrefill(userId: '2026000001', password: 'dummy-secret'),
      ),
    );

    expect(state.prefill?.userId, '2026000001');
    expect(state.prefill?.password, 'dummy-secret');
    expect(state.prefill.toString(), isNot(contains('dummy-secret')));

    state.markLoginComplete();
    expect(state.prefill, isNull);
  });

  test('tab resume state is bounded and cleared on logout', () {
    final state = LoginFlowState()..recordTab(3);
    expect(state.resumeTab, 3);
    state.recordTab(9);
    expect(state.resumeTab, 3);
    state.clear();
    expect(state.resumeTab, 0);
    expect(state.prefill, isNull);
  });
}
