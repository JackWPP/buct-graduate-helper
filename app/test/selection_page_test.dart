import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/gmis/gmis_api.dart';
import 'package:huayan/gmis/gmis_client.dart';
import 'package:huayan/gmis/gmis_transport.dart';
import 'package:huayan/selection_page.dart';
import 'package:huayan/snapshot.dart';
import 'package:huayan/theme.dart';

/// 1x1 透明 PNG，用来让 `Image.memory` 能真的解码。
final _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
);

class _FakeTransport implements GmisTransport {
  final submitted = <Map<String, String>?>[];
  final courseQueries = <Map<String, String>>[];

  @override
  Future<GmisResponse> send(GmisRequest request) async {
    switch (request.path) {
      case '/student/pygl/xswsxk_kb_load':
        return GmisResponse(
          statusCode: 200,
          headers: const {},
          body: jsonEncode({
            'yx': [
              {'xsbh': '001', 'xsmc': '化学工程学院'},
              {'xsbh': '002', 'xsmc': '材料科学与工程学院'},
            ],
            'jc': [
              {'id': 41, 'mc': '上午1'},
              {'id': 42, 'mc': '上午2'},
              {'id': 46, 'mc': '下午6'},
              {'id': 50, 'mc': '晚上10'},
            ],
          }),
        );
      case '/student/pygl/xswsxk_kb_list':
        courseQueries.add(request.form ?? const <String, String>{});
        return GmisResponse(
          statusCode: 200,
          headers: const {},
          body: jsonEncode({
            'total': 2,
            'kc': [
              {
                'bjid': 'bj-new',
                'kcmc': '催化化学',
                'bjmc': '催化化学A班',
                'rkjsxm': '何静',
                'dz': '科402',
                'kcxf': '2',
                'sjms': '星期一 下午6-下午9',
                'xkrs': '20',
                'rnrs': '30',
                'yxkc': '0',
              },
              {
                'bjid': 'bj-old',
                'kcmc': '数值分析',
                'bjmc': '数值分析B班',
                'rkjsxm': '常延贞',
                'kcxf': '3',
                'sjms': '星期二 上午1-上午2',
                'xkrs': '40',
                'rnrs': '40',
                'yxkc': '2',
              },
            ],
          }),
        );
      case '/home/verificationcode':
        return GmisResponse(
          statusCode: 200,
          headers: const {},
          body: '',
          bytes: _pngBytes,
        );
      case '/student/pygl/xswsxk_kb_xk':
        submitted.add(request.form);
        return GmisResponse(statusCode: 200, headers: const {}, body: '{}');
      default:
        return GmisResponse(statusCode: 200, headers: const {}, body: '{}');
    }
  }
}

Snapshot _snapshot() {
  final json = jsonDecode(File('assets/snapshot.json').readAsStringSync());
  return Snapshot.fromJson(json as Map<String, dynamic>);
}

Widget _wrap(GmisApi api, Snapshot snap) {
  return MaterialApp(
    theme: huayanTheme(),
    home: SelectionPage(api: api, snap: snap),
  );
}

void main() {
  testWidgets('selection page lists courses with actions', (tester) async {
    final api = GmisApi(GmisClient(transport: _FakeTransport()));
    await tester.pumpWidget(_wrap(api, _snapshot()));
    await tester.pumpAndSettle();

    expect(find.text('催化化学'), findsOneWidget);
    expect(find.text('数值分析'), findsOneWidget);
    expect(find.byKey(const Key('selection-pick-bj-new')), findsOneWidget);
    expect(find.byKey(const Key('selection-drop-bj-old')), findsOneWidget);
    expect(find.byKey(const Key('selection-search')), findsOneWidget);
  });

  testWidgets('selecting a course asks for confirmation and captcha', (
    tester,
  ) async {
    final transport = _FakeTransport();
    final api = GmisApi(GmisClient(transport: transport));
    var refreshed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: huayanTheme(),
        home: SelectionPage(
          api: api,
          snap: _snapshot(),
          onChanged: () async => refreshed++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('selection-pick-bj-new')));
    await tester.pumpAndSettle();
    // 二次确认：写清课程名，并且只有确认后才继续。
    expect(find.text('确认选课？'), findsOneWidget);
    expect(find.textContaining('不能撤回'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '选课'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('输入选课验证码'), findsOneWidget);
    expect(find.byKey(const Key('selection-captcha-image')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('selection-captcha-input')),
      '4321',
    );
    await tester.tap(find.byKey(const Key('selection-captcha-confirm')));
    await tester.pumpAndSettle();

    expect(transport.submitted, [
      {'lb': '1', 'bjid': 'bj-new', 'xkyzm': '4321'},
    ]);
    expect(refreshed, 1);
    expect(find.text('操作成功'), findsOneWidget);
  });

  testWidgets('cancelling the confirm dialog submits nothing', (tester) async {
    final transport = _FakeTransport();
    final api = GmisApi(GmisClient(transport: transport));
    await tester.pumpWidget(_wrap(api, _snapshot()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('selection-pick-bj-new')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '取消'),
      ),
    );
    await tester.pumpAndSettle();

    expect(transport.submitted, isEmpty);
  });

  testWidgets('selection filters by department and period', (tester) async {
    final transport = _FakeTransport();
    final api = GmisApi(GmisClient(transport: transport));
    await tester.pumpWidget(_wrap(api, _snapshot()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selection-filter-院系-001')), findsOneWidget);
    await tester.tap(find.byKey(const Key('selection-filter-院系-001')));
    await tester.pumpAndSettle();
    expect(transport.courseQueries.last['yxsh'], '001');

    await tester.tap(find.byKey(const Key('selection-filter-节次-下午')));
    await tester.pumpAndSettle();
    expect(find.text('催化化学'), findsOneWidget);
    expect(find.text('数值分析'), findsNothing);

    await tester.tap(find.byKey(const Key('selection-filter-节次-上午')));
    await tester.pumpAndSettle();
    expect(find.text('数值分析'), findsOneWidget);
    expect(find.text('催化化学'), findsNothing);

    await tester.tap(find.byKey(const Key('selection-filter-节次-')));
    await tester.pumpAndSettle();
    expect(find.text('催化化学'), findsOneWidget);
    expect(find.text('数值分析'), findsOneWidget);
  });
}
