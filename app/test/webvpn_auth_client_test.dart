import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/gmis/gmis_exception.dart';
import 'package:huayan/gmis/gmis_transport.dart';
import 'package:huayan/webvpn/webvpn_auth_client.dart';
import 'package:huayan/webvpn/webvpn_credential.dart';
import 'package:huayan/webvpn/webvpn_exception.dart';
import 'package:huayan/webvpn/webvpn_validator.dart';

class _FakeTransport implements GmisTransport {
  _FakeTransport(this.responses);

  final List<GmisResponse> responses;
  final requests = <GmisRequest>[];
  var _index = 0;

  @override
  Future<GmisResponse> send(GmisRequest request) async {
    requests.add(request);
    return responses[_index++];
  }
}

class _FakeValidator implements WebVpnValidator {
  _FakeValidator(this.state);

  final WebVpnState state;

  @override
  Future<WebVpnValidation> validate(WebVpnCredential credential) async {
    return WebVpnValidation(state);
  }
}

GmisResponse _response(
  int status, {
  String body = '',
  Map<String, List<String>> headers = const {},
}) {
  return GmisResponse(
    statusCode: status,
    headers: headers,
    body: body,
    bytes: Uint8List(0),
  );
}

void main() {
  test('统一身份认证登录换取 WebVPN Cookie', () async {
    final sso = _FakeTransport([
      _response(
        200,
        body:
            '<p id="login-croypto">AAAAAAAAAAAAAAAAAAAAAA==</p>'
            '<p id="login-page-flowkey">flow-1</p>',
        headers: {
          'set-cookie': ['SESSION=sso-session; Path=/; HttpOnly'],
        },
      ),
      _response(
        302,
        headers: {
          'location': [
            'https://w.buct.edu.cn/login?cas_login=true&ticket=ST-123',
          ],
        },
      ),
    ]);
    final webVpn = _FakeTransport([
      _response(
        302,
        headers: {
          'location': ['https://w.buct.edu.cn/'],
          'set-cookie': [
            'wengine_vpn_ticketw_buct_edu_cn=ticket-1; Path=/; Secure; HttpOnly',
          ],
        },
      ),
      _response(200, body: '<html>ok</html>'),
    ]);

    final client = WebVpnAuthClient(
      ssoTransport: sso,
      webVpnTransport: webVpn,
      validator: _FakeValidator(WebVpnState.valid),
    );
    final result = await client.login(userId: '2026000001', password: 'secret');
    expect(result.needsSms, isFalse);
    final session = result.session!;

    expect(session.baseUrl, contains('w.buct.edu.cn/https/'));
    expect(session.hasTicket, isTrue);
    expect(session.credential.ticketValue, 'ticket-1');
    expect(sso.requests, hasLength(2));
    final form = sso.requests.last.form!;
    expect(form['type'], 'UsernamePassword');
    expect(form['execution'], 'flow-1');
    expect(form['username'], '2026000001');
    expect(form['password'], isNotEmpty);
    expect(form['password'], isNot('secret'));
    expect(
      sso.requests.last.headers['Cookie'],
      contains('SESSION=sso-session'),
    );
    expect(webVpn.requests, hasLength(2));
  });

  test('用留存 SSO Cookie 静默换新 ticket', () async {
    final sso = _FakeTransport([
      _response(
        302,
        headers: {
          'location': [
            'https://w.buct.edu.cn/login?cas_login=true&ticket=ST-9',
          ],
        },
      ),
    ]);
    final webVpn = _FakeTransport([
      _response(
        302,
        headers: {
          'location': ['https://w.buct.edu.cn/'],
          'set-cookie': [
            'wengine_vpn_ticketw_buct_edu_cn=ticket-9; Path=/; Secure; HttpOnly',
          ],
        },
      ),
      _response(200, body: '<html>ok</html>'),
    ]);
    final client = WebVpnAuthClient(
      ssoTransport: sso,
      webVpnTransport: webVpn,
      validator: _FakeValidator(WebVpnState.valid),
    );

    final session = await client.renewSilently(
      ssoCookies: const {'SOURCEID_TGC': 'tgc-1'},
    );
    expect(session, isNotNull);
    expect(session!.credential.ticketValue, 'ticket-9');
    expect(
      sso.requests.single.headers['Cookie'],
      contains('SOURCEID_TGC=tgc-1'),
    );
    expect(webVpn.requests, hasLength(2));
  });

  test('SSO 会话失效时静默续签返回 null', () async {
    final sso = _FakeTransport([
      _response(200, body: '<p id="login-page-flowkey">flow-2</p>'),
    ]);
    final client = WebVpnAuthClient(
      ssoTransport: sso,
      webVpnTransport: _FakeTransport([]),
      validator: _FakeValidator(WebVpnState.valid),
    );

    final session = await client.renewSilently(
      ssoCookies: const {'SOURCEID_TGC': 'stale'},
    );
    expect(session, isNull);
    expect(
      sso.requests.single.headers['Cookie'],
      contains('SOURCEID_TGC=stale'),
    );
  });

  test('错误凭证显示统一身份认证错误码', () async {
    final sso = _FakeTransport([
      _response(
        200,
        body:
            '<p id="login-croypto">AAAAAAAAAAAAAAAAAAAAAA==</p>'
            '<p id="login-page-flowkey">flow-1</p>',
      ),
      _response(401, body: '<p id="login-error-msg">1030028</p>'),
    ]);
    final client = WebVpnAuthClient(
      ssoTransport: sso,
      webVpnTransport: _FakeTransport([]),
      validator: _FakeValidator(WebVpnState.valid),
    );

    expect(
      () => client.login(userId: '2026000001', password: 'bad'),
      throwsA(
        isA<GmisAuthException>().having(
          (error) => error.message,
          'message',
          contains('学号或密码'),
        ),
      ),
    );
  });

  test('密码加密输出是 AES-ECB 的 base64 密文', () {
    final encrypted = WebVpnAuthClient.encryptSsoPassword(
      base64Encode(Uint8List(16)),
      'secret',
    );
    final bytes = base64Decode(encrypted);
    expect(bytes.length, 16);
    expect(bytes.length % 16, 0);
  });

  test('短信二次认证流程发送验证码并换取 WebVPN 会话', () async {
    final sso = _FakeTransport([
      _response(
        200,
        body:
            '<p id="login-croypto">AAAAAAAAAAAAAAAAAAAAAA==</p>'
            '<p id="login-page-flowkey">flow-1</p>',
      ),
      _response(
        200,
        body:
            '<p id="current-login-type">smsLogin</p>'
            '<p id="sso-second">true</p>'
            '<p id="second-auth-user-id">2026000001</p>'
            '<p id="phone-number">13800138000</p>'
            '<p id="login-page-flowkey">flow-2</p>',
      ),
      _response(
        200,
        body: '{"code":200,"message":"OK","data":{"result":true}}',
      ),
      _response(200, body: '{"code":200,"message":"OK","data":true}'),
      _response(
        302,
        headers: {
          'location': [
            'https://w.buct.edu.cn/login?cas_login=true&ticket=ST-456',
          ],
        },
      ),
    ]);
    final webVpn = _FakeTransport([
      _response(
        302,
        headers: {
          'location': ['https://w.buct.edu.cn/'],
          'set-cookie': [
            'wengine_vpn_ticketw_buct_edu_cn=ticket-2; Path=/; Secure; HttpOnly',
          ],
        },
      ),
      _response(200, body: '<html>ok</html>'),
    ]);
    final client = WebVpnAuthClient(
      ssoTransport: sso,
      webVpnTransport: webVpn,
      validator: _FakeValidator(WebVpnState.valid),
    );

    final first = await client.login(userId: '2026000001', password: 'secret');
    expect(first.needsSms, isTrue);
    expect(first.challenge!.maskedPhone, '138****8000');

    await client.sendSmsCode();
    final sendRequest = sso.requests[2];
    expect(sendRequest.json!['phone'], '13800138000');
    expect(sendRequest.json!['businessNo'], '0008');
    expect(sendRequest.headers['Csrf-Key']!.length, 32);
    expect(sendRequest.headers['Csrf-Value']!.length, 32);

    final session = await client.verifySmsCode('123456');
    expect(session.hasTicket, isTrue);
    expect(session.credential.ticketValue, 'ticket-2');
    expect(sso.requests[4].form!['type'], 'smsLogin');
    expect(sso.requests[4].form!['password'], '123456');
    expect(sso.requests[4].form!['execution'], 'flow-2');
  });

  test('匿名 ticket 不能当登录成功', () async {
    final sso = _FakeTransport([
      _response(
        200,
        body:
            '<p id="login-croypto">AAAAAAAAAAAAAAAAAAAAAA==</p>'
            '<p id="login-page-flowkey">flow-1</p>',
      ),
      _response(
        302,
        headers: {
          'location': [
            'https://w.buct.edu.cn/login?cas_login=true&ticket=ST-invalid',
          ],
        },
      ),
    ]);
    final webVpn = _FakeTransport([
      _response(
        200,
        body: '<title>统一身份认证平台</title>',
        headers: {
          'set-cookie': [
            'wengine_vpn_ticketw_buct_edu_cn=anonymous; Path=/; Secure; HttpOnly',
          ],
        },
      ),
    ]);
    final client = WebVpnAuthClient(
      ssoTransport: sso,
      webVpnTransport: webVpn,
      validator: _FakeValidator(WebVpnState.expired),
    );

    expect(
      () => client.login(userId: '2026000001', password: 'secret'),
      throwsA(isA<WebVpnAuthException>()),
    );
  });

  test('已登录时 GET 直接拿到有效 ticket 就不再提交密码', () async {
    final sso = _FakeTransport([
      _response(
        302,
        headers: {
          'location': [
            'https://w.buct.edu.cn/login?cas_login=true&ticket=ST-existing',
          ],
        },
      ),
    ]);
    final webVpn = _FakeTransport([
      _response(
        200,
        headers: {
          'set-cookie': [
            'wengine_vpn_ticketw_buct_edu_cn=ticket-existing; Path=/; Secure; HttpOnly',
          ],
        },
      ),
    ]);
    final client = WebVpnAuthClient(
      ssoTransport: sso,
      webVpnTransport: webVpn,
      validator: _FakeValidator(WebVpnState.valid),
    );

    final result = await client.login(userId: '2026000001', password: 'secret');
    expect(result.session!.credential.ticketValue, 'ticket-existing');
    expect(sso.requests, hasLength(1));
  });
}
