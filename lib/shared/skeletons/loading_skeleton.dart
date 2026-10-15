import 'package:flutter/material.dart';

/// Shimmer-like loading skeleton placeholder.
class LoadingSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final wanted = width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // Call sites ask for a nominal width (a 400px bar, a 200px bar). On a
        // 320-375px phone that overflows its slot, so the request is a
        // preference and never a hard size.
        final clamped = wanted == null ||
                !available.isFinite ||
                wanted <= available
            ? wanted
            : available;
        return Container(
          width: clamped,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );
      },
    );
  }
}

class ArticleCardSkeleton extends StatelessWidget {
  const ArticleCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        LoadingSkeleton(height: 180, borderRadius: 12),
        SizedBox(height: 12),
        LoadingSkeleton(width: 80, height: 16),
        SizedBox(height: 8),
        LoadingSkeleton(height: 22),
        SizedBox(height: 6),
        LoadingSkeleton(width: 200, height: 14),
      ],
    );
  }
}
