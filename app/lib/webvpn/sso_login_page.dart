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
    this.initialSid = '',
    this.notice,
    this.client,
  });

  final ValueChanged<WebVpnSession> onSuccess;
  final VoidCallback? onDirect;
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
  late final WebVpnAuthClient _client = widget.client ?? WebVpnAuthClient();
  var _showPwd = false;
  var _loading = false;
  var _error = '';

  @override
  void initState() {
    super.initState();
    _error = widget.notice ?? '';
  }

  @override
  void dispose() {
    _sid.dispose();
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sid = _sid.text.trim();
    final pwd = _pwd.text;
    if (sid.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请填写学号和密码');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final session = await _client.login(userId: sid, password: pwd);
      if (!mounted) return;
      _pwd.clear();
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
              key: const Key('sso-submit'),
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
                  : const Text('登录'),
            ),
            const SizedBox(height: 12),
            if (widget.onDirect != null)
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
