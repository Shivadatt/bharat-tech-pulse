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
import '../../../shared/responsive/responsive_breakpoints.dart';
import '../../../shared/responsive/responsive_container.dart';
import '../../../shared/responsive/responsive_grid.dart';
import '../../../shared/skeletons/error_state.dart';
import '../../../shared/skeletons/loading_skeleton.dart';
import '../../../shared/widgets/article_card.dart';
import '../../../shared/widgets/article_thumbnail.dart';
import '../../../shared/widgets/author_avatar.dart';
import '../../../shared/widgets/author_info_widget.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/popular_article_card.dart';
import '../../../shared/widgets/share_buttons_widget.dart';
import '../../../shared/widgets/trending_card.dart';
import '../controllers/article_controller.dart';

class ArticleView extends StatefulWidget {
  const ArticleView({super.key});

  @override
  State<ArticleView> createState() => _ArticleViewState();
}

class _ArticleViewState extends State<ArticleView> {
  ArticleController get controller => Get.find<ArticleController>();

  @override
  void initState() {
    super.initState();
    // GetX keeps the type-keyed controller alive across article routes, so a
    // reader moving article-to-article gets a fresh widget on a stale instance.
    controller.ensureCurrentRouteLoaded();
  }

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
        final compact = ResponsiveBreakpoints.isMobileSmall(context);

        return ResponsiveContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb
              BreadcrumbWidget(
                items: [
                  // A category row dropped by RLS leaves an empty slug, and
                  // `//' is not a route: the crumb would navigate to the 404.
                  if (article.categorySlug.isNotEmpty)
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
                    Semantics(
                      header: true,
                      child: Text(
                        article.title,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: compact ? 24 : null,
                              fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.2,
                          ),
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
                        AuthorAvatar(
                          name: article.author.name,
                          avatarUrl: article.author.avatarUrl,
                          radius: 20,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              // An `authors` embed dropped by RLS (archived
                              // byline) leaves an empty slug; `/author/` is not
                              // a cold-boot path and lands on the 404 route.
                              onTap: article.author.slug.isEmpty
                                  ? null
                                  : () => Get.toNamed(
                                      '/author/${article.author.slug}'),
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
                      child: ConstrainedBox(
                        // A 16:9 box sized only by column width swamps the
                        // article in short landscape viewports; capping it at
                        // 45% of viewport height keeps the byline on screen.
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ArticleThumbnail(
                            url: article.featuredImage,
                            fallbackIcon: Icons.image,
                            // Without a decode size a 5000px-wide source is
                            // rasterised at native resolution on every article.
                            cacheWidth: 1200,
                            semanticLabel: article.title,
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
              Expanded(
                child: Text(
                  'Key Takeaways',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
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
  static final RegExp _bulletLine = RegExp(r'^[-*]\s+(.+)$');

  /// Paired `**bold**` and `` `code` `` markers in one pass; anything that does
  /// not match stays literal, mirroring the prerenderer's `renderInline`.
  static final RegExp _inlineMarkers = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.8,
      fontSize: 16.5,
    );

    // Fenced code blocks survive paragraph splitting: odd segments of a
    // ``` split are code, even segments keep the normal block rules. A final
    // odd segment means the fence was never closed, so it stays plain text
    // rather than being rendered as a code panel.
    final normalized = content.replaceAll('\r\n', '\n');
    final segments = normalized.split('```');
    final blocks = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i.isOdd && i < segments.length - 1) {
        blocks.add(_buildCodeBlock(context, segments[i]));
        continue;
      }
      for (final p in segments[i].split('\n\n')) {
        final trimmed = p.trim();
        if (trimmed.isEmpty) continue;
        blocks.add(_buildBlock(context, trimmed, theme, bodyStyle));
      }
    }

    // CanvasKit paints text to a canvas, so without a SelectionArea bound of
    // an article on web cannot highlight or copy a passage.
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      ),
    );
  }

  Widget _buildBlock(
    BuildContext context,
    String trimmed,
    ThemeData theme,
    TextStyle? bodyStyle,
  ) {
    if (trimmed.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Semantics(
          header: true,
          child: Text(
            trimmed.substring(4),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
        ),
      );
    } else if (trimmed.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 14),
        child: Semantics(
          header: true,
          child: Text(
            trimmed.substring(3),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else if (trimmed.startsWith('# ')) {
      // The prerenderer maps a lone `#` to a section heading too; without this
      // branch the app would print the literal marker and diverge from it.
      return Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 14),
        child: Semantics(
          header: true,
          child: Text(
            trimmed.substring(2),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

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
                child: _buildNumberedLine(context, line.trim(), bodyStyle),
              ),
          ],
        ),
      );
    }

    // Match the prerenderer: a bullet list only when every line of a multi-line
    // block starts with `- ` or `* `; a stray single bullet stays a paragraph.
    final isBulletList = lines.length > 1 &&
        lines.every((l) => _bulletLine.hasMatch(l.trim()));

    if (isBulletList) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildBulletLine(context, line.trim(), theme, bodyStyle),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildInlineText(context, trimmed, bodyStyle),
    );
  }

  Widget _buildNumberedLine(
    BuildContext context,
    String line,
    TextStyle? style,
  ) {
    final match = _numberedLine.firstMatch(line);
    final marker = match?.group(0) ?? '';
    final rest = marker.isEmpty ? line : line.substring(marker.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A fixed 34px box clips two-digit markers ("10.") and anything wider
        // under large text scales; the floor keeps single digits aligned.
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 34),
          child: Text(
            marker.trim(),
            maxLines: 1,
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: _buildInlineText(context, rest, style)),
      ],
    );
  }

  Widget _buildBulletLine(
    BuildContext context,
    String line,
    ThemeData theme,
    TextStyle? style,
  ) {
    final match = _bulletLine.firstMatch(line);
    final rest = match?.group(1) ?? line;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Expanded(child: _buildInlineText(context, rest, style)),
      ],
    );
  }

  /// A ``` block renders as a scrollable monospace panel: lines never wrap or
  /// overflow the column, they scroll sideways instead.
  Widget _buildCodeBlock(BuildContext context, String raw) {
    final theme = Theme.of(context);
    var body = raw;
    // Drop the fence's info string (```json) when the first line is just a
    // bare token, plus the single trailing newline the closing fence leaves.
    final cut = body.indexOf('\n');
    if (cut != -1 &&
        RegExp(r'^[A-Za-z0-9+#._-]*$').hasMatch(body.substring(0, cut).trim())) {
      body = body.substring(cut + 1);
    }
    if (body.endsWith('\n')) body = body.substring(0, body.length - 1);

    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          body,
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Courier New', 'Consolas'],
            fontSize: 14,
            height: 1.6,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  /// Renders **bold** and `code` spans without a markdown package; unpaired
  /// markers render as literal text.
  Widget _buildInlineText(
    BuildContext context,
    String text,
    TextStyle? style,
  ) {
    final theme = Theme.of(context);
    final children = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineMarkers.allMatches(text)) {
      if (m.start > last) {
        children.add(TextSpan(text: text.substring(last, m.start)));
      }
      final bold = m.group(1);
      if (bold != null) {
        children.add(
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else {
        children.add(TextSpan(
          text: m.group(2),
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: const ['Courier New', 'Consolas'],
            fontSize: 14.5,
            backgroundColor: theme.brightness == Brightness.dark
                ? const Color(0xFF111827)
                : const Color(0xFFF1F5F9),
          ),
        ));
      }
      last = m.end;
    }
    // Nothing matched — keep the plain Text node the old renderer produced.
    if (children.isEmpty) return Text(text, style: style);
    if (last < text.length) {
      children.add(TextSpan(text: text.substring(last)));
    }
    return Text.rich(
      TextSpan(children: children),
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
              Expanded(
                child: Text(
                  'Table of Contents',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
