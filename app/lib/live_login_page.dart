import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_controller.dart';
import 'auth/auth_gateway.dart';
import 'theme.dart';

/// 真实 GMIS 登录页：验证码来自学校接口；密码可选择加密保存在本机，用于下次预填。
class LiveLoginPage extends StatefulWidget {
  const LiveLoginPage({
    super.key,
    required this.controller,
    required this.initialSid,
    this.notice,
    this.onSuccess,
    this.onWebVpnLogin,
    this.allowWebVpn = true,
    this.initialPassword,
    this.fromSso = false,
    this.description,
    this.webVpnLabel = '校外访问：使用网页版 VPN 登录',
  });

  final AppController controller;
  final String initialSid;
  final String? notice;
  final void Function(String sid, bool remember, String? password)? onSuccess;
  final VoidCallback? onWebVpnLogin;
  final bool allowWebVpn;
  final String? initialPassword;
  final bool fromSso;
  final String? description;
  final String webVpnLabel;

  @override
  State<LiveLoginPage> createState() => _LiveLoginPageState();
}

class _LiveLoginPageState extends State<LiveLoginPage> {
  late final TextEditingController _sid = TextEditingController(
    text: widget.initialSid,
  );
  late final _pwd = TextEditingController(text: widget.initialPassword ?? '');
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  var _showPwd = false;
  var _remember = true;
  var _keepPassword = true;
  var _loading = false;
  var _captchaLoading = false;
  var _error = '';

  @override
  void initState() {
    super.initState();
    _error = widget.notice ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCaptcha());
  }

  @override
  void dispose() {
    _codeFocus.dispose();
    _sid.dispose();
    _pwd.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _refreshCaptcha({bool clearError = true}) async {
    if (_captchaLoading) return;
    setState(() {
      _captchaLoading = true;
      if (clearError) _error = '';
    });
    final challenge = await widget.controller.fetchCaptcha();
    if (!mounted) return;
    setState(() {
      _captchaLoading = false;
      if (challenge == null) {
        _error = widget.controller.error ?? '验证码加载失败，请重试';
      }
    });
    _code.clear();
    if (widget.fromSso && _pwd.text.isNotEmpty) {
      _codeFocus.requestFocus();
    }
  }

  Future<void> _submit() async {
    final sid = _sid.text.trim();
    final pwd = _pwd.text;
    if (sid.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请填写学号和密码');
      return;
    }
    final challenge = widget.controller.captcha;
    if (challenge == null) {
      setState(() => _error = '验证码还没加载好，点验证码刷新一下');
      return;
    }
    if (_code.text.trim().isEmpty) {
      setState(() => _error = '请填写验证码');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    final message = await widget.controller.login(
      userId: sid,
      password: pwd,
      captcha: _code.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (message != null) {
      setState(() => _error = message);
      await _refreshCaptcha(clearError: false);
      _codeFocus.requestFocus();
      return;
    }
    _pwd.clear();
    _code.clear();
    widget.onSuccess?.call(sid, _remember, _keepPassword ? pwd : null);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.controller.captcha;
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
                        '化研助手',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: HuayanColors.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '北京化工大学 · 研究生管理系统',
                        style: TextStyle(fontSize: 12, color: HuayanColors.sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.description ??
                  '用学号和教务密码进入。勾选“保持登录”时密码会加密保存在本机，可随时清除。',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: HuayanColors.sub,
              ),
            ),
            if (widget.fromSso) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('live-login-prefill-hint'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: HuayanColors.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '学号、密码已从统一身份认证带入，只需填写验证码。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: HuayanColors.blue,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    key: const Key('live-login-sid'),
                    controller: _sid,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: _inputDecoration('学号'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('live-login-pwd'),
                    controller: _pwd,
                    obscureText: !_showPwd,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('live-login-code'),
                          controller: _code,
                          focusNode: _codeFocus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          onSubmitted: (_) => _loading ? null : _submit(),
                          decoration: _inputDecoration('验证码'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CaptchaBox(
                        challenge: challenge,
                        loading: _captchaLoading,
                        onTap: _refreshCaptcha,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _remember = !_remember),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            key: const Key('live-login-remember'),
                            value: _remember,
                            onChanged: (value) =>
                                setState(() => _remember = value ?? false),
                            activeColor: HuayanColors.blue,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '记住学号',
                          style: TextStyle(
                            fontSize: 13,
                            color: HuayanColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('live-login-forgot'),
                  onPressed: () => _showLegal('forgot'),
                  child: const Text('忘记密码'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _keepPassword = !_keepPassword),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            key: const Key('live-login-keep-password'),
                            value: _keepPassword,
                            onChanged: (value) =>
                                setState(() => _keepPassword = value ?? false),
                            activeColor: HuayanColors.blue,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            '保持登录（加密保存密码，下次只需验证码）',
                            style: TextStyle(
                              fontSize: 13,
                              color: HuayanColors.sub,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error,
                  key: const Key('live-login-error'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: HuayanColors.danger,
                  ),
                ),
              ),
            FilledButton(
              key: const Key('live-login-submit'),
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
            const SizedBox(height: 8),
            if (widget.allowWebVpn && widget.onWebVpnLogin != null)
              TextButton.icon(
                key: const Key('live-login-webvpn'),
                onPressed: widget.onWebVpnLogin,
                icon: const Icon(Icons.public, size: 18),
                label: Text(widget.webVpnLabel),
              ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '登录即表示同意',
                  style: TextStyle(fontSize: 12, color: HuayanColors.faint),
                ),
                TextButton(
                  onPressed: () => _showLegal('terms'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('《服务条款》'),
                ),
                const Text(
                  '与',
                  style: TextStyle(fontSize: 12, color: HuayanColors.faint),
                ),
                TextButton(
                  onPressed: () => _showLegal('privacy'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('《隐私政策》'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '非官方客户端 · 数据来自北京化工大学研究生管理系统',
              style: TextStyle(fontSize: 12, color: HuayanColors.faint),
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

  void _showLegal(String kind) {
    final privacy = kind == 'privacy';
    final forgot = kind == 'forgot';
    final title = forgot ? '忘记密码' : (privacy ? '隐私政策' : '服务条款');
    final body = forgot
        ? '请到学校研究生管理系统的登录页找回或重置密码。开启“保持登录”时密码只加密保存在本机，可在设置中清除。'
        : privacy
        ? '化研助手使用你的学号和教务密码直接登录北京化工大学研究生管理系统。开启“保持登录”时，密码会加密保存在系统安全存储，仅用于下次登录预填；不开启则不保存密码。登录 Cookie、密码和最近一次课表/成绩快照都只留在本机，退出登录可一并清除。'
        : '化研助手不是学校官方客户端。课表、成绩、考试和流程信息以研究生管理系统为准。选课、退选等涉及学籍的操作必须由你本人确认。';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _CaptchaBox extends StatelessWidget {
  const _CaptchaBox({
    required this.challenge,
    required this.loading,
    required this.onTap,
  });

  final CaptchaChallenge? challenge;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = challenge;
    return InkWell(
      key: const Key('live-login-captcha'),
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 112,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HuayanColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HuayanColors.line),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : current == null
            ? const Text(
                '点击刷新',
                style: TextStyle(fontSize: 12, color: HuayanColors.faint),
              )
            : current.imageBytes != null
            ? Image.memory(
                current.imageBytes!,
                width: 104,
                height: 46,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              )
            : Text(
                current.demoCode ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: HuayanColors.ink,
                ),
              ),
      ),
    );
  }
}
