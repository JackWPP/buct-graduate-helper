/// 网页版 VPN 登录得到的 Cookie 和代理根地址。
class WebVpnSession {
  const WebVpnSession({required this.baseUrl, required this.cookies});

  final String baseUrl;
  final Map<String, String> cookies;

  bool get hasTicket =>
      cookies.keys.any((name) => name.startsWith('wengine_vpn_ticket'));
}

/// Android CookieManager 返回的是 `a=1; b=2` 形式，解析成 Map。
Map<String, String> parseCookieHeader(String? header) {
  final result = <String, String>{};
  if (header == null || header.trim().isEmpty) return result;
  for (final part in header.split(';')) {
    final item = part.trim();
    final index = item.indexOf('=');
    if (index <= 0) continue;
    final name = item.substring(0, index).trim();
    if (name.isEmpty) continue;
    result[name] = item.substring(index + 1).trim();
  }
  return result;
}
