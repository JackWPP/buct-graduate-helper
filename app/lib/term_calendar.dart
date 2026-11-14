import 'prefs.dart';

/// GMIS 不返回“第 1 周周一”，这里维护已知学期并允许用户在本机补充。
class TermCalendar {
  const TermCalendar({this.prefs, this.accountId = ''});

  final PrefsStore? prefs;
  final String accountId;

  static const Map<String, String> knownStarts = {
    // 2026-2027 秋季学期，55 为 GMIS 当前 termcode。
    '55': '2026-08-31',
  };

  String? resolve(String termCode) {
    if (termCode.isEmpty) return null;
    final stored = prefs?.termStart(termCode, accountId: accountId);
    if (stored != null && stored.isNotEmpty) return stored;
    return knownStarts[termCode];
  }

  Future<void> remember(String termCode, String firstMonday) async {
    if (termCode.isEmpty || firstMonday.isEmpty) return;
    await prefs?.setTermStart(termCode, firstMonday, accountId: accountId);
  }
}
