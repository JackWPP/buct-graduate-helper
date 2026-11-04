import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'schedule.dart';

Future<void> shareIcs(
  BuildContext context, {
  required List<Course> courses,
  required String termStart,
  required String filename,
  required String calendarName,
  required String successMessage,
}) async {
  final offline = courses.where(
    (course) => !course.online && course.segments.isNotEmpty,
  );
  if (offline.isEmpty) {
    _toast(context, '线上课的节次是占位，没有写进日历');
    return;
  }
  final body = buildIcs(courses, termStart, calendarName: calendarName);
  final safe = filename.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safe');
    await file.writeAsString(body);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar', name: safe)],
        subject: calendarName,
      ),
    );
    if (!context.mounted) return;
    _toast(context, successMessage);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: body));
    if (!context.mounted) return;
    _toast(context, successMessage.replaceFirst('已导出', '已复制'));
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 900),
    ),
  );
}
