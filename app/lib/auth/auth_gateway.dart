import 'dart:math';
import 'dart:typed_data';

import '../gmis/gmis_exception.dart';

/// 登录验证码。真实模式提供 GIF/PNG 字节，演示模式提供本地四位数字。
class CaptchaChallenge {
  const CaptchaChallenge({this.imageBytes, this.demoCode});

  final Uint8List? imageBytes;
  final String? demoCode;

  bool get isDemo => demoCode != null;
}

/// 登录成功后的最小会话：只保存 Cookie 和学号，绝不保存密码。
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.cookies,
    required this.savedAt,
  });

  final String userId;
  final Map<String, String> cookies;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'cookies': cookies,
    'savedAt': savedAt.toIso8601String(),
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: '${json['userId'] ?? ''}',
      cookies: (json['cookies'] as Map? ?? const {}).map(
        (key, value) => MapEntry('$key', '$value'),
      ),
      savedAt: DateTime.tryParse('${json['savedAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}

abstract interface class AuthGateway {
  Future<CaptchaChallenge> fetchCaptcha();

  Future<AuthSession> login({
    required String userId,
    required String password,
    required String captcha,
  });

  Future<void> restore(AuthSession session);

  Future<void> logout();
}

/// 演示模式：账号必须是快照里的演示学号，验证码是本地随机四位数字。
/// 这个网关只用于截图和 UI 测试，不接触任何真实学校接口。
class DemoAuthGateway implements AuthGateway {
  DemoAuthGateway({required this.demoStudentId});

  final String demoStudentId;
  final Random _random = Random.secure();
  String _code = '';

  @override
  Future<CaptchaChallenge> fetchCaptcha() async {
    _code = '${1000 + _random.nextInt(9000)}';
    return CaptchaChallenge(demoCode: _code);
  }

  @override
  Future<AuthSession> login({
    required String userId,
    required String password,
    required String captcha,
  }) async {
    if (userId.trim() != demoStudentId) {
      throw GmisAuthException('演示快照只有学号 $demoStudentId 的数据');
    }
    if (password.isEmpty) throw const GmisAuthException('请填写学号和密码');
    if (captcha != _code) throw const GmisAuthException('验证码错误');
    return AuthSession(
      userId: userId.trim(),
      cookies: const {},
      savedAt: DateTime.now(),
    );
  }

  @override
  Future<void> restore(AuthSession session) async {}

  @override
  Future<void> logout() async {}
}
