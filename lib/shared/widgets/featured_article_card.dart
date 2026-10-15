import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/theme_colors.dart';
import '../../data/models/article_model.dart';
import '../responsive/responsive_breakpoints.dart';
import 'article_meta_widget.dart';
import 'article_thumbnail.dart';
import 'category_chip.dart';

class FeaturedArticleCard extends StatefulWidget {
  final ArticleModel article;

  const FeaturedArticleCard({super.key, required this.article});

  @override
  State<FeaturedArticleCard> createState() => _FeaturedArticleCardState();
}

class _FeaturedArticleCardState extends State<FeaturedArticleCard> {
  bool _isHovered = false;

  /// Brand saffron reads 2.1:1 against the white light-mode card, so the badge
  /// darkens to amber there and keeps the tricolour accent in dark mode.
  static Color _saffronOn(Brightness brightness) =>
      brightness == Brightness.dark
          ? AppColors.saffron
          : const Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = widget.article;
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: article.title,
        // GestureDetector adds no semantics node, so without this a
        // screen-reader user cannot discover the card as an activatable link.
        onTap: () => Get.toNamed('/article/${article.slug}'),
        child: GestureDetector(
          onTap: () => Get.toNamed('/article/${article.slug}'),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? theme.colorScheme.primary : theme.colorScheme.outline,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(_isHovered ? 40 : 15),
                blurRadius: _isHovered ? 24 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: isDesktop ? _buildDesktopLayout(theme, article) : _buildMobileLayout(theme, article),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, ArticleModel article) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArticleThumbnail(
                  url: article.featuredImage,
                  fallbackIcon: null,
                  semanticLabel: article.title,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withAlpha(120),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Semantics(
                      container: true,
                      button: true,
                      child: CategoryChip(
                        label: article.categoryName,
                        slug: article.categorySlug,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _saffronOn(theme.brightness).withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _saffronOn(theme.brightness),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'FEATURED STORY',
                          style: TextStyle(
                            color: _saffronOn(theme.brightness),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${article.readingTimeMinutes} min read',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    article.title,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _isHovered ? theme.colorScheme.primary : null,
                      height: 1.25,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    article.excerpt,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  ArticleMetaWidget(
                    authorName: article.author.name,
                    date: article.publishedAt,
                    readingTimeMinutes: article.readingTimeMinutes,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme, ArticleModel article) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ArticleThumbnail(
                url: article.featuredImage,
                fallbackIcon: null,
                semanticLabel: article.title,
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Align(
                alignment: Alignment.topLeft,
                child: Semantics(
                  container: true,
                  button: true,
                  child: CategoryChip(
                    label: article.categoryName,
                    slug: article.categorySlug,
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FEATURED STORY',
                style: TextStyle(
                  color: _saffronOn(theme.brightness),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  // The stacked layout is used below 1440px, where a tablet-width
                  // card looked under-typed at the default 18px.
                  fontSize: ResponsiveBreakpoints.isTablet(context) ? 22 : null,
                  fontWeight: FontWeight.bold,
                  color: _isHovered ? theme.colorScheme.primary : null,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}
