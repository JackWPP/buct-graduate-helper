import 'package:flutter/material.dart';

class HuayanColors {
  static const blue = Color(0xFF2F6BFF);
  static const blueSoft = Color(0xFFEDF2FF);
  static const bg = Color(0xFFF5F7FA);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6E9F0);
  static const lineSoft = Color(0xFFEDEFF4);
  static const ink = Color(0xFF14171F);
  static const sub = Color(0xFF5B6273);
  static const faint = Color(0xFF9AA1B2);
  static const placeholder = Color(0xFFB6BCC9);
  static const danger = Color(0xFFE5484D);
  static const amber = Color(0xFFD9A13B);
  static const amberInk = Color(0xFF9A6B12);
  static const amberSoft = Color(0xFFFFF6E8);
  static const ok = Color(0xFF12A05C);
}

class CourseTone {
  const CourseTone({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;

  factory CourseTone.fromHex(String hex) {
    final color = parseHex(hex);
    return CourseTone(
      background: Color.lerp(Colors.white, color, 0.14)!,
      border: Color.lerp(Colors.white, color, 0.32)!,
      foreground: Color.lerp(HuayanColors.ink, color, 0.78)!,
    );
  }
}

Color parseHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

ThemeData huayanTheme({String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: HuayanColors.blue,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: HuayanColors.bg,
    colorScheme: scheme.copyWith(
      primary: HuayanColors.blue,
      onPrimary: Colors.white,
      surface: HuayanColors.card,
      onSurface: HuayanColors.ink,
    ),
    dividerColor: HuayanColors.lineSoft,
    splashFactory: InkRipple.splashFactory,
  );
}
