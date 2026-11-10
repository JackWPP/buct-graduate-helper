import 'webvpn_url.dart';

/// 门户票据 Cookie 的固定前缀。不同部署/门户可能带不同 host 后缀，
/// 所以只比较前缀，不假定完整名称。
const webVpnTicketPrefix = 'wengine_vpn_ticket';

/// WebVPN 会话的唯一凭证。
///
/// 只保存门户票据和元数据：不保存学号、密码、短信验证码、SSO Cookie
/// 或目标站点 Cookie。ticketValue 是 bearer token，禁止写日志。
class WebVpnCredential {
  const WebVpnCredential({
    required this.ticketName,
    required this.ticketValue,
    required this.issuedAt,
    required this.lastUsedAt,
    this.portalHost = WebVpnUrls.host,
    this.lastValidatedAt,
    this.source = sourceNativeSso,
  });

  static const sourceNativeSso = 'nativeSso';
  static const sourceWebView = 'webview';
  static const sourceLegacy = 'legacy';

  final String portalHost;
  final String ticketName;
  final String ticketValue;
  final DateTime issuedAt;
  final DateTime lastUsedAt;
  final DateTime? lastValidatedAt;
  final String source;

  bool get isValid =>
      ticketName.startsWith(webVpnTicketPrefix) && ticketValue.isNotEmpty;

  String get cookieHeader => '$ticketName=$ticketValue';

  WebVpnCredential copyWith({
    String? ticketName,
    String? ticketValue,
    DateTime? issuedAt,
    DateTime? lastUsedAt,
    DateTime? lastValidatedAt,
    String? source,
  }) {
    return WebVpnCredential(
      portalHost: portalHost,
      ticketName: ticketName ?? this.ticketName,
      ticketValue: ticketValue ?? this.ticketValue,
      issuedAt: issuedAt ?? this.issuedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'portalHost': portalHost,
    'ticketName': ticketName,
    'ticketValue': ticketValue,
    'issuedAt': issuedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt.toIso8601String(),
    if (lastValidatedAt != null)
      'lastValidatedAt': lastValidatedAt!.toIso8601String(),
    'source': source,
  };

  factory WebVpnCredential.fromJson(Map<String, dynamic> json) {
    DateTime? dateOf(String key) => DateTime.tryParse('${json[key] ?? ''}');
    final now = DateTime.now();
    return WebVpnCredential(
      portalHost: '${json['portalHost'] ?? WebVpnUrls.host}',
      ticketName: '${json['ticketName'] ?? ''}',
      ticketValue: '${json['ticketValue'] ?? ''}',
      issuedAt: dateOf('issuedAt') ?? now,
      lastUsedAt: dateOf('lastUsedAt') ?? now,
      lastValidatedAt: dateOf('lastValidatedAt'),
      source: '${json['source'] ?? sourceNativeSso}',
    );
  }

  /// 兼容旧版本把 ticket 塞在 AuthSession.cookies 里的存储格式。
  static WebVpnCredential? fromLegacySession(Map<String, dynamic> json) {
    final cookies = json['cookies'];
    if (cookies is! Map) return null;
    String? ticketName;
    String? ticketValue;
    for (final entry in cookies.entries) {
      final name = '${entry.key}';
      final value = '${entry.value}'.trim();
      if (name.startsWith(webVpnTicketPrefix) && value.isNotEmpty) {
        ticketName = name;
        ticketValue = value;
        break;
      }
    }
    if (ticketName == null || ticketValue == null) return null;
    final savedAt =
        DateTime.tryParse('${json['savedAt'] ?? ''}') ?? DateTime.now();
    return WebVpnCredential(
      ticketName: ticketName,
      ticketValue: ticketValue,
      issuedAt: savedAt,
      lastUsedAt: savedAt,
      source: sourceLegacy,
    );
  }

  @override
  String toString() =>
      'WebVpnCredential(ticketName: $ticketName, value: <redacted>, '
      'source: $source)';
}
