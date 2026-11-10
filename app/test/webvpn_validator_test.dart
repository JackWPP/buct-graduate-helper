import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/gmis/gmis_exception.dart';
import 'package:huayan/gmis/gmis_transport.dart';
import 'package:huayan/webvpn/webvpn_credential.dart';
import 'package:huayan/webvpn/webvpn_url.dart';
import 'package:huayan/webvpn/webvpn_validator.dart';

class _FakeTransport implements GmisTransport {
  _FakeTransport(this.response);

  final GmisResponse Function(GmisRequest request) response;
  final requests = <GmisRequest>[];

  @override
  Future<GmisResponse> send(GmisRequest request) async {
    requests.add(request);
    return response(request);
  }
}

GmisResponse _response(
  int status, {
  String body = '',
  Map<String, List<String>> headers = const {},
}) {
  return GmisResponse(statusCode: status, headers: headers, body: body);
}

void main() {
  final credential = WebVpnCredential(
    ticketName: 'wengine_vpn_ticketw_buct_edu_cn',
    ticketValue: 'opaque-ticket',
    issuedAt: DateTime(2026, 11, 10),
    lastUsedAt: DateTime(2026, 11, 10),
  );

  WebVpnValidator validatorWith(GmisResponse response) {
    return HttpWebVpnValidator(
      transport: _FakeTransport((_) => response),
    );
  }

  test('200 from the target page means the ticket is valid', () async {
    final result = await validatorWith(
      _response(200, body: '<input id="pubkey" />'),
    ).validate(credential);
    expect(result.state, WebVpnState.valid);
  });

  test('302 to the portal login means the ticket expired', () async {
    final result = await validatorWith(
      _response(
        302,
        headers: {
          'location': ['https://w.buct.edu.cn/login'],
        },
      ),
    ).validate(credential);
    expect(result.state, WebVpnState.expired);
  });

  test('302 to the wrapped sidportal login means expired', () async {
    final result = await validatorWith(
      _response(
        302,
        headers: {
          'location': [
            'https://w.buct.edu.cn/https/${WebVpnUrls.sidPortalToken}/login?service=x',
          ],
        },
      ),
    ).validate(credential);
    expect(result.state, WebVpnState.expired);
  });

  test('302 to the target login means ticket valid, GMIS signed out', () async {
    final result = await validatorWith(
      _response(
        302,
        headers: {
          'location': [
            'https://w.buct.edu.cn/https/${WebVpnUrls.gmisToken}/home/stulogin',
          ],
        },
      ),
    ).validate(credential);
    expect(result.state, WebVpnState.valid);
  });

  test('network error keeps unknown/offline instead of clearing', () async {
    final validator = HttpWebVpnValidator(
      transport: _FakeTransport((_) => throw const GmisNetworkException('down')),
    );
    final result = await validator.validate(credential);
    expect(result.state, WebVpnState.offline);
  });

  test('200 without a target-page marker is not valid', () async {
    final result = await validatorWith(
      _response(200, body: '登录已过期'),
    ).validate(credential);
    expect(result.state, WebVpnState.expired);
  });

  test('http 500 is unknown, not expired', () async {
    final result = await validatorWith(_response(500)).validate(credential);
    expect(result.state, WebVpnState.unknown);
  });

  test('request carries only the ticket cookie and no follow', () async {
    final transport = _FakeTransport((_) => _response(200));
    final validator = HttpWebVpnValidator(transport: transport);
    await validator.validate(credential);

    final request = transport.requests.single;
    expect(request.followRedirects, isFalse);
    expect(request.headers['Cookie'], credential.cookieHeader);
    expect(request.path, contains(WebVpnUrls.gmisToken));
  });
}
