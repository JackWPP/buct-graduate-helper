import 'package:flutter/services.dart';

/// 通过原生 channel 读取/清理 WebView Cookie。
///
/// 网页版 VPN 兜底登录会在 WebView 里拿到 ticket；退出或换账号时必须
/// 清掉，避免下一次打开 WebView 时复用上一个会话。
class WebViewCookies {
  const WebViewCookies._();

  static const _channel = MethodChannel('edu.buct.graduate.huayan/cookies');

  static Future<String?> read(String url) async {
    try {
      return await _channel.invokeMethod<String>('getCookies', {'url': url});
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clearCookies');
    } on MissingPluginException {
      // 桌面/测试环境没有原生 channel，忽略。
    }
  }
}
