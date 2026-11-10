import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'todo_models.dart';

abstract interface class TodoStore {
  Future<List<TodoItem>> load();
  Future<void> save(List<TodoItem> items);
  Future<void> clear();
}

/// 本机待办按学号隔离：换账号看不到别人的待办，退出登录不删数据。
class PrefsTodoStore implements TodoStore {
  PrefsTodoStore({required this.profileKey, this.prefs});

  static const _prefix = 'huayan_todos_v1_';
  static const _version = 1;

  final String profileKey;
  final SharedPreferences? prefs;

  String get key => '$_prefix$profileKey';

  Future<SharedPreferences> _instance() async =>
      prefs ?? await SharedPreferences.getInstance();

  @override
  Future<List<TodoItem>> load() async {
    try {
      final prefs = await _instance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return const <TodoItem>[];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <TodoItem>[];
      final items = decoded['items'];
      if (items is! List) return const <TodoItem>[];
      final result = <TodoItem>[];
      for (final item in items) {
        if (item is! Map) continue;
        final todo = TodoItem.tryFromJson(Map<String, dynamic>.from(item));
        if (todo != null) result.add(todo);
      }
      return result;
    } catch (error) {
      debugPrint('读取本机待办失败: $error');
      return const <TodoItem>[];
    }
  }

  @override
  Future<void> save(List<TodoItem> items) async {
    final prefs = await _instance();
    await prefs.setString(
      key,
      jsonEncode({
        'version': _version,
        'items': [for (final item in items) item.toJson()],
      }),
    );
  }

  @override
  Future<void> clear() async {
    final prefs = await _instance();
    await prefs.remove(key);
  }
}
