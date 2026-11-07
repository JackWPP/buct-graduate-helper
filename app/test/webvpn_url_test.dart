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
    expect(
      WebVpnSession(baseUrl: WebVpnUrls.gmisBase, cookies: cookies).hasTicket,
      isTrue,
    );
  });
}
