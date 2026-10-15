import 'package:flutter/material.dart';

/// Circular author avatar with an initials fallback.
/// CircleAvatar rethrows a failed `backgroundImage` load when
/// `onBackgroundImageError` is null, and an empty avatarUrl fails instantly,
/// which blanked the whole page for any author without a picture.
class AuthorAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final double radius;

  const AuthorAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withAlpha(50),
      child: Text(
        _initialsFor(name),
        style: TextStyle(
          fontSize: (radius * 0.7).clamp(11.0, 22.0),
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );

    final url = avatarUrl.trim();
    if (url.isEmpty) return fallback;

    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: theme.colorScheme.primary.withAlpha(50),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }

  static String _initialsFor(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w.substring(0, 1).toUpperCase()).join();
  }
}
