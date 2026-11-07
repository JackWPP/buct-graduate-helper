import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../gmis/gmis_exception.dart';
import '../theme.dart';
import 'webvpn_auth_client.dart';
import 'webvpn_session.dart';

/// 原生统一身份认证页。
///
/// 学校网页版 VPN 后面的 SSO 与普通网页表单一致：GET 页面拿 croypto 和
/// flowkey，密码用页面给的 AES key 加密后 POST。这里不打开 WebView。
class SsoLoginPage extends StatefulWidget {
  const SsoLoginPage({
    super.key,
    required this.onSuccess,
    this.onDirect,
    this.onUserId,
    this.initialSid = '',
    this.notice,
    this.client,
  });

  final ValueChanged<WebVpnSession> onSuccess;
  final VoidCallback? onDirect;
  final ValueChanged<String>? onUserId;
  final String initialSid;
  final String? notice;
  final WebVpnAuthClient? client;

  @override
  State<SsoLoginPage> createState() => _SsoLoginPageState();
}

class _SsoLoginPageState extends State<SsoLoginPage> {
  late final TextEditingController _sid = TextEditingController(
    text: widget.initialSid,
  );
  final _pwd = TextEditingController();
  final _code = TextEditingController();
  late final WebVpnAuthClient _client = widget.client ?? WebVpnAuthClient();
  var _showPwd = false;
  var _loading = false;
  var _sendingCode = false;
  var _error = '';
  var _info = '';
  WebVpnSmsChallenge? _challenge;

  @override
  void initState() {
    super.initState();
    _error = widget.notice ?? '';
  }

  @override
  void dispose() {
    _sid.dispose();
    _pwd.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_challenge != null) {
      await _verifySms();
      return;
    }
    final sid = _sid.text.trim();
    final pwd = _pwd.text;
    if (sid.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请填写学号和密码');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _info = '';
    });
    try {
      final result = await _client.login(userId: sid, password: pwd);
      if (!mounted) return;
      _pwd.clear();
      widget.onUserId?.call(sid);
      if (result.needsSms) {
        setState(() {
          _loading = false;
          _challenge = result.challenge;
          _info = '密码验证通过，请输入短信验证码。';
        });
        return;
      }
      final session = result.session;
      if (session == null) {
        throw const GmisFormatException('统一身份认证没有返回会话');
      }
      setState(() => _loading = false);
      widget.onSuccess(session);
    } on GmisException catch (error) {
      if (!mounted) return;
      _pwd.clear();
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      _pwd.clear();
      setState(() {
        _loading = false;
        _error = '统一身份认证失败，请稍后重试';
      });
    }
  }

  Future<void> _sendCode() async {
    if (_challenge == null || _sendingCode) return;
    setState(() {
      _sendingCode = true;
      _error = '';
      _info = '';
    });
    try {
      await _client.sendSmsCode();
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _info = '验证码已发送，请查看手机短信。';
      });
    } on GmisException catch (error) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = '验证码发送失败，请稍后重试';
      });
    }
  }

  Future<void> _verifySms() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '请输入短信验证码');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _info = '';
    });
    try {
      final session = await _client.verifySmsCode(code);
      if (!mounted) return;
      _code.clear();
      setState(() => _loading = false);
      widget.onSuccess(session);
    } on GmisException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '短信验证失败，请稍后重试';
      });
    }
  }

  void _backToPassword() {
    setState(() {
      _challenge = null;
      _code.clear();
      _error = '';
      _info = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SvgPicture.asset(
                    'assets/brand.svg',
                    width: 56,
                    height: 56,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '网页版 VPN',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: HuayanColors.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '北京化工大学 · 统一身份认证',
                        style: TextStyle(fontSize: 12, color: HuayanColors.sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              '默认通过学校网页版 VPN 访问研究生管理系统。统一身份认证在这里直接完成，不打开网页。',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: HuayanColors.sub,
              ),
            ),
            const SizedBox(height: 18),
            if (_challenge == null) ...[
              TextField(
                key: const Key('sso-sid'),
                controller: _sid,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration('学号'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('sso-pwd'),
                controller: _pwd,
                obscureText: !_showPwd,
                onSubmitted: (_) => _loading ? null : _submit(),
                decoration: _inputDecoration('密码').copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showPwd = !_showPwd),
                    tooltip: _showPwd ? '隐藏密码' : '显示密码',
                    icon: Icon(
                      _showPwd ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: HuayanColors.faint,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HuayanColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HuayanColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '二次身份验证',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: HuayanColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '这一额外步骤可证明是您本人在尝试登录。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: HuayanColors.sub,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已绑定手机号：${_challenge!.maskedPhone}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: HuayanColors.sub,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('sso-sms-code'),
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loading ? null : _verifySms(),
                      decoration: _inputDecoration('请输入验证码').copyWith(
                        counterText: '',
                        suffixIcon: TextButton(
                          key: const Key('sso-sms-send'),
                          onPressed: _sendingCode ? null : _sendCode,
                          child: Text(_sendingCode ? '发送中…' : '获取验证码'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_info.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _info,
                  key: const Key('sso-info'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: HuayanColors.blue,
                  ),
                ),
              ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error,
                  key: const Key('sso-error'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: HuayanColors.danger,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            FilledButton(
              key: Key(_challenge == null ? 'sso-submit' : 'sso-sms-submit'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_challenge == null ? '登录' : '验证并登录'),
            ),
            if (_challenge != null) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  key: const Key('sso-sms-back'),
                  onPressed: _loading ? null : _backToPassword,
                  child: const Text('返回修改学号密码'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_challenge == null && widget.onDirect != null)
              Center(
                child: TextButton(
                  key: const Key('sso-direct'),
                  onPressed: _loading ? null : widget.onDirect,
                  child: const Text('校内直连（不使用网页版 VPN）'),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              '统一身份认证只用于换取网页版 VPN 凭证。密码不会被保存，也不会写入日志。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: HuayanColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: HuayanColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HuayanColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HuayanColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HuayanColors.blue),
      ),
    );
  }
}
