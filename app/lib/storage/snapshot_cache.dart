import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../snapshot.dart';

/// 最近一次成功的快照。缓存只写学业字段，不写密码、Cookie、验证码。
class SnapshotCache {
  SnapshotCache({this.directory});

  static const _fileName = 'snapshot_v2.json';

  final Directory? directory;

  Future<File> _file() async {
    final dir = directory ?? await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/$_fileName');
  }

  Future<Snapshot?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      final snapshot = Snapshot.fromJson(Map<String, dynamic>.from(raw));
      if (snapshot.schemaVersion < 2) return null;
      return snapshot;
    } catch (error) {
      debugPrint('读取快照缓存失败: $error');
      return null;
    }
  }

  Future<void> save(Snapshot snapshot) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      flush: true,
    );
    await temp.rename(file.path);
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 缓存损坏或不存在时不影响退出登录。
    }
  }
}
