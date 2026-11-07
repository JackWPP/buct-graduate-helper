import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

/// 本机偏好。密码、验证码和 Cookie 不进这里。
class PrefsStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const onboardedKey = 'buct_onboarded';
  static const sidKey = 'buct_sid';
  static const settingsKey = 'buct_settings';
  static const termStartPrefix = 'buct_term_start_';

  /// 小组件没接上时返回 null。Widget 测试因此直接进入首页。
  static Future<PrefsStore?> tryOpen() async {
    try {
      return PrefsStore(await SharedPreferences.getInstance());
    } catch (_) {
      return null;
    }
  }

  bool get onboarded => _prefs.getBool(onboardedKey) ?? false;

  String get sid => _prefs.getString(sidKey) ?? '';

  Future<void> setOnboarded() => _prefs.setBool(onboardedKey, true);

  Future<void> setSid(String? value) {
    if (value == null || value.isEmpty) return _prefs.remove(sidKey);
    return _prefs.setString(sidKey, value);
  }

  String? termStart(String termCode) =>
      _prefs.getString('$termStartPrefix$termCode');

  Future<void> setTermStart(String termCode, String firstMonday) =>
      _prefs.setString('$termStartPrefix$termCode', firstMonday);

  void apply(AppSettings settings) {
    final raw = _prefs.getString(settingsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      settings.applyJson(jsonDecode(raw));
    } catch (_) {
      // 坏掉的偏好按默认值继续，不挡住课表。
    }
  }

  Future<void> save(AppSettings settings) {
    return _prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }
}
