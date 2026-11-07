import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// 冷启动品牌页：比裸 spinner 更能说明当前在做什么。
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, this.message = '正在启动'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash-page'),
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SvgPicture.asset(
                  'assets/brand.svg',
                  width: 76,
                  height: 76,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '化研助手',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: HuayanColors.ink,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '北京化工大学 · 研究生管理系统',
                style: TextStyle(fontSize: 12, color: HuayanColors.sub),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                key: const Key('splash-message'),
                style: const TextStyle(fontSize: 13, color: HuayanColors.sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页骨架屏：缓存尚未读出或首次刷新时占位。
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home-skeleton'),
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          children: const [
            _SkeletonLine(width: 160, height: 20),
            SizedBox(height: 12),
            _SkeletonLine(width: 230, height: 14),
            SizedBox(height: 22),
            _SkeletonCard(height: 150),
            SizedBox(height: 14),
            _SkeletonCard(height: 118),
            SizedBox(height: 14),
            _SkeletonCard(height: 96),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HuayanColors.lineSoft,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: HuayanColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HuayanColors.lineSoft),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonLine(width: 130, height: 14),
          const SizedBox(height: 14),
          const _SkeletonLine(width: double.infinity, height: 12),
          const SizedBox(height: 9),
          const _SkeletonLine(width: 210, height: 12),
          const Spacer(),
          Row(
            children: const [
              _SkeletonLine(width: 54, height: 24),
              SizedBox(width: 8),
              _SkeletonLine(width: 54, height: 24),
            ],
          ),
        ],
      ),
    );
  }
}
