import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  DeviceScreenType deviceType,
);

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context)? desktop;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context) mobile;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= ResponsiveBreakpoints.desktop && desktop != null) {
          return desktop!(context);
        }
        if (width >= ResponsiveBreakpoints.tablet && tablet != null) {
          return tablet!(context);
        }
        return mobile(context);
      },
    );
  }
}
