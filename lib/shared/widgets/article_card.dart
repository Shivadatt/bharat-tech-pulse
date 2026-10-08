import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/article_model.dart';
import 'article_meta_widget.dart';
import 'category_chip.dart';

class ArticleCard extends StatefulWidget {
  final ArticleModel article;

  const ArticleCard({super.key, required this.article});

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = widget.article;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Get.toNamed('/article/${article.slug}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? theme.colorScheme.primary : theme.colorScheme.outline,
              width: 1.2,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ]
                : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      article.featuredImage,
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      cacheHeight: 450,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: theme.colorScheme.surface,
                        child: const Icon(Icons.broken_image_rounded, size: 40),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: CategoryChip(
                      label: article.categoryName,
                      slug: article.categorySlug,
                    ),
                  ),
                ],
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isHovered ? theme.colorScheme.primary : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.excerpt,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    ArticleMetaWidget(
                      authorName: article.author.name,
                      date: article.publishedAt,
                      readingTimeMinutes: article.readingTimeMinutes,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
