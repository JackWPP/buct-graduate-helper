import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'icons.dart';
import 'snapshot.dart';
import 'theme.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key, required this.onNext, required this.onSkip});

  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('onboarding-skip'),
                  onPressed: onSkip,
                  child: const Text(
                    '跳过',
                    style: TextStyle(color: HuayanColors.faint, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const _MiniTimetable(),
              const SizedBox(height: 28),
              const Text(
                '一学期的课\n一张表看清',
                style: TextStyle(
                  fontSize: 32,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: HuayanColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '课表、选课、成绩、待办，都在一个地方。不用再每天开电脑登网页。',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: HuayanColors.sub,
                ),
              ),
              const Spacer(),
              const _Dots(index: 0),
              const SizedBox(height: 16),
              _PrimaryButton(
                key: const Key('onboarding-next'),
                label: '下一步',
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GuidePage extends StatelessWidget {
  const GuidePage({
    super.key,
    required this.updatedLabel,
    required this.onStart,
    required this.onSkip,
  });

  final String updatedLabel;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  static const _items = [
    (
      tone: Color(0xFFEDF2FF),
      ink: HuayanColors.blue,
      glyph: 'cal',
      title: '课表自动同步',
      text: '打开就能看这份已同步的课表。调课、停课以学校系统为准。',
    ),
    (
      tone: Color(0xFFF3EAFF),
      ink: Color(0xFF7C5CFF),
      glyph: 'check',
      title: '选课少走弯路',
      text: '余量和冲突会先算好。现在不在选课周，这里只放已选结果。',
    ),
    (
      tone: Color(0xFFFFF1E6),
      ink: Color(0xFFF0853A),
      glyph: 'bell',
      title: '截止日不漏',
      text: '评教和流程收在首页。学校没给日期的，不编一个截止日。',
    ),
    (
      tone: Color(0xFFE8F8EF),
      ink: HuayanColors.ok,
      glyph: 'grid',
      title: '低频功能不用再开电脑',
      text: '学校系统里的入口按分类放好，找不到就搜。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final when = updatedLabel.isEmpty ? '已' : '$updatedLabel ';
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('guide-skip'),
                  onPressed: onSkip,
                  child: const Text(
                    '跳过',
                    style: TextStyle(color: HuayanColors.faint, fontSize: 15),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const Text(
                      '登录一次\n剩下的事它帮你盯着',
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: HuayanColors.ink,
                      ),
                    ),
                    const SizedBox(height: 22),
                    for (final item in _items) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: item.tone,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: HuayanIcon(
                              item.glyph,
                              size: 18,
                              color: item.ink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: HuayanColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.text,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: HuayanColors.sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      '数据来自 $when导出的学校快照。预览不保存密码，也不连接学校服务器。',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: HuayanColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const _Dots(index: 1),
              const SizedBox(height: 16),
              _PrimaryButton(
                key: const Key('guide-start'),
                label: '开始使用',
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.snap,
    required this.initialSid,
    required this.onSuccess,
  });

  final Snapshot snap;
  final String initialSid;
  final void Function(String sid, bool remember) onSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _sid = TextEditingController(
    text: widget.initialSid,
  );
  final _pwd = TextEditingController();
  final _code = TextEditingController();
  final _random = Random();
  var _captcha = '';
  var _showPwd = false;
  var _remember = true;
  var _error = '';
  var _fails = 0;

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
  }

  @override
  void dispose() {
    _sid.dispose();
    _pwd.dispose();
    _code.dispose();
    super.dispose();
  }

  void _refreshCaptcha() {
    _captcha = List.generate(4, (_) => _random.nextInt(10)).join();
  }

  void _submit() {
    final sid = _sid.text.trim();
    final pwd = _pwd.text;
    if (sid.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请填写学号和密码');
      return;
    }
    if (_code.text.trim() != _captcha) {
      _fails += 1;
      _code.clear();
      setState(() {
        _refreshCaptcha();
        _error = _fails >= 3 ? '验证码错误。请核对学号和密码，不会锁定账号。' : '验证码错误';
      });
      return;
    }
    final demo = widget.snap.loginStudentId;
    if (sid != demo) {
      _fails += 1;
      _code.clear();
      setState(() {
        _refreshCaptcha();
        _error = '演示快照只有学号 $demo 的数据';
      });
      return;
    }
    _pwd.clear();
    _code.clear();
    _error = '';
    _fails = 0;
    widget.onSuccess(sid, _remember);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.snap.updatedLabel;
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
            const Text(
              '用学号和教务密码进入。这份预览读的是已导出的快照，密码不会保存。',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: HuayanColors.sub,
              ),
            ),
            const SizedBox(height: 18),
            _Field(
              key: const Key('login-sid'),
              controller: _sid,
              hint: '学号',
              keyboard: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _Field(
              key: const Key('login-pwd'),
              controller: _pwd,
              hint: '密码',
              obscure: !_showPwd,
              trailing: IconButton(
                onPressed: () => setState(() => _showPwd = !_showPwd),
                tooltip: _showPwd ? '隐藏密码' : '显示密码',
                icon: HuayanIcon(
                  _showPwd ? 'eyeoff' : 'eye',
                  size: 20,
                  color: HuayanColors.faint,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    key: const Key('login-code'),
                    controller: _code,
                    hint: '验证码（4 位数字）',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                _CaptchaButton(
                  code: _captcha,
                  onTap: () => setState(() {
                    _refreshCaptcha();
                    _code.clear();
                  }),
                ),
              ],
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
                            key: const Key('login-remember'),
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
                  key: const Key('login-forgot'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('请到学校研究生系统找回密码。这里不保存密码。'),
                        duration: Duration(milliseconds: 900),
                      ),
                    );
                  },
                  child: const Text('忘记密码'),
                ),
              ],
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error,
                  key: const Key('login-error'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: HuayanColors.danger,
                  ),
                ),
              ),
            _PrimaryButton(
              key: const Key('login-submit'),
              label: '登录',
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '登录即表示同意',
                  style: TextStyle(fontSize: 12, color: HuayanColors.faint),
                ),
                _LegalLink(label: '《服务条款》', kind: 'terms', snap: widget.snap),
                const Text(
                  '与',
                  style: TextStyle(fontSize: 12, color: HuayanColors.faint),
                ),
                _LegalLink(label: '《隐私政策》', kind: 'privacy', snap: widget.snap),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '非官方客户端 · 数据来自 ${label.isEmpty ? '已导出' : label} 的学校快照',
              style: const TextStyle(fontSize: 12, color: HuayanColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.kind, required this.snap});

  final String kind;
  final Snapshot snap;

  @override
  Widget build(BuildContext context) {
    final privacy = kind == 'privacy';
    final title = privacy ? '隐私政策' : '服务条款';
    final body = privacy
        ? '这个预览只在你的浏览器里使用一份已经导出的学业快照，用来显示课表、学分和流程状态。它不把密码发到任何服务器，也不保存密码。证件号、电话和住址被排除在快照之外。你可以在设置里清掉本机偏好，或退出登录。'
        : '化研助手不是学校官方客户端。课表、成绩和流程以研究生管理系统为准。不要用它自动抢课、代选或批量尝试。选课、退选在正式版本里也必须由你本人确认。';
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    key: const Key('nav-back'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '返回',
                    icon: const HuayanIcon(
                      'back',
                      size: 18,
                      color: HuayanColors.ink,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HuayanColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: HuayanColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: HuayanColors.lineSoft),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: HuayanColors.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '更新于 ${snap.updatedLabel}。正式上架前需要换成完整文本。',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: HuayanColors.faint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.kind,
    required this.snap,
  });

  final String label;
  final String kind;
  final Snapshot snap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context)
            .push(huayanRoute<void>(LegalPage(kind: kind, snap: snap)));
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _CaptchaButton extends StatelessWidget {
  const _CaptchaButton({required this.code, required this.onTap});

  final String code;
  final VoidCallback onTap;

  static const _turns = [-8, 6, -4, 7];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F5F8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('captcha-refresh'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          key: const Key('captcha'),
          width: 108,
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < code.length; i++)
                Transform.rotate(
                  angle: _turns[i] * pi / 180,
                  child: Text(
                    code[i],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: i.isEven ? HuayanColors.ink : HuayanColors.blue,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: const [],
      style: const TextStyle(fontSize: 16, color: HuayanColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: HuayanColors.placeholder),
        filled: true,
        fillColor: HuayanColors.card,
        suffixIcon: trailing,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: HuayanColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: HuayanColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: HuayanColors.blue, width: 1.4),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: HuayanColors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? HuayanColors.blue : const Color(0xFFD7DDE8),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniTimetable extends StatelessWidget {
  const _MiniTimetable();

  static const _cells = [
    Color(0xFFE7EEFF),
    Color(0xFFF4F6F9),
    Color(0xFFF3EAFF),
    Color(0xFFF4F6F9),
    Color(0xFFFFF1E8),
    Color(0xFFF4F6F9),
    Color(0xFFF4F6F9),
    Color(0xFFE8F8EF),
    Color(0xFFF4F6F9),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE7EBF3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A14171F),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            const Row(
              children: [
                _Dot(Color(0xFFD5DBE6)),
                SizedBox(width: 6),
                _Dot(Color(0xFFD5DBE6)),
                SizedBox(width: 6),
                _Dot(Color(0xFFD5DBE6)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 164,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1F6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        GridView.count(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final color in _cells)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFEEF1F5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Positioned(right: 0, top: 78, child: _Pin()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 34, height: 2, color: HuayanColors.blue),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: HuayanColors.blue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: HuayanColors.blue.withValues(alpha: 0.14),
                spreadRadius: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
