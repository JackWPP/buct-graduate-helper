import 'webvpn_credential.dart';
import 'webvpn_url.dart';

/// 运行时的 WebVPN 会话：一个有效格式的 ticket + 门户代理根地址。
///
/// [hasTicket] 只表示“手里有一个 ticket”，不表示门户认它；
/// 是否有效由 `WebVpnValidator` 判断。
class WebVpnSession {
  WebVpnSession({
    required this.credential,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? WebVpnUrls.gmisBase;

  final WebVpnCredential credential;
  final String baseUrl;

  bool get hasTicket => credential.isValid;

  String get ticketName => credential.ticketName;

  String get ticketValue => credential.ticketValue;

  String get cookieHeader => credential.cookieHeader;
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

/// 从 Cookie 头里只提取 ticket，其他 Cookie 丢弃。
WebVpnCredential? credentialFromCookieHeader(
  String? header, {
  String source = WebVpnCredential.sourceWebView,
}) {
  final cookies = parseCookieHeader(header);
  for (final entry in cookies.entries) {
    if (!entry.key.startsWith(webVpnTicketPrefix)) continue;
    final value = entry.value.trim();
    if (value.isEmpty) continue;
    final now = DateTime.now();
    return WebVpnCredential(
      ticketName: entry.key,
      ticketValue: value,
      issuedAt: now,
      lastUsedAt: now,
      source: source,
    );
  }
  return null;
}
