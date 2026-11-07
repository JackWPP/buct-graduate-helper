import 'gmis_client.dart';
import 'gmis_exception.dart';

/// GMIS 业务接口封装。只做请求和 JSON 形状校验，不负责页面模型。
class GmisApi {
  const GmisApi(this._client);

  final GmisClient _client;

  Future<List<Map<String, dynamic>>> terms() async {
    return _asList(await _client.getJson('/student/default/bindterm'));
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
    int pageSize = 100,
    bool onlyInWindow = false,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (var page = 1; page <= 20; page++) {
      final data = await courseList(
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
