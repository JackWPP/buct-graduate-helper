import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

/// 添加账号第一步：输入学号。后续由 LiveShell 复用 SSO/GMIS 登录页完成认证。
class AddAccountPage extends StatefulWidget {
  const AddAccountPage({
    super.key,
    required this.existingIds,
    required this.onContinue,
  });

  final Set<String> existingIds;
  final Future<void> Function(String sid) onContinue;

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final _sid = TextEditingController();
  var _loading = false;
  var _error = '';

  @override
  void dispose() {
    _sid.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sid = _sid.text.trim();
    if (sid.isEmpty) {
      setState(() => _error = '请输入学号');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await widget.onContinue(sid);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '添加账号失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _sid.text.trim();
    return Subpage(
      title: '添加账号',
      children: [
        const Text(
          '新账号会独立保存登录会话、密码、课表快照和待办，不会影响当前账号。',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: HuayanColors.faint,
          ),
        ),
        const SizedBox(height: 16),
        HuayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '学号',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HuayanColors.sub,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('add-account-sid'),
                controller: _sid,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _error = ''),
                onSubmitted: (_) => _loading ? null : _submit(),
                decoration: InputDecoration(
                  hintText: '输入要添加的学号',
                  errorText: _error.isEmpty ? null : _error,
                ),
              ),
              if (widget.existingIds.contains(existing)) ...[
                const SizedBox(height: 8),
                const Text(
                  '这个账号已经保存在本机，继续会直接切换过去。',
                  style: TextStyle(fontSize: 12, color: HuayanColors.amberInk),
                ),
              ],
            ],
          ),
        ),
        FilledButton(
          key: const Key('add-account-continue'),
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
              : const Text('继续登录'),
        ),
        const SizedBox(height: 14),
        const Text(
          '需要统一身份认证和研究生管理系统验证码；登录成功后才写入账号列表。',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: HuayanColors.faint,
          ),
        ),
      ],
    );
  }
}
