import 'package:flutter/material.dart';

class NewsletterCard extends StatefulWidget {
  final bool compact;

  const NewsletterCard({super.key, this.compact = false});

  @override
  State<NewsletterCard> createState() => _NewsletterCardState();
}

class _NewsletterCardState extends State<NewsletterCard> {
  final _emailController = TextEditingController();
  bool _isSubscribed = false;

  void _handleSubscribe() {
    if (_emailController.text.contains('@')) {
      setState(() => _isSubscribed = true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(widget.compact ? 20 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF151D2E), const Color(0xFF0F172A)]
              : [const Color(0xFFF1F5F9), const Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(50),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mail_outline_rounded,
                    color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bharat Tech Weekly',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Get curated AI developments, scam alerts, and top gadget reviews delivered to your inbox every Sunday. Zero spam.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_isSubscribed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22C55E)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Welcome to Bharat Tech Weekly! Check your inbox to confirm.',
                      style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Enter your email address',
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubscribe,
                child: const Text('Subscribe for Free'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
