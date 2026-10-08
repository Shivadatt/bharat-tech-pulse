import 'package:flutter/material.dart';
import '../../core/utils/date_formatter.dart';

class ArticleMetaWidget extends StatelessWidget {
  final String authorName;
  final DateTime date;
  final int readingTimeMinutes;
  final bool compact;

  const ArticleMetaWidget({
    super.key,
    required this.authorName,
    required this.date,
    required this.readingTimeMinutes,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ?? Colors.grey;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        if (!compact) ...[
          Text(
            authorName,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text('•', style: TextStyle(color: muted, fontSize: 12)),
        ],
        Text(
          DateFormatter.timeAgo(date),
          style: theme.textTheme.bodySmall,
        ),
        Text('•', style: TextStyle(color: muted, fontSize: 12)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 13, color: muted),
            const SizedBox(width: 4),
            Text(
              '$readingTimeMinutes min read',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
