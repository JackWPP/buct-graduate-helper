import 'dart:convert';

/// 旧版单账号使用空 storageKey，继续读写未加后缀的旧 key。
const legacyAccountStorageKey = '';

/// 把学号变成可用于安全存储 key 和缓存文件名的命名空间。
///
/// 学号本身是数字，但这里仍做白名单，避免历史数据或手工导入的异常值
/// 拼出 `../` 之类的路径。空字符串表示旧版单账号命名空间。
String accountStorageKeyFor(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return legacyAccountStorageKey;
  final safe = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return safe.length <= 64 ? safe : safe.substring(0, 64);
}

String _string(Object? raw) => '${raw ?? ''}'.trim();

DateTime _date(Object? raw, DateTime fallback) {
  final parsed = DateTime.tryParse('${raw ?? ''}');
  return parsed ?? fallback;
}

/// 本机保存的账号身份信息。这里只放展示字段，不存密码、Cookie 或票据。
class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    required this.college,
    required this.major,
    required this.storageKey,
    required this.addedAt,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final String college;
  final String major;

  /// 空字符串表示旧版单账号命名空间；其他值是新账号的存储后缀。
  final String storageKey;
  final DateTime addedAt;
  final DateTime lastUsedAt;

  bool get isLegacy => storageKey.isEmpty;

  AccountProfile copyWith({
    String? id,
    String? name,
    String? college,
    String? major,
    String? storageKey,
    DateTime? addedAt,
    DateTime? lastUsedAt,
  }) {
    return AccountProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      college: college ?? this.college,
      major: major ?? this.major,
      storageKey: storageKey ?? this.storageKey,
      addedAt: addedAt ?? this.addedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'college': college,
    'major': major,
    'storageKey': storageKey,
    'addedAt': addedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt.toIso8601String(),
  };

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final id = _string(json['id']);
    return AccountProfile(
      id: id,
      name: _string(json['name']),
      college: _string(json['college']),
      major: _string(json['major']),
      storageKey: accountStorageKeyFor(_string(json['storageKey'])),
      addedAt: _date(json['addedAt'], now),
      lastUsedAt: _date(json['lastUsedAt'], now),
    );
  }

  @override
  String toString() => 'AccountProfile(id: $id, name: $name)';
}

/// 账号册。它是账号列表和活跃账号的事实来源；`PrefsStore.sid` 只是镜像。
class AccountBook {
  const AccountBook({this.accounts = const [], this.activeId});

  final List<AccountProfile> accounts;
  final String? activeId;

  AccountProfile? get active {
    final id = activeId;
    if (id == null || id.isEmpty) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  AccountProfile? byId(String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  bool get isEmpty => accounts.isEmpty;

  AccountBook copyWith({List<AccountProfile>? accounts, String? activeId}) {
    return AccountBook(
      accounts: accounts ?? this.accounts,
      activeId: activeId ?? this.activeId,
    ).normalized();
  }

  /// 新增或更新账号；已有的 addedAt 不被覆盖。
  AccountBook upsert(AccountProfile profile) {
    final next = <AccountProfile>[];
    var replaced = false;
    for (final account in accounts) {
      if (account.id == profile.id) {
        next.add(
          profile.copyWith(
            addedAt: account.addedAt,
            storageKey: account.storageKey,
          ),
        );
        replaced = true;
      } else {
        next.add(account);
      }
    }
    if (!replaced) next.add(profile);
    return copyWith(
      accounts: next,
      activeId: (activeId == null || activeId!.isEmpty) ? profile.id : activeId,
    );
  }

  AccountBook activate(String id) {
    if (byId(id) == null) return this;
    return copyWith(activeId: id);
  }

  /// 移除账号。若移除的是活跃账号，自动选择最近使用的其他账号。
  AccountBook remove(String id) {
    final next = accounts.where((account) => account.id != id).toList();
    var nextActive = activeId;
    if (nextActive == id) {
      nextActive = null;
      if (next.isNotEmpty) {
        final sorted = [...next]
          ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
        nextActive = sorted.first.id;
      }
    }
    return AccountBook(accounts: next, activeId: nextActive).normalized();
  }

  /// 过滤空 id/重复 id，并修正不存在的 activeId。
  AccountBook normalized() {
    final seen = <String>{};
    final next = <AccountProfile>[];
    for (final account in accounts) {
      if (account.id.isEmpty || !seen.add(account.id)) continue;
      next.add(
        account.copyWith(storageKey: accountStorageKeyFor(account.storageKey)),
      );
    }
    var nextActive = activeId;
    if (nextActive == null ||
        nextActive.isEmpty ||
        !seen.contains(nextActive)) {
      nextActive = next.isEmpty
          ? null
          : ([
              ...next,
            ]..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt))).first.id;
    }
    return AccountBook(accounts: List.unmodifiable(next), activeId: nextActive);
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'activeId': activeId,
    'accounts': accounts.map((account) => account.toJson()).toList(),
  };

  factory AccountBook.fromJson(Map<String, dynamic> json) {
    final raw = json['accounts'];
    final accounts = <AccountProfile>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          accounts.add(
            AccountProfile.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return AccountBook(
      accounts: accounts,
      activeId: _string(json['activeId']),
    ).normalized();
  }

  String encode() => jsonEncode(toJson());

  factory AccountBook.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('账号册格式不正确');
    return AccountBook.fromJson(Map<String, dynamic>.from(decoded));
  }
}
