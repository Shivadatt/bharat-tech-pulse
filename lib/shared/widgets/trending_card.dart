import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/theme_colors.dart';
import '../../data/models/article_model.dart';
import 'article_meta_widget.dart';

class TrendingCard extends StatelessWidget {
  final int rank;
  final ArticleModel article;

  const TrendingCard({
    super.key,
    required this.rank,
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankString = rank.toString().padLeft(2, '0');

    return InkWell(
      onTap: () => Get.toNamed('/article/${article.slug}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rankString,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                // The alpha wash measured 1.80:1 on white and 2.54:1 on the
                // dark card, under even the 3:1 large-text floor.
                color: theme.colorScheme.primary,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.categoryName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.linkText(theme.brightness),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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
