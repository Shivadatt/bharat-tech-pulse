import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/config/site_config.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/article_model.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/components/newsletter_card.dart';
import '../../../shared/components/section_header.dart';
import '../../../shared/layouts/content_with_sidebar.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_container.dart';
import '../../../shared/responsive/responsive_grid.dart';
import '../../../shared/skeletons/error_state.dart';
import '../../../shared/skeletons/loading_skeleton.dart';
import '../../../shared/widgets/article_card.dart';
import '../../../shared/widgets/author_info_widget.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/popular_article_card.dart';
import '../../../shared/widgets/share_buttons_widget.dart';
import '../../../shared/widgets/trending_card.dart';
import '../controllers/article_controller.dart';

class ArticleView extends GetView<ArticleController> {
  const ArticleView({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicScaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const _ArticleLoadingView();
        }

        if (controller.errorMessage.value.isNotEmpty || controller.article.value == null) {
          return ErrorState(
            title: 'Article Not Found',
            message: controller.errorMessage.value.isNotEmpty
                ? controller.errorMessage.value
                : 'The requested article could not be loaded.',
            onRetry: () => controller.loadArticle(controller.currentSlug),
          );
        }

        final article = controller.article.value!;
        final articleUrl = '${SiteConfig.domain}/article/${article.slug}';

        return ResponsiveContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb
              BreadcrumbWidget(
                items: [
                  BreadcrumbItem(
                    label: article.categoryName,
                    route: '/${article.categorySlug}/',
                  ),
                  BreadcrumbItem(label: article.title),
                ],
              ),
              const SizedBox(height: 16),

              // Layout with sidebar
              ContentWithSidebar(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    CategoryChip(
                      label: article.categoryName,
                      slug: article.categorySlug,
                    ),
                    const SizedBox(height: 14),

                    // H1 Title
                    Text(
                      article.title,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Excerpt / Deck
                    Text(
                      article.excerpt,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 20),

                    // Author + Published/Updated Meta Row
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(article.author.avatarUrl),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => Get.toNamed('/author/${article.author.slug}'),
                              child: Text(
                                article.author.name,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Text(
                              'Published: ${DateFormatter.formatEditorial(article.publishedAt)} • Updated: ${DateFormatter.formatEditorial(article.updatedAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        ShareButtonsWidget(title: article.title, url: articleUrl),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Hero Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          article.featuredImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: const Icon(Icons.image, size: 50),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Key Takeaways Box
                    if (article.keyTakeaways.isNotEmpty) ...[
                      _KeyTakeawaysBox(takeaways: article.keyTakeaways),
                      const SizedBox(height: 32),
                    ],

                    // Main Article Body Content
                    _ArticleBodyContent(content: article.content),
                    const SizedBox(height: 36),

                    // FAQ Section
                    if (article.faqs.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 24),
                      Text(
                        'Frequently Asked Questions',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      for (final faq in article.faqs) ...[
                        _FaqCard(faq: faq),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 24),
                    ],

                    // Tags
                    if (article.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text('Topics: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          for (final tag in article.tags)
                            Chip(
                              label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                              backgroundColor: Theme.of(context).colorScheme.surface,
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Share Bar
                    ShareButtonsWidget(title: article.title, url: articleUrl),
                    const SizedBox(height: 36),

                    // Author Box
                    AuthorInfoWidget(author: article.author),
                    const SizedBox(height: 48),

                    // Related Articles
                    if (controller.relatedArticles.isNotEmpty) ...[
                      SectionHeader(
                        title: 'Related Stories',
                        icon: Icons.auto_awesome_mosaic_rounded,
                      ),
                      ResponsiveGrid(
                        desktopColumns: 2,
                        tabletColumns: 2,
                        mobileColumns: 1,
                        children: controller.relatedArticles
                            .map((a) => ArticleCard(article: a))
                            .toList(),
                      ),
                    ],
                  ],
                ),
                sidebar: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table of Contents
                    if (article.toc.isNotEmpty) ...[
                      _TocSidebarWidget(toc: article.toc),
                      const SizedBox(height: 32),
                    ],

                    // Trending
                    SectionHeader(
                      title: 'Trending',
                      icon: Icons.trending_up_rounded,
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < controller.trendingArticles.length; i++) ...[
                            TrendingCard(
                              rank: i + 1,
                              article: controller.trendingArticles[i],
                            ),
                            if (i < controller.trendingArticles.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Most Read
                    SectionHeader(
                      title: 'Most Read',
                      icon: Icons.local_fire_department_rounded,
                    ),
                    ...controller.popularArticles
                        .map((a) => PopularArticleCard(article: a)),
                    const SizedBox(height: 32),

                    // Newsletter
                    const NewsletterCard(compact: true),
                  ],
                ),
              ),
              const SizedBox(height: 56),
            ],
          ),
        );
      }),
    );
  }
}

class _KeyTakeawaysBox extends StatelessWidget {
  final List<String> takeaways;

  const _KeyTakeawaysBox({required this.takeaways});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(60),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Key Takeaways',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in takeaways)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      )),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ArticleBodyContent extends StatelessWidget {
  final String content;

  const _ArticleBodyContent({required this.content});

  static final RegExp _numberedLine = RegExp(r'^\d+\.\s+');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.8,
      fontSize: 16.5,
    );
    final paragraphs = content.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((p) {
        final trimmed = p.trim();
        if (trimmed.startsWith('### ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Text(
              trimmed.substring(4),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
          );
        } else if (trimmed.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 14),
            child: Text(
              trimmed.substring(3),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else {
          final lines = trimmed.split('\n');
          final isNumberedList =
              lines.every((l) => _numberedLine.hasMatch(l.trim()));

          if (isNumberedList) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildNumberedLine(line.trim(), bodyStyle),
                    ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildInlineText(trimmed, bodyStyle),
          );
        }
      }).toList(),
    );
  }

  Widget _buildNumberedLine(String line, TextStyle? style) {
    final match = _numberedLine.firstMatch(line);
    final marker = match?.group(0) ?? '';
    final rest = marker.isEmpty ? line : line.substring(marker.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            marker.trim(),
            maxLines: 1,
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: _buildInlineText(rest, style)),
      ],
    );
  }

  /// Renders **bold** spans without a markdown package; unpaired markers
  /// render as literal text.
  Widget _buildInlineText(String text, TextStyle? style) {
    final parts = text.split('**');
    // An even part count means the '**' markers are unpaired — render them
    // as literal text instead of bolding a stray tail segment.
    if (parts.length == 1 || parts.length.isEven) {
      return Text(text, style: style);
    }
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
        ],
      ),
      style: style,
    );
  }
}

class _FaqCard extends StatelessWidget {
  final ArticleFaq faq;

  const _FaqCard({required this.faq});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            faq.question,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            faq.answer,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TocSidebarWidget extends StatelessWidget {
  final List<ArticleTocItem> toc;

  const _TocSidebarWidget({required this.toc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_bulleted_rounded,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Table of Contents',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in toc)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.arrow_right_rounded,
                      size: 16, color: theme.colorScheme.primary),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ArticleLoadingView extends StatelessWidget {
  const _ArticleLoadingView();

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          LoadingSkeleton(width: 150, height: 16),
          SizedBox(height: 20),
          LoadingSkeleton(height: 38),
          SizedBox(height: 12),
          LoadingSkeleton(width: 400, height: 20),
          SizedBox(height: 24),
          LoadingSkeleton(height: 400, borderRadius: 16),
          SizedBox(height: 24),
          LoadingSkeleton(height: 120),
        ],
      ),
    );
  }
}
