import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/article_model.dart';
import 'article_meta_widget.dart';

class CompactArticleCard extends StatelessWidget {
  final ArticleModel article;

  const CompactArticleCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => Get.toNamed('/article/${article.slug}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 90,
                height: 70,
                child: Image.network(
                  article.featuredImage,
                  fit: BoxFit.cover,
                  cacheWidth: 180,
                  cacheHeight: 140,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: theme.colorScheme.surface),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
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
