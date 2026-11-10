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

const appVersionLabel = '1.7.1';

ThemeData huayanTheme({String? fontFamily}) {
  final family = fontFamily ?? 'Noto Sans SC';
  final scheme = ColorScheme.fromSeed(
    seedColor: HuayanColors.blue,
    brightness: Brightness.light,
  );
  final buttonText = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: family,
    scaffoldBackgroundColor: HuayanColors.bg,
    colorScheme: scheme.copyWith(
      primary: HuayanColors.blue,
      onPrimary: Colors.white,
      surface: HuayanColors.card,
      onSurface: HuayanColors.ink,
    ),
    dividerColor: HuayanColors.lineSoft,
    splashFactory: InkRipple.splashFactory,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HuayanColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: family,
        fontSize: 14,
        color: Colors.white,
      ),
      actionTextColor: const Color(0xFF9DB8FF),
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        backgroundColor: HuayanColors.blue,
        foregroundColor: Colors.white,
        textStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: HuayanPageTransitionsBuilder(),
        TargetPlatform.iOS: HuayanPageTransitionsBuilder(),
        TargetPlatform.linux: HuayanPageTransitionsBuilder(),
        TargetPlatform.macOS: HuayanPageTransitionsBuilder(),
        TargetPlatform.windows: HuayanPageTransitionsBuilder(),
        TargetPlatform.fuchsia: HuayanPageTransitionsBuilder(),
      },
    ),
  );
}

class HuayanPageTransitionsBuilder extends PageTransitionsBuilder {
  const HuayanPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

Route<T> huayanRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
