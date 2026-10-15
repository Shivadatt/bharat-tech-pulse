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

  /// [via] names the destination the visitor pressed. Nothing here can open
  /// WhatsApp or Telegram - that would mean a `url_launcher` dependency and a
  /// popup the browser may block - so the label and the confirmation tell the
  /// truth about what actually happened: the link is on the clipboard.
  void _copyLink(BuildContext context, {String? via}) {
    Clipboard.setData(ClipboardData(text: url));
    Get.snackbar(
      'Link Copied',
      via == null
          ? 'Article link copied to your clipboard!'
          : 'Link copied — paste it in $via to share.',
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
          tooltip: 'Copy link to share on WhatsApp',
          onTap: () => _copyLink(context, via: 'WhatsApp'),
        ),
        _ShareIconButton(
          icon: Icons.send_rounded,
          tooltip: 'Copy link to share on Telegram',
          onTap: () => _copyLink(context, via: 'Telegram'),
        ),
        _ShareIconButton(
          icon: Icons.share_rounded,
          tooltip: 'Copy link to share elsewhere',
          onTap: () => _copyLink(context, via: 'your app of choice'),
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
        // 8px of padding around a 16px icon only gives a 32px target, under the
        // 40px mobile minimum; the box is sized instead of padded.
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(icon, size: 16, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
