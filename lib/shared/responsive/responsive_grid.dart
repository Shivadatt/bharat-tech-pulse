import 'package:flutter/material.dart';

/// Highly adaptive responsive grid that automatically adjusts column counts
/// without overflow across 375px to 1440px+ viewports.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int desktopColumns;
  final int tabletColumns;
  final int mobileColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 20.0,
    this.runSpacing = 20.0,
    this.desktopColumns = 3,
    this.tabletColumns = 2,
    this.mobileColumns = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int cols;
        if (width >= 1024) {
          cols = desktopColumns;
        } else if (width >= 560) {
          // 650 here compared a *slot* width to a *screen* constant: the
          // sidebar layout's content slot at 1024 is 1024-40-380 = 604, so the
          // rail collapsed to one 604px card while the sections beside it
          // showed three 315px cards.
          cols = tabletColumns;
        } else {
          cols = mobileColumns;
        }

        final itemWidth = (width - ((cols - 1) * spacing)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}
