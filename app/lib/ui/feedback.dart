import 'package:flutter/material.dart';

/// 全局轻提示：统一 SnackBar 样式，并对短时间内的重复文案去重。
class AppFeedback {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static String? _lastMessage;
  static DateTime? _lastAt;

  static void show(
    String message, {
    BuildContext? context,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    final text = message.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final lastAt = _lastAt;
    if (_lastMessage == text &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(seconds: 3)) {
      return;
    }
    _lastMessage = text;
    _lastAt = now;
    final messenger =
        messengerKey.currentState ??
        (context == null ? null : ScaffoldMessenger.maybeOf(context));
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), action: action, duration: duration),
      );
  }

  static void reset() {
    _lastMessage = null;
    _lastAt = null;
  }
}
