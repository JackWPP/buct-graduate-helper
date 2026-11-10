import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/auth/auth_gateway.dart';
import 'package:huayan/gmis/gmis_crypto.dart';
import 'package:huayan/gmis/gmis_exception.dart';
import 'package:huayan/snapshot.dart';
import 'package:huayan/storage/snapshot_cache.dart';

const _testPublicKey = '''
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDSsOsjPum/eh6Ve/k+W6lqfyRc
szk/XJfMuD2QJnp3MZhmECVs/84QS2SGMtpe+IMUCyN7xo+MC7rHLdiuxqaZXPdu
KbVoC8s/MUDdM/bvsT/LJ1j6LLHBrGVYhOzJu5JOH+v6SBj3QjthGVJ5UNcxgwTY
fIRAsJr4yyEPpRHyvwIDAQAB
-----END PUBLIC KEY-----
''';

void main() {
  test('extractPublicKey reads the hidden GMIS field', () {
    final html =
        '''<input id="pubkey" type="hidden" value='$_testPublicKey'>''';
    expect(extractPublicKey(html), _testPublicKey.trim());
  });

  test('encryptGmisPassword returns base64 RSA ciphertext', () {
    final encrypted = encryptGmisPassword(_testPublicKey, 'secret');
    expect(base64Decode(encrypted).length, 128);
  });

  test('snapshot v2 round trip keeps list data and counters', () {
    final snapshot = Snapshot(
      termName: '2026-2027秋季学期',
      termStart: '2026-08-31',
      student: const Student(name: '测试', id: '2026000001'),
      courses: const [],
      schemaVersion: 2,
      termCode: '55',
      grades: const [
        GradeRecord(
          termName: '2026-2027秋季学期',
          courseCode: 'A001',
          courseName: '测试课程',
          credits: 2,
          score: '90',
        ),
      ],
      noticeItems: const [
        NoticeItem(id: '1', title: '通知', publishedAt: '2026-10-01'),
      ],
      examItems: const [
        ExamItem(
          termName: '2026-2027秋季学期',
          courseCode: 'A001',
          courseName: '测试课程',
          room: '教101',
          date: '2026-11-10',
          startTime: '09:00',
        ),
      ],
      selectionCourses: const [
        SelectionCourse(
          id: 'b1',
          code: 'A001',
          name: '测试课程',
          capacity: 30,
          selected: true,
          selectable: 1,
        ),
      ],
    );
    final restored = Snapshot.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map,
      ),
    );
    expect(restored.schemaVersion, 2);
    expect(restored.termCode, '55');
    expect(restored.grades.single.courseName, '测试课程');
    expect(restored.noticeItems.single.title, '通知');
    expect(restored.examItems.single.courseCode, 'A001');
    expect(restored.selectionCourses.single.capacity, 30);
    expect(restored.notices, 1);
    expect(restored.exams, 1);
  });

  test('bundled snapshot exposes 49 service entries including notices', () {
    final snap = Snapshot.fromJson(
      jsonDecode(File('assets/snapshot.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(
      snap.services.fold<int>(0, (sum, group) => sum + group.items.length),
      49,
    );
    final notices = snap.services
        .expand((group) => group.items)
        .singleWhere((item) => item.id == 'tzgg');
    expect(notices.native, 'notices');
  });

  test('snapshot cache round trips schema v2 in a temp directory', () async {
    final dir = await Directory.systemTemp.createTemp('huayan-cache-');
    addTearDown(() => dir.delete(recursive: true));
    final cache = SnapshotCache(directory: dir);
    final snapshot = Snapshot(
      termName: '2026-2027秋季学期',
      termStart: '2026-08-31',
      student: const Student(name: '测试', id: '2026000001'),
      courses: const [],
      schemaVersion: 2,
      termCode: '55',
      noticeItems: const [NoticeItem(id: '1', title: '通知')],
    );
    await cache.save(snapshot);
    final loaded = await cache.load();
    expect(loaded, isNotNull);
    expect(loaded!.schemaVersion, 2);
    expect(loaded.termCode, '55');
    expect(loaded.noticeItems.single.title, '通知');
  });

  test('auth session json keeps the optional WebVPN base URL', () {
    final session = AuthSession(
      userId: '2026000001',
      cookies: const {'ASP.NET_SessionId': 'abc'},
      savedAt: DateTime(2026, 11, 7, 12),
      baseUrl: 'https://w.buct.edu.cn/https/token/',
    );
    final restored = AuthSession.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(session.toJson())) as Map,
      ),
    );
    expect(restored.baseUrl, 'https://w.buct.edu.cn/https/token/');
    expect(restored.cookies['ASP.NET_SessionId'], 'abc');
  });

  test(
    'demo gateway accepts only its demo student and local captcha',
    () async {
      final gateway = DemoAuthGateway(demoStudentId: '2026000001');
      final captcha = await gateway.fetchCaptcha();
      final code = captcha.demoCode;
      expect(code, isNotNull);
      expect(code!.length, 4);

      final session = await gateway.login(
        userId: '2026000001',
        password: 'secret',
        captcha: code,
      );
      expect(session.userId, '2026000001');
      expect(session.cookies, isEmpty);

      expect(
        () => gateway.login(
          userId: '2026000002',
          password: 'secret',
          captcha: code,
        ),
        throwsA(isA<GmisAuthException>()),
      );
    },
  );
}
