import 'package:flutter/material.dart';

import 'gmis/gmis_exception.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

typedef RemoteRows = Future<List<Map<String, dynamic>>> Function();
typedef RemoteMap = Future<Map<String, dynamic>> Function();

String _textOf(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return '$value';
  return '';
}

String _firstOf(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = _textOf(row[key]);
    if (value.isNotEmpty && value != 'null') return value;
  }
  return '';
}

/// 通用列表页：用于已经有 JSON 列表接口、但没有专门设计稿的服务。
class RemoteListPage extends StatefulWidget {
  const RemoteListPage({
    super.key,
    required this.title,
    required this.load,
    this.intro = '',
    this.emptyText = '学校暂未返回记录。',
    this.onSessionExpired,
  });

  final String title;
  final String intro;
  final String emptyText;
  final RemoteRows load;
  final VoidCallback? onSessionExpired;

  @override
  State<RemoteListPage> createState() => _RemoteListPageState();
}

class _RemoteListPageState extends State<RemoteListPage> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _sessionNotified = false;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant RemoteListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final children = <Widget>[];
        if (widget.intro.isNotEmpty) {
          children.add(
            Text(
              widget.intro,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: HuayanColors.sub,
              ),
            ),
          );
          children.add(const SizedBox(height: 12));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          children.add(const _LoadingCard());
        } else if (snapshot.hasError) {
          _notifySession(snapshot.error);
          children.add(_ErrorCard(_message(snapshot.error)));
        } else {
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            children.add(
              EmptyHint(
                title: '暂时没有记录',
                text: widget.emptyText,
                glyph: 'clipboard',
              ),
            );
          } else {
            for (final row in rows) {
              children.add(_RemoteRowCard(row: row));
              children.add(const SizedBox(height: 10));
            }
          }
        }
        return Subpage(title: widget.title, children: children);
      },
    );
  }

  void _notifySession(Object? error) {
    if (_sessionNotified || error is! GmisSessionExpired) return;
    final callback = widget.onSessionExpired;
    if (callback == null) return;
    _sessionNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  String _message(Object? error) {
    if (error is GmisException) return error.message;
    return '加载失败，请稍后重试。';
  }
}

/// 通用信息页：用于返回单个 JSON 对象的服务，例如学期报到注册。
class RemoteInfoPage extends StatefulWidget {
  const RemoteInfoPage({
    super.key,
    required this.title,
    required this.load,
    required this.fields,
    this.intro = '',
    this.onSessionExpired,
  });

  final String title;
  final String intro;
  final RemoteMap load;
  final List<(String, String)> fields;
  final VoidCallback? onSessionExpired;

  @override
  State<RemoteInfoPage> createState() => _RemoteInfoPageState();
}

class _RemoteInfoPageState extends State<RemoteInfoPage> {
  late Future<Map<String, dynamic>> _future;
  bool _sessionNotified = false;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Subpage(title: widget.title, children: const [_LoadingCard()]);
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          _notifySession(error);
          return Subpage(
            title: widget.title,
            children: [
              _ErrorCard(
                error is GmisException ? error.message : '加载失败，请稍后重试。',
              ),
            ],
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final rows = <Widget>[];
        for (final field in widget.fields) {
          final value = _textOf(data[field.$2]);
          if (value.isEmpty) continue;
          rows.add(KvRow(label: field.$1, value: value));
        }
        return Subpage(
          title: widget.title,
          children: [
            if (widget.intro.isNotEmpty) ...[
              Text(
                widget.intro,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: HuayanColors.sub,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (rows.isEmpty)
              const EmptyHint(
                title: '暂时没有记录',
                text: '学校暂未返回这一项。',
                glyph: 'clipboard',
              )
            else
              HuayanCard(child: Column(children: rows)),
          ],
        );
      },
    );
  }

  void _notifySession(Object? error) {
    if (_sessionNotified || error is! GmisSessionExpired) return;
    final callback = widget.onSessionExpired;
    if (callback == null) return;
    _sessionNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const HuayanCard(
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('正在读取学校数据…', style: TextStyle(color: HuayanColors.sub)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return HuayanCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HuayanIcon('info', size: 18, color: HuayanColors.amberInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: HuayanColors.amberInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteRowCard extends StatelessWidget {
  const _RemoteRowCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final title = _firstOf(row, const [
      'tkmc',
      'sjmc',
      'kcmc',
      'djksmc',
      'xmmc',
      'bt',
      'mc',
      'name',
      'title',
      'jcid',
    ]);
    final subtitle = _firstOf(row, const [
      'kssj',
      'sj',
      'rq',
      'fbrq',
      'time',
      'ksrq',
      'shlbz',
      'zt',
      'ztmc',
    ]);
    final lines = <String>[];
    for (final entry in row.entries) {
      if (const {
        'tkmc',
        'sjmc',
        'kcmc',
        'djksmc',
        'xmmc',
        'bt',
        'mc',
        'name',
        'title',
        'jcid',
        'kssj',
        'sj',
        'rq',
        'fbrq',
        'time',
        'ksrq',
        'shlbz',
        'zt',
        'ztmc',
      }.contains(entry.key)) {
        continue;
      }
      final value = _textOf(entry.value);
      if (value.isEmpty || value == 'null') continue;
      lines.add('${_labelOf(entry.key)}：$value');
      if (lines.length >= 4) break;
    }
    return HuayanCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? '学校记录' : title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HuayanColors.ink,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: HuayanColors.sub),
            ),
          ],
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: HuayanColors.faint,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _labelOf(String key) {
    const labels = {
      'kcbh': '课程编号',
      'kcmc': '课程',
      'xm': '姓名',
      'xh': '学号',
      'bj': '班级',
      'bjid': '班级',
      'rq': '日期',
      'ksrq': '开始日期',
      'jsrq': '结束日期',
      'kssj': '时间',
      'kksj': '考试时间',
      'kscj': '成绩',
      'ksys': '考试老师',
      'zwh': '座位号',
      'dz': '地点',
      'bz': '备注',
    };
    return labels[key] ?? key;
  }
}
