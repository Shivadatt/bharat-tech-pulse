import 'package:flutter/material.dart';

/// Renders the standard loading / error / empty / data states for a CMS panel,
/// collapsing the repeated boilerplate across admin views.
class AdminStateView extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final bool isEmpty;
  final String emptyMessage;
  final VoidCallback? onRetry;
  final Widget child;

  const AdminStateView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.isEmpty,
    required this.emptyMessage,
    required this.child,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return _Message(
        icon: Icons.error_outline_rounded,
        color: Colors.red,
        text: error!,
        actionLabel: onRetry == null ? null : 'Retry',
        onAction: onRetry,
      );
    }
    if (isEmpty) {
      return _Message(
        icon: Icons.inbox_outlined,
        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
        text: emptyMessage,
      );
    }
    return child;
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.color,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
