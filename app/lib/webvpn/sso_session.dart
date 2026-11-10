/// 统一身份认证的长期会话（TGC / SESSION Cookie）。
///
/// 只保存 `sidportal.buct.edu.cn` 的 Cookie，用于在 WebVPN ticket 失效时
/// 静默换一张新 ticket。它等价于“保持登录”凭据，只能放系统安全存储，
/// [toString] 不输出任何 Cookie 值。
class SsoSession {
  const SsoSession({required this.cookies, required this.savedAt});

  static const int version = 1;

  final Map<String, String> cookies;
  final DateTime savedAt;

  bool get isUsable => cookies.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'version': version,
    'cookies': cookies,
    'savedAt': savedAt.toIso8601String(),
  };

  static SsoSession? fromJson(Map<String, dynamic> json) {
    final raw = json['cookies'];
    if (raw is! Map) return null;
    final cookies = <String, String>{};
    for (final entry in raw.entries) {
      final name = '${entry.key}'.trim();
      final value = '${entry.value}'.trim();
      if (name.isEmpty || value.isEmpty) continue;
      cookies[name] = value;
    }
    if (cookies.isEmpty) return null;
    final savedAt = DateTime.tryParse('${json['savedAt'] ?? ''}');
    return SsoSession(cookies: cookies, savedAt: savedAt ?? DateTime.now());
  }

  @override
  String toString() =>
      'SsoSession(cookies: ${cookies.length}, savedAt: $savedAt)';
}
