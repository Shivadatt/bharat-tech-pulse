import 'package:flutter/material.dart';
import '../../app/theme/theme_colors.dart';
import '../responsive/responsive_breakpoints.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stackAction = ResponsiveBreakpoints.isMobileSmall(context);

    final headingRow = Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
        ],
        // A non-flexible Row child is measured with unbounded width, so the
        // heading can never give space to the action button and overflows the
        // row on narrow phones.
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ],
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headingRow,
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );

    final action = actionLabel != null && onActionTap != null
        ? TextButton.icon(
            onPressed: onActionTap,
            style: stackAction
                ? TextButton.styleFrom(padding: const EdgeInsets.only(right: 12))
                : null,
            // TextButton.icon lays its children in a `MainAxisSize.min` Row, and
            // a Row measures non-flex children with unbounded width, so this
            // label could never shrink: at 2x text scale it needed 447px inside
            // the 268px left over on a 320px phone and overflowed. Clamping the
            // label itself makes it ellipsize instead, and changes nothing on
            // any viewport where the text already fits.
            icon: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.55,
              ),
              child: Text(
                actionLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.linkText(theme.brightness),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            label: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          )
        : null;

    // A 13px 'View All News' button plus an 18px heading cannot share one line
    // under 480px, so the link drops below the heading instead of squeezing it.
    if (action != null && stackAction) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            action,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: titleBlock),
          ?action,
        ],
      ),
    );
  }
}
