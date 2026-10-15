import 'package:flutter/material.dart';

/// Shared card/hero thumbnail.
/// A draft or seeded article can carry an empty `featuredImage`, and
/// `Image.network('')` only surfaces that through the async error path, so the
/// placeholder is chosen before any network resolve is attempted.
class ArticleThumbnail extends StatelessWidget {
  final String url;
  final int? cacheWidth;
  final int? cacheHeight;

  /// Pass `null` for the small thumbnails that read better as a flat fill.
  final IconData? fallbackIcon;

  const ArticleThumbnail({
    super.key,
    required this.url,
    this.cacheWidth,
    this.cacheHeight,
    this.fallbackIcon = Icons.broken_image_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surface,
      child: fallbackIcon == null
          ? null
          : Icon(fallbackIcon, size: 40),
    );

    final trimmed = url.trim();
    if (trimmed.isEmpty) return placeholder;

    return Image.network(
      trimmed,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
