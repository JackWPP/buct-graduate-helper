import '../gmis/gmis_exception.dart';
import '../gmis/gmis_transport.dart';
import 'webvpn_credential.dart';
import 'webvpn_url.dart';

/// WebVPN 会话状态。
enum WebVpnState { unknown, valid, expired, offline }

class WebVpnValidation {
  const WebVpnValidation(
    this.state, {
    this.statusCode,
    this.detail,
  });

  final WebVpnState state;
  final int? statusCode;
  final String? detail;
}

abstract interface class WebVpnValidator {
  Future<WebVpnValidation> validate(WebVpnCredential credential);
}

/// 用受保护的目标页面探测 ticket 是否仍被门户认可。
///
/// 不跟随 302：门户过期时 Location 会回到 `/login` 或
/// `/https/<sidportal-token>/login?service=...`；ticket 有效时回到目标页面。
class HttpWebVpnValidator implements WebVpnValidator {
  HttpWebVpnValidator({
    GmisTransport? transport,
    String? probePath,
  }) : _transport =
           transport ??
           DioGmisTransport(
             baseUrl: 'https://${WebVpnUrls.host}',
             connectTimeout: const Duration(seconds: 8),
             receiveTimeout: const Duration(seconds: 8),
           ),
       _probePath =
           probePath ?? '/https/${WebVpnUrls.gmisToken}/home/stulogin';

  final GmisTransport _transport;
  final String _probePath;

  @override
  Future<WebVpnValidation> validate(WebVpnCredential credential) async {
    try {
      final response = await _transport.send(
        GmisRequest(
          method: 'GET',
          path: _probePath,
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Cookie': credential.cookieHeader,
          },
          followRedirects: false,
        ),
      );
      return _classify(response);
    } on GmisNetworkException {
      return const WebVpnValidation(WebVpnState.offline);
    } on GmisException {
      return const WebVpnValidation(WebVpnState.unknown);
    } catch (_) {
      return const WebVpnValidation(WebVpnState.unknown);
    }
  }

  WebVpnValidation _classify(GmisResponse response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      // 某些部署可能不跳转、直接返回 SSO 页面；页面本身不是有效目标页。
      if (response.body.contains('统一身份认证平台')) {
        return WebVpnValidation(
          WebVpnState.expired,
          statusCode: status,
          detail: 'portal-login-page',
        );
      }
      return WebVpnValidation(WebVpnState.valid, statusCode: status);
    }
    if (status >= 300 && status < 400) {
      final raw = response.header('location');
      if (raw == null || raw.isEmpty) {
        return WebVpnValidation(
          WebVpnState.unknown,
          statusCode: status,
          detail: 'redirect-without-location',
        );
      }
      final base = Uri.parse('https://${WebVpnUrls.host}$_probePath');
      final location = base.resolve(raw);
      final kind = WebVpnUrls.classifyRedirect(location, viaWebVpn: true);
      return switch (kind) {
        WebVpnRedirectKind.portalLogin => WebVpnValidation(
          WebVpnState.expired,
          statusCode: status,
          detail: 'portal-login',
        ),
        WebVpnRedirectKind.targetLogin ||
        WebVpnRedirectKind.targetPage => WebVpnValidation(
          WebVpnState.valid,
          statusCode: status,
          detail: 'target-redirect',
        ),
        WebVpnRedirectKind.external => WebVpnValidation(
          WebVpnState.unknown,
          statusCode: status,
          detail: 'external-redirect',
        ),
      };
    }
    return WebVpnValidation(
      WebVpnState.unknown,
      statusCode: status,
      detail: 'http-$status',
    );
  }
}
