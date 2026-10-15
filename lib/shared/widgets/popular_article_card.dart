import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/models/article_model.dart';
import 'article_meta_widget.dart';
import 'article_thumbnail.dart';

class PopularArticleCard extends StatelessWidget {
  final ArticleModel article;

  const PopularArticleCard({super.key, required this.article});

  static final NumberFormat _compact = NumberFormat.compact();

  /// `Colors.orange.shade700` measures 2.7:1 on the white light-mode card, so
  /// the label darkens there and keeps the original hue on the dark surface
  /// (6.2:1) instead of changing the accent itself.
  static Color _accent(Brightness brightness) => brightness == Brightness.dark
      ? Colors.orange.shade700
      : const Color(0xFFC2410C);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent(theme.brightness);

    return InkWell(
      onTap: () => Get.toNamed('/article/${article.slug}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: ArticleThumbnail(
                  url: article.featuredImage,
                  cacheWidth: 160,
                  cacheHeight: 160,
                  fallbackIcon: null,
                  semanticLabel: article.title,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          size: 14, color: accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${_compact.format(article.viewCount)} views',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
    );
  }
}
