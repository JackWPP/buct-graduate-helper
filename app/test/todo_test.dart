import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/planner/todo_controller.dart';
import 'package:huayan/planner/todo_models.dart';
import 'package:huayan/planner/todo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStore implements TodoStore {
  List<TodoItem> items = [];
  int saves = 0;

  @override
  Future<List<TodoItem>> load() async => List<TodoItem>.from(items);

  @override
  Future<void> save(List<TodoItem> next) async {
    saves++;
    items = List<TodoItem>.from(next);
  }

  @override
  Future<void> clear() async {
    items = [];
  }
}

TodoItem _todo({
  String id = 't1',
  String title = '交报告',
  int? start = 9 * 60,
  int? end = 10 * 60,
  bool done = false,
}) {
  return TodoItem(
    id: id,
    title: title,
    date: '2026-11-10',
    startMin: start,
    endMin: end,
    done: done,
    createdAt: 0,
  );
}

void main() {
  test('todo json round-trips and drops invalid times', () {
    final item = _todo();
    final parsed = TodoItem.tryFromJson(item.toJson());
    expect(parsed, isNotNull);
    expect(parsed!.title, '交报告');
    expect(parsed.timed, isTrue);

    final invalid = TodoItem.tryFromJson({
      ...item.toJson(),
      'startMin': 600,
      'endMin': 500,
    });
    expect(invalid, isNotNull);
    expect(invalid!.allDay, isTrue);
    expect(TodoItem.tryFromJson({...item.toJson(), 'title': ''}), isNull);
    expect(TodoItem.tryFromJson({...item.toJson(), 'date': '11-10'}), isNull);
  });

  test('prefs store saves, loads and clears per profile', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsTodoStore(profileKey: '2026000001', prefs: prefs);
    await store.save([_todo()]);

    final loaded = await PrefsTodoStore(
      profileKey: '2026000001',
      prefs: prefs,
    ).load();
    expect(loaded, hasLength(1));
    expect(loaded.single.title, '交报告');

    final other = await PrefsTodoStore(
      profileKey: '2026000002',
      prefs: prefs,
    ).load();
    expect(other, isEmpty);

    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('prefs store tolerates corrupt payloads', () async {
    SharedPreferences.setMockInitialValues({
      'huayan_todos_v1_2026000001': '{not json',
    });
    final prefs = await SharedPreferences.getInstance();
    final loaded = await PrefsTodoStore(
      profileKey: '2026000001',
      prefs: prefs,
    ).load();
    expect(loaded, isEmpty);
  });

  test('controller persists add, toggle and delete', () async {
    final store = _MemoryStore();
    final controller = TodoController(store: store);
    await controller.load();
    expect(controller.loaded, isTrue);

    final item = _todo();
    await controller.upsert(item);
    expect(controller.todos, hasLength(1));

    await controller.toggle(item);
    expect(controller.todos.single.done, isTrue);

    await controller.upsert(item.copyWith(title: '改过的标题'));
    expect(controller.todos.single.title, '改过的标题');
    expect(controller.todos, hasLength(1));

    await controller.delete(item.id);
    expect(controller.todos, isEmpty);
    expect(store.saves, greaterThanOrEqualTo(3));
  });
}
