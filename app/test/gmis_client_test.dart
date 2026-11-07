import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/auth/auth_gateway.dart';
import 'package:huayan/gmis/gmis_api.dart';
import 'package:huayan/gmis/gmis_client.dart';
import 'package:huayan/gmis/gmis_exception.dart';
import 'package:huayan/gmis/gmis_transport.dart';

const _publicKey = '''
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDSsOsjPum/eh6Ve/k+W6lqfyRc
szk/XJfMuD2QJnp3MZhmECVs/84QS2SGMtpe+IMUCyN7xo+MC7rHLdiuxqaZXPdu
KbVoC8s/MUDdM/bvsT/LJ1j6LLHBrGVYhOzJu5JOH+v6SBj3QjthGVJ5UNcxgwTY
fIRAsJr4yyEPpRHyvwIDAQAB
-----END PUBLIC KEY-----
''';

class _FakeTransport implements GmisTransport {
  _FakeTransport(this.handler);

  final GmisResponse Function(GmisRequest request) handler;
  final requests = <GmisRequest>[];

  @override
  Future<GmisResponse> send(GmisRequest request) async {
    requests.add(request);
    return handler(request);
  }
}

GmisResponse _response(
  String body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) {
  return GmisResponse(statusCode: status, headers: headers, body: body);
}

void main() {
  test('login keeps the captcha public key and cookies', () async {
    final transport = _FakeTransport((request) {
      switch (request.path) {
        case '/home/stulogin':
          return GmisResponse(
            statusCode: 200,
            headers: const {
              'set-cookie': ['ASP.NET_SessionId=abc; path=/'],
            },
            body: '<input id="pubkey" type="hidden" value=\'$_publicKey\'>',
          );
        case '/home/verificationcode':
          return GmisResponse(
            statusCode: 200,
            headers: const {
              'content-type': ['image/gif'],
            },
            body: '',
            bytes: Uint8List.fromList(const [1, 2, 3]),
          );
        case '/home/stulogin_do':
          return _response(
            '{"jg":"1","url":"/student/default/index"}',
            headers: const {
              'set-cookie': ['__SINDEXCOOKIE__=token; path=/'],
            },
          );
        case '/student/default/index':
          return _response('{}');
        default:
          return _response('{}');
      }
    });
    final client = GmisClient(transport: transport);

    final captcha = await client.fetchCaptcha();
    expect(captcha.imageBytes, const [1, 2, 3]);
    expect(client.cookies['ASP.NET_SessionId'], 'abc');

    final session = await client.login(
      userId: '2026000001',
      password: 'secret',
      captcha: '1234',
    );
    expect(session.userId, '2026000001');
    expect(session.cookies['__SINDEXCOOKIE__'], 'token');

    final post = transport.requests.firstWhere(
      (request) => request.path == '/home/stulogin_do',
    );
    final form = jsonDecode(post.form!['json']!) as Map<String, dynamic>;
    expect(form['UserId'], '2026000001');
    expect(form['VeriCode'], '1234');
    expect(base64Decode(form['Password'] as String).length, 128);
    expect(form['url'], '');
  });

  test(
    'a redirect to the login page is reported as an expired session',
    () async {
      final transport = _FakeTransport(
        (request) => GmisResponse(
          statusCode: 302,
          headers: const {
            'location': ['/home/stulogin?x=1'],
          },
          body: '',
        ),
      );
      final client = GmisClient(transport: transport);
      expect(
        () => client.getJson('/student/default/getxscardinfo'),
        throwsA(isA<GmisSessionExpired>()),
      );
    },
  );

  test('a stale RSA key is reported as an auth error', () async {
    final transport = _FakeTransport(
      (request) =>
          _response('InvalidCipherTextException: block incorrect', status: 500),
    );
    final client = GmisClient(transport: transport);
    expect(
      () => client.getJson('/student/default/getxscardinfo'),
      throwsA(isA<GmisAuthException>()),
    );
  });

  test('list APIs unwrap rows and common envelopes', () async {
    final transport = _FakeTransport((request) {
      if (request.path == '/student/default/bindterm') {
        return _response(
          '{"rows":[{"termcode":"55","termname":"秋季","selected":true}]}',
        );
      }
      return _response('{"data":[{"xm":"测试","xh":"2026000001"}]}');
    });
    final api = GmisApi(GmisClient(transport: transport));
    final terms = await api.terms();
    expect(terms.single['termcode'], '55');
    final card = await api.studentCard();
    expect(card['xm'], '测试');
  });

  test('restoring a session reuses its cookies', () async {
    final transport = _FakeTransport((request) => _response('{}'));
    final client = GmisClient(transport: transport);
    await client.restore(
      AuthSession(
        userId: '2026000001',
        cookies: const {'ASP.NET_SessionId': 'abc'},
        savedAt: DateTime(2026, 11, 6),
      ),
    );
    await client.getJson('/student/default/getxscardinfo');
    expect(
      transport.requests.single.headers['Cookie'],
      'ASP.NET_SessionId=abc',
    );
  });

  test('course catalog pages until the reported total', () async {
    final transport = _FakeTransport((request) {
      if (request.path != '/student/pygl/xswsxk_all') return _response('{}');
      final page = request.form?['page'];
      if (page == '1') {
        return _response('{"total":3,"kc":[{"kcmc":"A"},{"kcmc":"B"}]}');
      }
      return _response('{"total":3,"kc":[{"kcmc":"C"}]}');
    });
    final api = GmisApi(GmisClient(transport: transport));
    final rows = await api.courseCatalogRows(pageSize: 2);
    expect(rows.map((row) => row['kcmc']), ['A', 'B', 'C']);
  });

  test('online exam rows merge current and historical records', () async {
    final transport = _FakeTransport((request) {
      if (request.path == '/student/wsks/wskscp_load') {
        return _response('{"sj1":{"kcmc":"待考"},"sj2":null}');
      }
      if (request.path == '/student/wsks/wskscp_list') {
        return _response('{"rows":[{"kcmc":"已考"}]}');
      }
      return _response('{}');
    });
    final api = GmisApi(GmisClient(transport: transport));
    final rows = await api.onlineExamRows();
    expect(rows.map((row) => row['_kind']), ['current', 'past']);
  });

  test('selection submit sends lb and captcha and reports success', () async {
    final transport = _FakeTransport((request) {
      if (request.path == '/student/pygl/xswsxk_kb_xk') {
        return _response('{}');
      }
      return _response('{}');
    });
    final api = GmisApi(GmisClient(transport: transport));

    final pick = await api.selectCourse(bjid: 'bj-1', captcha: '1234');
    expect(pick.ok, isTrue);
    expect(transport.requests.last.form, {
      'lb': '1',
      'bjid': 'bj-1',
      'xkyzm': '1234',
    });

    final drop = await api.dropCourse(bjid: 'bj-1', captcha: '5678');
    expect(drop.ok, isTrue);
    expect(transport.requests.last.form, {
      'lb': '0',
      'bjid': 'bj-1',
      'xkyzm': '5678',
    });
  });

  test('selection failure is normalised into actionable reasons', () async {
    Future<SelectionResult> submit(String msg) {
      final transport = _FakeTransport(
        (request) => _response(jsonEncode({'msg': msg})),
      );
      return GmisApi(GmisClient(transport: transport))
          .selectCourse(bjid: 'bj-1', captcha: '1234');
    }

    final full = await submit('该课程人数已满');
    expect(full.ok, isFalse);
    expect(full.reason, SelectionFailure.full);
    expect(full.display, contains('满员'));

    expect((await submit('与已选课程时间冲突')).reason, SelectionFailure.conflict);
    expect((await submit('未到选课时间')).reason, SelectionFailure.closed);
    expect((await submit('超过可选门数上限')).reason, SelectionFailure.limit);
    expect((await submit('该课程已选')).reason, SelectionFailure.duplicated);
  });

  test('selection captcha does not reload the login page', () async {
    final transport = _FakeTransport((request) {
      if (request.path == '/home/verificationcode') {
        return GmisResponse(
          statusCode: 200,
          headers: const {
            'content-type': ['image/gif'],
          },
          body: '',
          bytes: Uint8List.fromList(const [9, 9, 9]),
        );
      }
      return _response('{}');
    });
    final api = GmisApi(GmisClient(transport: transport));
    final bytes = await api.selectionCaptcha();
    expect(bytes, const [9, 9, 9]);
    expect(transport.requests.single.path, '/home/verificationcode');
    expect(transport.requests.single.query?['codetype'], 'xkyzm');
  });
}
