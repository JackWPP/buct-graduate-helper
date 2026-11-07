import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'gmis/gmis_api.dart';
import 'gmis/gmis_exception.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'ui/feedback.dart';
import 'widgets.dart';

/// 选课页。
///
/// 数据来自 `xswsxk_kb_list`（当前选课窗口优先），提交走 `xswsxk_kb_xk`。
/// 设计稿的三条硬规则在这里落地：提交前二次确认、每次提交都要输入
/// 选课验证码、失败原因归一化成可操作提示。
class SelectionPage extends StatefulWidget {
  const SelectionPage({
    super.key,
    required this.api,
    required this.snap,
    this.onChanged,
    this.onSessionExpired,
  });

  final GmisApi api;
  final Snapshot snap;

  /// 提交成功后回调，让外层刷新快照（课表、学分跟着变）。
  final Future<void> Function()? onChanged;
  final VoidCallback? onSessionExpired;

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  final _query = TextEditingController();

  List<Map<String, dynamic>> _courses = const [];
  Set<String> _myBjids = {};
  bool _loading = true;
  bool _windowClosed = false;
  String _lb = '3';
  String _xwk = '';
  String _zh = '';
  String? _yxsh;
  String? _error;
  String? _pendingBjid;

  @override
  void initState() {
    super.initState();
    _myBjids = widget.snap.selectionCourses
        .where((course) => course.selected)
        .map((course) => course.id)
        .toSet();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var rows = await _fetch(onlyInWindow: true);
      var closed = false;
      if (rows.isEmpty) {
        // `type=2` 在非选课时间返回空列表，不代表接口失败；退回到全部课程。
        rows = await _fetch(onlyInWindow: false);
        closed = rows.isNotEmpty;
      }
      if (!mounted) return;
      setState(() {
        _courses = rows;
        _windowClosed = closed;
        _loading = false;
      });
    } on GmisSessionExpired {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onSessionExpired?.call();
    } on GmisException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetch({required bool onlyInWindow}) {
    return widget.api.courseListRows(
      lb: _lb,
      xwk: _xwk,
      zh: _zh,
      yxsh: _yxsh ?? '',
      onlyInWindow: onlyInWindow,
    );
  }

  List<Map<String, dynamic>> get _visible {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return _courses;
    return _courses.where((row) {
      final text = [
        _text(row['kcmc']),
        _text(row['kcbh']),
        _text(row['rkjsxm']),
        _text(row['bjmc']),
        _text(row['dz']),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Future<void> _submit(Map<String, dynamic> row, {required bool drop}) async {
    final bjid = _text(row['bjid']);
    if (bjid.isEmpty) {
      _toast('这门课没有班级 id，学校不允许提交。');
      return;
    }
    final name = _text(row['kcmc']);
    final klass = _text(row['bjmc']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(drop ? '确认退课？' : '确认选课？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (klass.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                klass,
                style: const TextStyle(fontSize: 13, color: HuayanColors.sub),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              '提交后会直接写入学校系统，不能撤回。',
              style: TextStyle(fontSize: 12, color: HuayanColors.sub),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: HuayanColors.danger),
            child: Text(drop ? '退课' : '选课'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final captcha = await showDialog<String>(
      context: context,
      builder: (context) => _CaptchaDialog(api: widget.api),
    );
    if (captcha == null || captcha.trim().isEmpty || !mounted) return;

    setState(() => _pendingBjid = bjid);
    try {
      final result = drop
          ? await widget.api.dropCourse(bjid: bjid, captcha: captcha)
          : await widget.api.selectCourse(bjid: bjid, captcha: captcha);
      if (!mounted) return;
      _toast(result.display);
      if (result.ok) {
        await widget.onChanged?.call();
        await _load();
      }
    } on GmisSessionExpired {
      widget.onSessionExpired?.call();
    } on GmisException catch (error) {
      if (mounted) _toast(error.message);
    } finally {
      if (mounted) setState(() => _pendingBjid = null);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    AppFeedback.show(text, context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Subpage(
      title: '选课',
      children: [
        _HeaderCard(
          snap: widget.snap,
          total: _courses.length,
          windowClosed: _windowClosed,
        ),
        const SizedBox(height: 12),
        _FilterBar(
          lb: _lb,
          xwk: _xwk,
          zh: _zh,
          onLb: (value) {
            setState(() => _lb = value);
            _load();
          },
          onXwk: (value) {
            setState(() => _xwk = value);
            _load();
          },
          onZh: (value) {
            setState(() => _zh = value);
            _load();
          },
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('selection-search'),
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '搜索课程名、课程号、教师或班级',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: HuayanColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          HuayanCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '课程列表没取到',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: _load, child: const Text('重试')),
              ],
            ),
          )
        else if (_visible.isEmpty)
          const EmptyHint(title: '没有匹配的课程', text: '换个关键词，或等学校开放选课时间窗口。')
        else
          for (final row in _visible)
            _CourseTile(
              row: row,
              selected: _myBjids.contains(_text(row['bjid'])),
              busy: _pendingBjid == _text(row['bjid']),
              onSelect: () => _submit(row, drop: false),
              onDrop: () => _submit(row, drop: true),
            ),
      ],
    );
  }
}

String _text(Object? value) => value == null ? '' : '$value'.trim();

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.snap,
    required this.total,
    required this.windowClosed,
  });

  final Snapshot snap;
  final int total;
  final bool windowClosed;

  @override
  Widget build(BuildContext context) {
    final picked = snap.selectionCourses
        .where((course) => course.selected)
        .length;
    return HuayanCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  snap.termName.isEmpty ? '本学期选课' : snap.termName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '已选 $picked 门',
                style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? '学校还没有返回可选课程。'
                : windowClosed
                ? '当前不在选课时间窗口，下面显示的是全部可选课程。'
                : '共 $total 门课程现在可选。',
            style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.lb,
    required this.xwk,
    required this.zh,
    required this.onLb,
    required this.onXwk,
    required this.onZh,
  });

  final String lb;
  final String xwk;
  final String zh;
  final ValueChanged<String> onLb;
  final ValueChanged<String> onXwk;
  final ValueChanged<String> onZh;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipRow(
          prefix: '类型',
          options: const [('3', '全部'), ('1', '公共课'), ('2', '专业课')],
          value: lb,
          onTap: onLb,
        ),
        const SizedBox(height: 6),
        _ChipRow(
          prefix: '学位',
          options: const [('', '全部'), ('1', '学位课'), ('0', '非学位课')],
          value: xwk,
          onTap: onXwk,
        ),
        const SizedBox(height: 6),
        _ChipRow(
          prefix: '星期',
          options: [
            ('', '全部'),
            for (var i = 1; i <= 7; i++) ('$i', weekdays[i - 1]),
          ],
          value: zh,
          onTap: onZh,
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.prefix,
    required this.options,
    required this.value,
    required this.onTap,
  });

  final String prefix;
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            prefix,
            style: const TextStyle(fontSize: 11, color: HuayanColors.sub),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in options)
                GestureDetector(
                  key: Key('selection-filter-$prefix-${option.$1}'),
                  onTap: () => onTap(option.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: value == option.$1
                          ? HuayanColors.blue
                          : HuayanColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: value == option.$1
                            ? HuayanColors.blue
                            : HuayanColors.lineSoft,
                      ),
                    ),
                    child: Text(
                      option.$2,
                      style: TextStyle(
                        fontSize: 12,
                        color: value == option.$1
                            ? Colors.white
                            : HuayanColors.sub,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.row,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onDrop,
  });

  final Map<String, dynamic> row;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final bjid = _text(row['bjid']);
    final name = _text(row['kcmc']);
    final klass = _text(row['bjmc']);
    final teacher = _text(row['rkjsxm']);
    final room = _text(row['dz']);
    final time = _text(row['sjms']);
    final credits = _text(row['kcxf']);
    final yxkc = int.tryParse(_text(row['yxkc'])) ?? 0;
    final xkfs = _text(row['xkfs']);
    final enrolled = _text(row['xkrs']);
    final capacity = _text(row['rnrs']);

    // yxkc：0 可选、1 已选、2 可退选；xkfs=2 才允许退课。
    final picked = selected || yxkc == 1 || yxkc == 2;
    final canDrop = yxkc == 2 || xkfs == '2';
    final canSelect = !picked && yxkc == 0;

    return Container(
      key: Key('selection-row-$bjid'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: HuayanColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HuayanColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? '未命名课程' : name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (picked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HuayanColors.blueSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '已选',
                    style: TextStyle(fontSize: 11, color: HuayanColors.blue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (klass.isNotEmpty) klass,
              if (teacher.isNotEmpty) teacher,
              if (credits.isNotEmpty) '$credits 学分',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
          ),
          if (time.isNotEmpty || room.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (time.isNotEmpty) time,
                if (room.isNotEmpty) room,
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (enrolled.isNotEmpty)
                Text(
                  capacity.isEmpty
                      ? '已选 $enrolled 人'
                      : '$enrolled / $capacity 人',
                  style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
                ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (canDrop)
                TextButton(
                  key: Key('selection-drop-$bjid'),
                  onPressed: onDrop,
                  style: TextButton.styleFrom(
                    foregroundColor: HuayanColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('退课'),
                )
              else if (canSelect)
                TextButton(
                  key: Key('selection-pick-$bjid'),
                  onPressed: onSelect,
                  style: TextButton.styleFrom(
                    foregroundColor: HuayanColors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('选课'),
                )
              else
                const Text(
                  '不可操作',
                  style: TextStyle(fontSize: 12, color: HuayanColors.sub),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 选课验证码弹层：取图 → 输入 → 返回验证码。
class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({required this.api});

  final GmisApi api;

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  final _code = TextEditingController();
  Uint8List? _image;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.api.selectionCaptcha();
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _loading = false;
      });
    } on GmisException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入选课验证码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选课验证码和登录验证码是两套，每次提交都要重新输入。',
            style: TextStyle(fontSize: 12, color: HuayanColors.sub),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_loading)
                const SizedBox(
                  width: 96,
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_image != null)
                InkWell(
                  onTap: _refresh,
                  child: Image.memory(
                    _image!,
                    key: const Key('selection-captcha-image'),
                    width: 96,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Text(
                  _error ?? '验证码加载失败',
                  style: const TextStyle(
                    fontSize: 12,
                    color: HuayanColors.danger,
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('selection-captcha-refresh'),
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: '换一张',
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('selection-captcha-input'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              hintText: '4 位验证码',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('selection-captcha-confirm'),
          onPressed: () => Navigator.of(context).pop(_code.text),
          child: const Text('提交'),
        ),
      ],
    );
  }
}
