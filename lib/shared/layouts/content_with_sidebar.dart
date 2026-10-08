import 'package:flutter/material.dart';
import '../../app/config/app_constants.dart';
import '../responsive/responsive_breakpoints.dart';

class ContentWithSidebar extends StatelessWidget {
  final Widget content;
  final Widget sidebar;
  final double sidebarWidth;

  const ContentWithSidebar({
    super.key,
    required this.content,
    required this.sidebar,
    this.sidebarWidth = AppConstants.sidebarWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 36),
          sidebar,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: content),
        const SizedBox(width: 40),
        SizedBox(
          width: sidebarWidth,
          child: sidebar,
        ),
      ],
    );
  }
}
