import 'dart:typed_data';

import '../activities/activity_models.dart';
import 'gmis_client.dart';
import 'gmis_exception.dart';

/// 选课失败原因归一化。
///
/// 设计稿要求把学校的原始 `msg` 归成五类可操作提示，避免直接把
/// “该课程人数已满”这类后端措辞丢给用户。
enum SelectionFailure {
  none,
  full,
  conflict,
  closed,
  limit,
  duplicated,
  other;

  static SelectionFailure fromMessage(String message) {
    if (message.isEmpty) return SelectionFailure.none;
    if (message.contains('人数') ||
        message.contains('容量') ||
        message.contains('满')) {
      return SelectionFailure.full;
    }
    if (message.contains('门数') ||
        message.contains('上限') ||
        message.contains('最多')) {
      return SelectionFailure.limit;
    }
    // “冲突”要在“已选”之前判，学校常写成“与已选课程时间冲突”。
    if (message.contains('冲突')) {
      return SelectionFailure.conflict;
    }
    if (message.contains('选课时间') ||
        message.contains('未开放') ||
        message.contains('未到') ||
        message.contains('窗口') ||
        message.contains('不在')) {
      return SelectionFailure.closed;
    }
    if (message.contains('已选') || message.contains('重复')) {
      return SelectionFailure.duplicated;
    }
    return SelectionFailure.other;
  }

  String get hint => switch (this) {
    SelectionFailure.none => '',
    SelectionFailure.full => '这门课已经满员，换一个班级或等有人退课。',
    SelectionFailure.conflict => '和已选课程时间冲突，先调整课表再试。',
    SelectionFailure.closed => '当前不在选课时间窗口内。',
    SelectionFailure.limit => '已达到本学期选课门数上限。',
    SelectionFailure.duplicated => '这门课已经选过了。',
    SelectionFailure.other => '',
  };
}

/// 选课/退选提交结果。
class SelectionResult {
  const SelectionResult({
    required this.ok,
    required this.message,
    required this.reason,
  });

  final bool ok;

  /// 学校返回的原始 `msg`，成功时为空。
  final String message;
  final SelectionFailure reason;

  /// 给用户看的一句话。
  String get display {
    if (ok) return '操作成功';
    if (reason.hint.isNotEmpty) return reason.hint;
    return message.isEmpty ? '学校没有返回结果，请刷新后确认。' : message;
  }
}

/// GMIS 业务接口封装。只做请求和 JSON 形状校验，不负责页面模型。
class GmisApi implements ActivityDataSource {
  const GmisApi(this._client);

  final GmisClient _client;

  Future<List<Map<String, dynamic>>> terms() async {
    final value = await _client.getJson('/student/default/bindterm');
    // GMIS 会话过期时 JSON 接口不一定 302，而是返回空对象；这里必须
    // 主动转成会话过期，否则启动会被当成“学校没返回学期列表”而走离线缓存。
    if (value is Map && value.isEmpty) {
      throw const GmisSessionExpired();
    }
    return _asList(value);
  }

  Future<Map<String, dynamic>> studentCard() async {
    final value = await _client.getJson('/student/default/getxscardinfo');
    final rows = _asList(value);
    if (rows.isNotEmpty) return rows.first;
    return _asMap(value);
  }

  Future<List<Map<String, dynamic>>> selectedCourses(String termCode) async {
    return _asList(
      await _client.postJson(
        '/student/pygl/py_kbcx_yw',
        form: {'termcode': termCode},
      ),
    );
  }

  Future<Map<String, dynamic>> trainingPlan() async {
    return _asMap(await _client.postJson('/student/pygl/pyjhcxlist'));
  }

  Future<Map<String, dynamic>> selectionMeta() async {
    return _asMap(await _client.postJson('/student/pygl/xswsxk_kb_load'));
  }

  /// 选课验证码（`xkyzm`），与登录验证码完全独立。
  Future<Uint8List> selectionCaptcha() =>
      _client.fetchCaptchaBytes(CaptchaKind.selection);

  /// 提交选课（`lb=1`）或退选（`lb=0`）。`bjid` 是提交主键，不是课程号。
  Future<SelectionResult> selectCourse({
    required String bjid,
    required String captcha,
  }) => _submitSelection(lb: '1', bjid: bjid, captcha: captcha);

  Future<SelectionResult> dropCourse({
    required String bjid,
    required String captcha,
  }) => _submitSelection(lb: '0', bjid: bjid, captcha: captcha);

  Future<SelectionResult> _submitSelection({
    required String lb,
    required String bjid,
    required String captcha,
  }) async {
    final value = _asMap(
      await _client.postJson(
        '/student/pygl/xswsxk_kb_xk',
        form: {'lb': lb, 'bjid': bjid, 'xkyzm': captcha.trim()},
      ),
    );
    final message = '${value['msg'] ?? ''}'.trim();
    final sign = '${value['sign'] ?? ''}'.trim();
    final ok = message.isEmpty && (sign.isEmpty || sign == '1');
    return SelectionResult(
      ok: ok,
      message: message,
      reason: ok
          ? SelectionFailure.none
          : SelectionFailure.fromMessage(message),
    );
  }

  Future<Map<String, dynamic>> courseList({
    String lb = '3',
    String xwk = '',
    String zh = '',
    String jc1 = '',
    String jc2 = '',
    String yxsh = '',
    String kcbh = '',
    int page = 1,
    int rows = 100,
    bool onlyInWindow = false,
  }) async {
    return _asMap(
      await _client.postJson(
        '/student/pygl/xswsxk_kb_list',
        form: {
          'lb': lb,
          'xwk': xwk,
          'zh': zh,
          'jc1': jc1,
          'jc2': jc2,
          'yxsh': yxsh,
          'kcbh': kcbh,
          'page': '$page',
          'rows': '$rows',
          'type': onlyInWindow ? '2' : '1',
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> courseListRows({
    String lb = '3',
    String xwk = '',
    String zh = '',
    String jc1 = '',
    String jc2 = '',
    String yxsh = '',
    String kcbh = '',
    int pageSize = 100,
    bool onlyInWindow = false,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var page = 1; page <= 20; page++) {
      final data = await courseList(
        lb: lb,
        xwk: xwk,
        zh: zh,
        jc1: jc1,
        jc2: jc2,
        yxsh: yxsh,
        kcbh: kcbh,
        page: page,
        rows: pageSize,
        onlyInWindow: onlyInWindow,
      );
      final batch = _asList(data);
      result.addAll(batch);
      final total = int.tryParse('${data['total'] ?? ''}') ?? result.length;
      if (batch.isEmpty || result.length >= total) break;
    }
    return result;
  }

  Future<Map<String, dynamic>> courseCatalog({
    int page = 1,
    int rows = 200,
  }) async {
    return _asMap(
      await _client.postJson(
        '/student/pygl/xswsxk_all',
        form: {'page': '$page', 'rows': '$rows'},
      ),
    );
  }

  Future<List<Map<String, dynamic>>> courseCatalogRows({
    int pageSize = 200,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var page = 1; page <= 20; page++) {
      final data = await courseCatalog(page: page, rows: pageSize);
      final batch = _asList(data);
      result.addAll(batch);
      final total = int.tryParse('${data['total'] ?? ''}') ?? result.length;
      if (batch.isEmpty || result.length >= total) break;
    }
    return result;
  }

  Future<Map<String, dynamic>> grades() async {
    return _asMap(await _client.postJson('/student/pygl/xscjcx_list'));
  }

  Future<List<Map<String, dynamic>>> evaluations() async {
    // 文档对 GET/POST 写法不一致；Python 客户端实测 POST 可用，先 POST。
    try {
      return _asList(await _client.postJson('/student/pygl/wsjxpjlist'));
    } on GmisException {
      return _asList(await _client.getJson('/student/pygl/wsjxpjlist'));
    }
  }

  Future<List<Map<String, dynamic>>> applications() async {
    return _asList(await _client.postJson('/student/grgl/getxssqinfo'));
  }

  Future<Map<String, dynamic>> notices({
    int page = 1,
    int rows = 20,
    String title = '',
    String start = '',
    String end = '',
  }) async {
    return _asMap(
      await _client.getJson(
        '/student/grgl/tzgg_list',
        query: {
          'page': '$page',
          'rows': '$rows',
          if (title.isNotEmpty) 'bt': title,
          if (start.isNotEmpty) 'ksrq': start,
          if (end.isNotEmpty) 'jsrq': end,
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> examRooms() async {
    return _asList(await _client.postJson('/student/pygl/kckccx_list'));
  }

  Future<List<Map<String, dynamic>>> courseAdjustments() async {
    return _asList(
      await _client.postJson(
        '/student/pygl/ttkcx_list',
        form: {'page': '1', 'rows': '50'},
      ),
    );
  }

  Future<dynamic> rawGet(String path, {Map<String, String>? query}) {
    return _client.getJson(path, query: query);
  }

  Future<dynamic> rawPost(String path, {Map<String, String>? form}) {
    return _client.postJson(path, form: form);
  }

  Future<List<Map<String, dynamic>>> rawListGet(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      return _asList(await rawGet(path, query: query));
    } on GmisAuthException {
      rethrow;
    } on GmisException {
      // 文档与页面脚本对部分列表接口的 GET/POST 标注不一致。
      return _asList(await rawPost(path, form: query));
    }
  }

  Future<List<Map<String, dynamic>>> rawListPost(
    String path, {
    Map<String, String>? form,
  }) async {
    try {
      return _asList(await rawPost(path, form: form));
    } on GmisAuthException {
      rethrow;
    } on GmisException {
      return _asList(await rawGet(path, query: form));
    }
  }

  /// 学术报告/劳动实践的可报名列表。页面脚本用 POST；部分部署对 GET
  /// 也做了兼容，失败时回退，避免一个方法写死请求方式。
  @override
  Future<List<ActivityItem>> activityAvailable(ActivityKind kind) async {
    final rows = await _activityRows(kind.availablePath);
    return rows
        .map((row) => ActivityItem.fromJson(row, kind: kind, applied: false))
        .toList();
  }

  @override
  Future<List<ActivityItem>> activityApplied(ActivityKind kind) async {
    final rows = await _activityRows(kind.appliedPath);
    return rows
        .map((row) => ActivityItem.fromJson(row, kind: kind, applied: true))
        .toList();
  }

  /// 劳动实践累计小时。学校返回 `{zt:'1', hdzsc: '12.5'}`。
  @override
  Future<double> laborPracticeHours() async {
    final value = _asMap(await _client.postJson('/student/yggl/getldsjzsc'));
    final raw = '${value['hdzsc'] ?? ''}'.trim();
    return double.tryParse(raw) ?? 0;
  }

  /// 学术报告报名前预检；`sign=0` 表示当前不在报名时间内。
  @override
  Future<bool> canApplyAcademicReport(String id) async {
    final value = _asMap(
      await _client.getJson('/student/yggl/xshdbm_sfkysq', query: {'id': id}),
    );
    final sign = '${value['sign'] ?? ''}'.trim();
    return sign != '0';
  }

  @override
  Future<Uint8List> activityCaptcha() => _client.fetchActivityCaptcha();

  /// 学术报告/劳动实践共用报名接口；`VeriCode` 是独立的活动验证码。
  @override
  Future<ActivitySignResult> registerActivity({
    required String id,
    required String captcha,
  }) async {
    final value = _asMap(
      await _client.postJson(
        '/student/yggl/xshdbm_bm',
        form: {'id': id, 'VeriCode': captcha.trim()},
      ),
    );
    final message = '${value['msg'] ?? ''}'.trim();
    final sign = '${value['sign'] ?? ''}'.trim();
    final zt = '${value['zt'] ?? ''}'.trim();
    final ok = message.isEmpty && (zt == '1' || (zt.isEmpty && sign.isEmpty));
    if (ok) return const ActivitySignResult(ok: true, message: '');
    if (message.isNotEmpty) {
      return ActivitySignResult(ok: false, message: message);
    }
    if (sign == '-1') {
      return const ActivitySignResult(ok: false, message: '不在报名时间内，请刷新活动列表。');
    }
    return const ActivitySignResult(ok: false, message: '学校没有返回报名结果，请刷新后查看。');
  }

  @override
  Future<ActivitySignResult> cancelActivity({
    required ActivityKind kind,
    required String applicationId,
  }) async {
    final value = _asMap(
      await _client.postJson(kind.cancelPath, form: {'hdid': applicationId}),
    );
    final message = '${value['msg'] ?? ''}'.trim();
    final sign = '${value['sign'] ?? ''}'.trim();
    final zt = '${value['zt'] ?? ''}'.trim();
    final ok =
        message.isEmpty &&
        (zt == '1' || sign == '1' || (zt.isEmpty && sign.isEmpty));
    return ActivitySignResult(ok: ok, message: message);
  }

  Future<List<Map<String, dynamic>>> _activityRows(String path) async {
    try {
      return _asList(await _client.postJson(path));
    } on GmisAuthException {
      rethrow;
    } on GmisException {
      return _asList(await _client.getJson(path));
    }
  }

  Future<Map<String, dynamic>> registrationStatus() async {
    return _asMap(await rawPost('/student/grgl/getzcxx'));
  }

  Future<Map<String, dynamic>> onlineExamCurrent() async {
    return _asMap(await rawGet('/student/wsks/wskscp_load'));
  }

  Future<List<Map<String, dynamic>>> onlineExams() async {
    try {
      return _asList(await rawGet('/student/wsks/wskscp_list'));
    } on GmisAuthException {
      rethrow;
    } on GmisException {
      return _asList(await rawPost('/student/wsks/wskscp_list'));
    }
  }

  Future<List<Map<String, dynamic>>> onlineExamRows() async {
    final current = await onlineExamCurrent();
    final rows = <Map<String, dynamic>>[];
    for (var index = 1; index <= 4; index++) {
      final item = current['sj$index'];
      if (item is Map) {
        rows.add({...Map<String, dynamic>.from(item), '_kind': 'current'});
      }
    }
    for (final item in await onlineExams()) {
      rows.add({...item, '_kind': 'past'});
    }
    return rows;
  }

  Future<Map<String, dynamic>> menu() async {
    return _asMap(
      await _client.getJson(
        '/student/default/MenuleftInfo',
        query: {'_': '${DateTime.now().millisecondsSinceEpoch}'},
      ),
    );
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (value is Map) {
      // Python 客户端的 paged_rows 兼容 rows/kc/pyjh/pyfakc；Dart 端也接受
      // data/list/rows 这几种外层包装，避免真实接口多包一层时整页空态。
      for (final key in const [
        'rows',
        'kc',
        'pyjh',
        'pyfakc',
        'data',
        'list',
      ]) {
        final nested = value[key];
        final rows = _asList(nested);
        if (rows.isNotEmpty) return rows;
      }
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
