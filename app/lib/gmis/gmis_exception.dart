/// GMIS 通用异常。
class GmisException implements Exception {
  const GmisException(this.message);

  final String message;

  @override
  String toString() => 'GmisException: $message';
}

/// 未登录、登录失败或 RSA 公钥不匹配。
class GmisAuthException extends GmisException {
  const GmisAuthException(super.message);
}

/// 已有会话过期（302 到 /home/stulogin）。
class GmisSessionExpired extends GmisAuthException {
  const GmisSessionExpired() : super('登录态已失效，请重新登录');
}

/// 非 JSON、业务错误或 HTTP 错误。
class GmisApiException extends GmisException {
  const GmisApiException(super.message, {this.statusCode});

  final int? statusCode;
}

/// 网络连接、超时或 TLS 失败。
class GmisNetworkException extends GmisException {
  const GmisNetworkException(super.message);
}

/// 响应结构不符合预期。
class GmisFormatException extends GmisException {
  const GmisFormatException(super.message);
}
