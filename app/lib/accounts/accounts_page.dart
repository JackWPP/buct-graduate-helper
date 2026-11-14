import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';
import 'account_models.dart';

/// 本机账号管理：切换、添加、移除。
class AccountsPage extends StatelessWidget {
  const AccountsPage({
    super.key,
    required this.accounts,
    required this.activeId,
    required this.switching,
    required this.onSwitch,
    required this.onAdd,
    required this.onRemove,
  });

  final List<AccountProfile> accounts;
  final String? activeId;
  final bool switching;
  final ValueChanged<AccountProfile> onSwitch;
  final VoidCallback onAdd;
  final Future<void> Function(AccountProfile) onRemove;

  Future<void> _confirmRemove(
    BuildContext context,
    AccountProfile account,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除这个账号？'),
        content: Text(
          '会清除本机保存的 ${account.name.isEmpty ? account.id : account.name} 登录会话、密码、快照和待办。'
          '学校系统里的数据不受影响。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok == true) await onRemove(account);
  }

  @override
  Widget build(BuildContext context) {
    return Subpage(
      title: '账号管理',
      children: [
        const Text(
          '每个账号的登录会话、密码、课表快照和待办分开保存；只有当前账号会在前台监测活动。',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: HuayanColors.faint,
          ),
        ),
        const SizedBox(height: 12),
        for (final account in accounts) ...[
          HuayanCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              key: Key('account-${account.id}'),
              enabled: !switching,
              onTap: account.id == activeId || switching
                  ? null
                  : () => onSwitch(account),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: HuayanColors.blueSoft,
                child: Text(
                  _initial(account),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: HuayanColors.blue,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      account.name.isEmpty ? account.id : account.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (account.id == activeId) ...[
                    const SizedBox(width: 8),
                    const _CurrentBadge(),
                  ],
                ],
              ),
              subtitle: Text(
                [
                  account.id,
                  if (account.college.isNotEmpty) account.college,
                  if (account.major.isNotEmpty) account.major,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                key: Key('account-remove-${account.id}'),
                tooltip: '移除账号',
                onPressed: switching
                    ? null
                    : () => _confirmRemove(context, account),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: HuayanColors.faint,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          key: const Key('account-add'),
          onPressed: switching ? null : onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加账号'),
        ),
        const SizedBox(height: 16),
        const Text(
          '退出当前账号只会清除登录状态，账号资料和待办会保留；移除账号才会清空本机数据。',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: HuayanColors.faint,
          ),
        ),
      ],
    );
  }

  static String _initial(AccountProfile account) {
    final name = account.name.trim();
    if (name.isNotEmpty) return name.characters.first;
    return account.id.isEmpty ? '?' : account.id.characters.first;
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: HuayanColors.blueSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        '当前',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: HuayanColors.blue,
        ),
      ),
    );
  }
}
