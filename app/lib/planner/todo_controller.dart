import 'package:flutter/foundation.dart';

import 'todo_models.dart';
import 'todo_store.dart';

/// 本机待办的内存状态 + 持久化。
///
/// 保存失败时保留当前内存列表并设置 [error]，不让页面因为存储异常崩掉；
/// 不打印待办标题或备注。
class TodoController extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  TodoController({required TodoStore store}) : _store = store;

  final TodoStore _store;
  List<TodoItem> _todos = const <TodoItem>[];
  bool _loaded = false;
  bool _mutated = false;
  bool _disposed = false;
  String? _error;

  List<TodoItem> get todos => List<TodoItem>.unmodifiable(_todos);
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load() async {
    try {
      final loaded = await _store.load();
      // 用户在 load 完成前已经加过待办时，不要用旧存储覆盖新内容。
      if (!_mutated) _todos = loaded;
      _error = null;
    } catch (error) {
      _todos = const <TodoItem>[];
      _error = '读取本机待办失败';
      debugPrint('读取本机待办失败: $error');
    } finally {
      _loaded = true;
      _notify();
    }
  }

  Future<void> upsert(TodoItem item) async {
    _mutated = true;
    final next = <TodoItem>[..._todos];
    final index = next.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    _todos = next;
    _notify();
    await _persist();
  }

  Future<void> toggle(TodoItem item) => upsert(item.copyWith(done: !item.done));

  Future<void> delete(String id) async {
    _mutated = true;
    _todos = _todos.where((item) => item.id != id).toList();
    _notify();
    await _persist();
  }

  Future<void> clear() async {
    _mutated = true;
    _todos = const <TodoItem>[];
    _notify();
    try {
      await _store.clear();
      _error = null;
    } catch (error) {
      _error = '清空本机待办失败';
      debugPrint('清空本机待办失败: $error');
    }
    _notify();
  }

  Future<void> _persist() async {
    try {
      await _store.save(_todos);
      _error = null;
    } catch (error) {
      _error = '待办保存失败，已保留在当前会话';
      debugPrint('保存本机待办失败: $error');
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
