import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/webvpn/webvpn_session.dart';
import 'package:huayan/webvpn/webvpn_url.dart';

void main() {
  test('WebVPN token matches the wengine AES-CFB vector', () {
    expect(
      WebVpnUrls.tokenForHost('portal.neu.edu.cn'),
      '77726476706e69737468656265737421e0f85388263c265e7b1dc7a99c406d369a',
    );
  });

  test('GMIS WebVPN base URL uses the expected token', () {
    expect(
      WebVpnUrls.gmisBase,
      'https://w.buct.edu.cn/https/'
      '77726476706e69737468656265737421f7fa488f69327d536a468ca88d1b203b/',
    );
    expect(
      WebVpnUrls.urlForHost('gmis.buct.edu.cn', '/home/stulogin'),
      'https://w.buct.edu.cn/https/'
      '77726476706e69737468656265737421f7fa488f69327d536a468ca88d1b203b/home/stulogin',
    );
  });

  test('cookie header parsing keeps WebVPN ticket', () {
    final cookies = parseCookieHeader(
      'wengine_vpn_ticketw_buct_edu_cn=abc; show_vpn=1; refresh=1',
    );
    expect(cookies['wengine_vpn_ticketw_buct_edu_cn'], 'abc');
    expect(cookies['show_vpn'], '1');

    final credential = credentialFromCookieHeader(
      'wengine_vpn_ticketw_buct_edu_cn=abc; show_vpn=1',
    );
    expect(credential, isNotNull);
    expect(credential!.ticketValue, 'abc');
    expect(
      WebVpnSession(credential: credential).hasTicket,
      isTrue,
    );
  });

  test('sidportal token matches the real portal redirect', () {
    expect(
      WebVpnUrls.sidPortalToken,
      '77726476706e69737468656265737421e3fe458c28227c5172468bb99b416d304cb31fd449',
    );
  });

  test('target URL builder handles scheme, port, path and query', () {
    expect(
      WebVpnUrls.urlForTarget(Uri.parse('https://gmis.buct.edu.cn/home/stulogin?x=1')),
      'https://w.buct.edu.cn/https/'
      '77726476706e69737468656265737421f7fa488f69327d536a468ca88d1b203b'
      '/home/stulogin?x=1',
    );
    expect(
      WebVpnUrls.urlForTarget(Uri.parse('http://example.buct.edu.cn:8080/a/b')),
      contains('/http-8080/'),
    );
  });

  test('redirect classifier separates portal, target and external', () {
    final sid = WebVpnUrls.sidPortalToken;
    final gmis = WebVpnUrls.gmisToken;
    expect(
      WebVpnUrls.classifyRedirect(
        Uri.parse('https://w.buct.edu.cn/login'),
        viaWebVpn: true,
      ),
      WebVpnRedirectKind.portalLogin,
    );
    expect(
      WebVpnUrls.classifyRedirect(
        Uri.parse('https://w.buct.edu.cn/https/$sid/login?service=x'),
        viaWebVpn: true,
      ),
      WebVpnRedirectKind.portalLogin,
    );
    expect(
      WebVpnUrls.classifyRedirect(
        Uri.parse('https://w.buct.edu.cn/https/$gmis/home/stulogin'),
        viaWebVpn: true,
      ),
      WebVpnRedirectKind.targetLogin,
    );
    expect(
      WebVpnUrls.classifyRedirect(
        Uri.parse('https://w.buct.edu.cn/https/$gmis/student/default/index'),
        viaWebVpn: true,
      ),
      WebVpnRedirectKind.targetPage,
    );
    expect(
      WebVpnUrls.classifyRedirect(
        Uri.parse('https://evil.example.com/login'),
        viaWebVpn: true,
      ),
      WebVpnRedirectKind.external,
    );
    expect(
      WebVpnUrls.classifyRedirect(
        Uri.parse('/home/stulogin'),
        viaWebVpn: false,
      ),
      WebVpnRedirectKind.targetLogin,
    );
  });
}
