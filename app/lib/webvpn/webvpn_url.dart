import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';

/// 北京化工大学网页版 VPN 的地址编码。
///
/// 学校使用 wengine 的 WebVPN：目标站点的主机名用 AES-128-CFB 加密，
/// token = hex(key) + hex(encrypted(host))，再拼到
/// `https://w.buct.edu.cn/https/<token>/<path>`。
class WebVpnUrls {
  const WebVpnUrls._();

  static const String host = 'w.buct.edu.cn';
  static const String _key = 'wrdvpnisthebest!';
  static const String gmisHost = 'gmis.buct.edu.cn';

  /// 生成目标站点在 WebVPN 中的根地址，末尾带 `/`，可直接作为 Dio baseUrl。
  static String baseForHost(String targetHost) {
    return 'https://$host/https/${tokenForHost(targetHost)}/';
  }

  static String get gmisBase => baseForHost(gmisHost);

  /// 把目标站点的 path 拼到 WebVPN 地址上；path 可以带前导 `/`。
  static String urlForHost(String targetHost, String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '${baseForHost(targetHost)}$clean';
  }

  static String tokenForHost(String targetHost) {
    final key = utf8.encode(_key);
    final encrypted = _aesCfb(utf8.encode(targetHost));
    return _hex(key) + _hex(encrypted);
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
