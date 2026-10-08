import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ShareButtonsWidget extends StatelessWidget {
  final String title;
  final String url;

  const ShareButtonsWidget({
    super.key,
    required this.title,
    required this.url,
  });

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: url));
    Get.snackbar(
      'Link Copied',
      'Article link copied to your clipboard!',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: Theme.of(context).cardColor,
      colorText: Theme.of(context).textTheme.bodyMedium?.color,
      margin: const EdgeInsets.all(16),
      maxWidth: 400,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Share:',
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        _ShareIconButton(
          icon: Icons.link_rounded,
          tooltip: 'Copy Link',
          onTap: () => _copyLink(context),
        ),
        _ShareIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Share on WhatsApp',
          onTap: () => _copyLink(context),
        ),
        _ShareIconButton(
          icon: Icons.send_rounded,
          tooltip: 'Share on Telegram',
          onTap: () => _copyLink(context),
        ),
        _ShareIconButton(
          icon: Icons.share_rounded,
          tooltip: 'Share',
          onTap: () => _copyLink(context),
        ),
      ],
    );
  }
}

class _ShareIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ShareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}
