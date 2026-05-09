import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// A single shimmering box — the base building block for all skeletons.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps children in a Shimmer gradient sweep.
class ShimmerWrapper extends StatelessWidget {
  final Widget child;
  const ShimmerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEDE9FE),
      highlightColor: const Color(0xFFF5F3FF),
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Skeleton for a horizontal library book card (165 × 300).
class ShimmerBookCard extends StatelessWidget {
  const ShimmerBookCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        width: 165,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primarySurface, width: 2),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: double.infinity, height: 10, radius: 6),
                  const SizedBox(height: 6),
                  ShimmerBox(width: 80, height: 10, radius: 6),
                  const SizedBox(height: 8),
                  ShimmerBox(width: double.infinity, height: 7, radius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scroll of shimmer book cards — drops in where the real list goes.
class ShimmerBookScroll extends StatelessWidget {
  final int count;
  const ShimmerBookScroll({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const ShimmerBookCard(),
      ),
    );
  }
}

/// Shimmer for a leaderboard row.
class ShimmerLeaderRow extends StatelessWidget {
  const ShimmerLeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primarySurface, width: 1.5),
        ),
        child: Row(children: [
          ShimmerBox(width: 36, height: 36, radius: 10),
          const SizedBox(width: 8),
          ShimmerBox(width: 42, height: 42, radius: 21),
          const SizedBox(width: 12),
          Expanded(child: ShimmerBox(width: double.infinity, height: 14, radius: 7)),
          const SizedBox(width: 16),
          ShimmerBox(width: 48, height: 14, radius: 7),
        ]),
      ),
    );
  }
}

/// A column of N shimmer leaderboard rows.
class ShimmerLeaderList extends StatelessWidget {
  final int count;
  const ShimmerLeaderList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const ShimmerLeaderRow(),
    );
  }
}

/// Shimmer for a profile stat card pair.
class ShimmerStatCards extends StatelessWidget {
  const ShimmerStatCards({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Row(children: [
        Expanded(
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primarySurface, width: 1.5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primarySurface, width: 1.5),
            ),
          ),
        ),
      ]),
    );
  }
}
