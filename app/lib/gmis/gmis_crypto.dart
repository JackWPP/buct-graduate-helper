import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'gmis_exception.dart';

/// 按 GMIS 登录页的 PEM 公钥做 RSA PKCS#1 v1.5 加密。
String encryptGmisPassword(String pem, String password) {
  try {
    final key = _parsePublicKey(pem);
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(key));
    final encrypted = cipher.process(utf8.encode(password));
    return base64Encode(encrypted);
  } on GmisException {
    rethrow;
  } catch (error) {
    throw GmisAuthException('密码加密失败：$error');
  }
}

/// 从登录页 HTML 中取隐藏字段 `#pubkey`。每次登录都要重新获取。
String extractPublicKey(String html) {
  final pattern = RegExp(
    r"""id="pubkey"\s+type="hidden"\s+value='([\s\S]*?)'""",
  );
  final match = pattern.firstMatch(html);
  if (match == null || match.group(1) == null) {
    throw const GmisAuthException('登录页未找到 RSA 公钥，学校登录页可能已更新');
  }
  return match.group(1)!.trim();
}

RSAPublicKey _parsePublicKey(String pem) {
  final base64Text = pem
      .replaceAll(RegExp(r'-----BEGIN [^-]+-----'), '')
      .replaceAll(RegExp(r'-----END [^-]+-----'), '')
      .replaceAll(RegExp(r'\s'), '');
  if (base64Text.isEmpty) {
    throw const GmisAuthException('登录页公钥为空');
  }
  try {
    final der = base64Decode(base64Text);
    final top = ASN1Parser(der).nextObject();
    if (top is! ASN1Sequence) {
      throw const GmisAuthException('登录页公钥格式不正确');
    }
    final spki = ASN1SubjectPublicKeyInfo.fromSequence(top);
    final values = spki.subjectPublicKey.stringValues;
    if (values == null) {
      throw const GmisAuthException('登录页公钥格式不正确');
    }
    final keySeq = ASN1Parser(Uint8List.fromList(values)).nextObject();
    if (keySeq is! ASN1Sequence || keySeq.elements == null) {
      throw const GmisAuthException('登录页公钥格式不正确');
    }
    final modulus = (keySeq.elements![0] as ASN1Integer).integer;
    final exponent = (keySeq.elements![1] as ASN1Integer).integer;
    if (modulus == null || exponent == null) {
      throw const GmisAuthException('登录页公钥格式不正确');
    }
    return RSAPublicKey(modulus, exponent);
  } on GmisException {
    rethrow;
  } catch (error) {
    throw GmisAuthException('登录页公钥解析失败：$error');
  }
}
