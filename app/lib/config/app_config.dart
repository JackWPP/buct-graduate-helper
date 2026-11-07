/// 编译期配置。真实 GMIS 地址和超时集中在这里，避免散落在页面里。
class AppConfig {
  const AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'GMIS_BASE_URL',
    defaultValue: 'https://gmis.buct.edu.cn',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/156.0 Mobile Safari/537.36';
}
