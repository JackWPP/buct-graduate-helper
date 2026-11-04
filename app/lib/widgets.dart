import 'dart:ui';

import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

class HuayanCard extends StatelessWidget {
  const HuayanCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A14171F),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: HuayanColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: HuayanColors.lineSoft),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: padding,
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class Subpage extends StatelessWidget {
  const Subpage({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    key: const Key('nav-back'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '返回',
                    icon: const HuayanIcon(
                      'back',
                      size: 18,
                      color: HuayanColors.ink,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HuayanColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: children,
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.title,
    required this.text,
    this.icon = Icons.description_outlined,
    this.glyph,
  });

  final String title;
  final String text;
  final IconData icon;
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          glyph == null
              ? Icon(icon, size: 36, color: HuayanColors.placeholder)
              : HuayanIcon(glyph!, size: 36, color: HuayanColors.placeholder),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: HuayanColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: HuayanColors.sub,
            ),
          ),
        ],
      ),
    );
  }
}

class KvRow extends StatelessWidget {
  const KvRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: HuayanColors.faint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: HuayanColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreditBar extends StatelessWidget {
  const CreditBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final width = fraction.isNaN ? 0.0 : fraction.clamp(0, 1).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            const ColoredBox(
              color: Color(0xFFE8EDF4),
              child: SizedBox.expand(),
            ),
            FractionallySizedBox(
              widthFactor: width,
              child: const ColoredBox(color: HuayanColors.blue),
            ),
          ],
        ),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: HuayanColors.ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class HuayanTabBar extends StatelessWidget {
  const HuayanTabBar({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (key: 'tab-home', icon: 'home', label: '首页'),
    (key: 'tab-timetable', icon: 'cal', label: '课表'),
    (key: 'tab-services', icon: 'grid', label: '服务'),
    (key: 'tab-me', icon: 'user', label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1414171F),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xF5FFFFFF),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: const Color(0xE6E6E9F0)),
            ),
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: _TabButton(
                          item: _items[i],
                          active: i == index,
                          onTap: () => onChanged(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final ({String key, String icon, String label}) item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : HuayanColors.faint;
    return Material(
      color: active ? HuayanColors.blue : Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        key: Key(item.key),
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HuayanIcon(item.icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
