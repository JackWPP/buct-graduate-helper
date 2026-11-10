import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';

/// 一次 302 的目标分类。
enum WebVpnRedirectKind { portalLogin, targetLogin, targetPage, external }

/// 北京化工大学网页版 VPN 的地址编码与跳转分类。
///
/// 学校使用 wengine 的 WebVPN：目标站点的主机名用 AES-128-CFB 加密，
/// token = hex(key) + hex(encrypted(host))，再拼到
/// `https://w.buct.edu.cn/https/<token>/<path>`。
class WebVpnUrls {
  const WebVpnUrls._();

  static const String host = 'w.buct.edu.cn';
  static const String gmisHost = 'gmis.buct.edu.cn';
  static const String sidPortalHost = 'sidportal.buct.edu.cn';
  static const String _key = 'wrdvpnisthebest!';

  /// 生成目标站点在 WebVPN 中的根地址，末尾带 `/`，可直接作为 Dio baseUrl。
  static String baseForHost(String targetHost) {
    return 'https://$host/https/${tokenForHost(targetHost)}/';
  }

  static String get gmisBase => baseForHost(gmisHost);

  static String get gmisToken => tokenForHost(gmisHost);

  /// 统一身份认证门户在 WebVPN 里的 token。真实门户会 302 到
  /// `/https/<sidportal-token>/login?...`，用它和普通目标 `/home/login` 区分。
  static String get sidPortalToken => tokenForHost(sidPortalHost);

  /// 把目标站点的 path 拼到 WebVPN 地址上；path 可以带前导 `/`。
  static String urlForHost(String targetHost, String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '${baseForHost(targetHost)}$clean';
  }

  /// 通用目标 URL 编码，支持 http/https 和端口前缀（http-8080 等）。
  static String urlForTarget(Uri target) {
    if (target.host.isEmpty) {
      throw ArgumentError.value(target, 'target', 'host is required');
    }
    final scheme = target.scheme.isEmpty ? 'https' : target.scheme.toLowerCase();
    final protocol = _protocolFor(scheme, target.hasPort ? target.port : null);
    final path = target.path.isEmpty ? '/' : target.path;
    final query = target.hasQuery ? '?${target.query}' : '';
    return 'https://$host/$protocol/${tokenForHost(target.host)}$path$query';
  }

  static String _protocolFor(String scheme, int? port) {
    if (scheme == 'http') {
      if (port == null || port == 80) return 'http';
      return 'http-$port';
    }
    if (scheme == 'https') {
      if (port == null || port == 443) return 'https';
      return 'https-$port';
    }
    return scheme;
  }

  /// 目标 host 的确定性 token。
  ///
  /// 算法：UTF-8(host) 用 AES-128-CFB（key = iv = "wrdvpnisthebest!"）
  /// 加密，token = hex(iv) + hex(cipher)。调用方不要把它当权限凭证。
  static String tokenForHost(String targetHost) {
    if (targetHost.isEmpty) {
      throw ArgumentError.value(targetHost, 'targetHost', 'host is required');
    }
    final host = targetHost.toLowerCase();
    final key = utf8.encode(_key);
    final encrypted = _aesCfb(utf8.encode(host));
    return _hex(key) + _hex(encrypted);
  }

  /// 区分门户登录、目标站点登录、普通目标跳转和外部跳转。
  ///
  /// [viaWebVpn] 为 false 时只识别校内直连的目标登录路径。
  static WebVpnRedirectKind classifyRedirect(
    Uri location, {
    required bool viaWebVpn,
  }) {
    final targetHost = location.host.toLowerCase();
    final path = location.path;

    if (viaWebVpn) {
      if (targetHost.isNotEmpty &&
          targetHost != host &&
          targetHost != sidPortalHost) {
        return WebVpnRedirectKind.external;
      }
      if (_isPortalLogin(targetHost, path)) {
        return WebVpnRedirectKind.portalLogin;
      }
      if (_isGmisLogin(path)) {
        return WebVpnRedirectKind.targetLogin;
      }
      return WebVpnRedirectKind.targetPage;
    }

    if (_isDirectLogin(path)) {
      return WebVpnRedirectKind.targetLogin;
    }
    return WebVpnRedirectKind.targetPage;
  }

  static bool _isPortalLogin(String targetHost, String path) {
    if (targetHost == host || targetHost.isEmpty) {
      if (path == '/login' || path.startsWith('/login/')) return true;
    }
    if (targetHost == sidPortalHost &&
        (path == '/login' || path.startsWith('/login/'))) {
      return true;
    }
    final wrapped = '/https/$sidPortalToken/login';
    return path == wrapped || path.startsWith('$wrapped/');
  }

  static bool _isGmisLogin(String path) {
    final wrapped = '/https/$gmisToken';
    for (final loginPath in const ['/home/stulogin', '/home/login']) {
      if (path == loginPath || path.startsWith('$loginPath/')) return true;
      final proxied = '$wrapped$loginPath';
      if (path == proxied || path.startsWith('$proxied/')) return true;
    }
    return false;
  }

  static bool _isDirectLogin(String path) {
    return path == '/home/stulogin' ||
        path.startsWith('/home/stulogin/') ||
        path == '/home/login' ||
        path.startsWith('/home/login/');
  }

  static Uint8List _aesCfb(List<int> input) {
    final key = Uint8List.fromList(utf8.encode(_key));
    final bytes = Uint8List.fromList(input);
    final engine = AESEngine()..init(true, KeyParameter(key));
    final output = Uint8List(bytes.length);
    var iv = Uint8List.fromList(key);
    for (var offset = 0; offset < bytes.length; offset += 16) {
      final keystream = Uint8List(16);
      engine.processBlock(iv, 0, keystream, 0);
      final count = min(16, bytes.length - offset);
      for (var i = 0; i < count; i++) {
        output[offset + i] = keystream[i] ^ bytes[offset + i];
      }
      if (count == 16) {
        iv = Uint8List.fromList(output.sublist(offset, offset + 16));
      }
    }
    return output;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
