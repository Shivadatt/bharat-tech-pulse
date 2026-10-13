import '../../app/config/site_config.dart';
import '../../data/models/article_model.dart';
import '../../data/models/category_model.dart';
import 'seo_schema.dart';

/// The single source of truth for *what* SEO metadata a route exposes:
/// final `<title>`, description, absolute canonical, absolute `og:image`,
/// `og:type`, the JSON-LD graph and the extra `article:*` / `author` tags.
///
/// Two consumers must agree on every field:
///  * `SeoService` at runtime (Googlebot, which executes JavaScript), and
///  * `tool/generate_prerender.dart`, which bakes the same values into the
///    static shells served to crawlers that never run JavaScript.
///
/// Before this class existed the prerenderer recomputed those rules by hand and
/// the two paths drifted (title-suffix rule, canonical precedence, JSON-LD
/// `keywords`). Keeping it free of `flutter/` and `package:get` imports is what
/// lets `dart run tool/generate_prerender.dart` share the logic.
class SeoMeta {
  /// Final document title, already site-name-suffixed if needed.
  final String title;

  /// Meta description (never empty; falls back to the site description).
  final String description;

  /// Absolute canonical URL written to `<link rel="canonical">`, `og:url`
  /// and the JSON-LD `url`/`@id`.
  final String canonicalUrl;

  /// Absolute `og:image` / `twitter:image` URL.
  final String ogImage;

  /// `og:type` value: `website`, `article`, …
  final String ogType;

  /// The JSON-LD document for this route (never null — see [page]).
  final Map<String, dynamic> jsonLd;

  /// Extra `property=` meta tags (article:published_time, …).
  final Map<String, String> properties;

  /// Extra `name=` meta tags (author, …).
  final Map<String, String> names;

  const SeoMeta._({
    required this.title,
    required this.description,
    required this.canonicalUrl,
    required this.ogImage,
    required this.ogType,
    required this.jsonLd,
    required this.properties,
    required this.names,
  });

  /// Generic route: a hand-supplied title/description/canonical.
  ///
  /// [canonicalUrl] wins over [canonicalPath] so a stored `canonical_url`
  /// that differs from the derived path is honoured exactly as the runtime
  /// honours it. When no page-specific graph is supplied the sitewide
  /// Organization + WebSite graph is used, so every route carries exactly one
  /// structured-data document and no route ever loses it.
  factory SeoMeta.page({
    required String title,
    String? description,
    String? canonicalPath,
    String? canonicalUrl,
    String? ogImage,
    String ogType = 'website',
    Map<String, dynamic>? jsonLd,
    Map<String, String> properties = const {},
    Map<String, String> names = const {},
  }) {
    return SeoMeta._(
      title: withSiteName(title),
      description: (description == null || description.isEmpty)
          ? SiteConfig.description
          : description,
      canonicalUrl: canonicalUrl != null && canonicalUrl.isNotEmpty
          ? canonicalUrl
          : (canonicalPath == null || canonicalPath.isEmpty
              ? '${SiteConfig.domain}/'
              : '${SiteConfig.domain}$canonicalPath'),
      ogImage: resolveImage(ogImage),
      ogType: ogType,
      jsonLd: jsonLd ?? SeoSchema.siteGraph(),
      properties: properties,
      names: names,
    );
  }

  /// Article route: everything the app shows for a loaded [ArticleModel].
  factory SeoMeta.forArticle(ArticleModel art) {
    final url = art.canonicalUrl.isNotEmpty
        ? art.canonicalUrl
        : '${SiteConfig.domain}/article/${art.slug}';
    final description = art.seoDescription.isNotEmpty ? art.seoDescription : art.excerpt;
    return SeoMeta._(
      title: withSiteName(art.seoTitle.isNotEmpty ? art.seoTitle : art.title),
      description: description.isEmpty ? SiteConfig.description : description,
      canonicalUrl: url,
      ogImage: resolveImage(art.ogImage.isNotEmpty ? art.ogImage : art.featuredImage),
      ogType: 'article',
      jsonLd: SeoSchema.articleGraph(
        title: art.title,
        description: description,
        url: url,
        imageUrl: resolveImage(art.ogImage.isNotEmpty ? art.ogImage : art.featuredImage),
        authorName: art.author.name,
        authorUrl: art.author.slug.isNotEmpty
            ? '${SiteConfig.domain}/author/${art.author.slug}'
            : null,
        publishedAt: art.publishedAt,
        modifiedAt: art.updatedAt,
        categoryName: art.categoryName,
        categorySlug: art.categorySlug,
        keywords: art.tags,
        faqs: art.faqs
            .map((f) => <String, String>{'question': f.question, 'answer': f.answer})
            .toList(),
        readingMinutes: art.readingTimeMinutes,
      ),
      properties: <String, String>{
        'article:published_time': art.publishedAt.toUtc().toIso8601String(),
        'article:modified_time': art.updatedAt.toUtc().toIso8601String(),
        'article:section': art.categoryName,
      },
      names: <String, String>{'author': art.author.name},
    );
  }

  /// Category route: CollectionPage + breadcrumb for a loaded [CategoryModel].
  factory SeoMeta.forCategory(CategoryModel cat) {
    final url = '${SiteConfig.domain}/${cat.slug}/';
    final description =
        cat.seoDescription.isNotEmpty ? cat.seoDescription : cat.description;
    return SeoMeta._(
      title: withSiteName(
          cat.seoTitle.isNotEmpty ? cat.seoTitle : '${cat.name} — ${SiteConfig.siteName}'),
      description: description.isEmpty ? SiteConfig.description : description,
      canonicalUrl: url,
      ogImage: resolveImage(cat.imageUrl.isNotEmpty ? cat.imageUrl : null),
      ogType: 'website',
      jsonLd: SeoSchema.categoryGraph(
        name: cat.name,
        slug: cat.slug,
        description: description,
        url: url,
      ),
      properties: const {},
      names: const {},
    );
  }

  /// Appends " | Bharat Tech Pulse" unless the title already carries the brand,
  /// so "AI — Bharat Tech Pulse" never becomes "AI — Bharat Tech Pulse | Bharat
  /// Tech Pulse".
  static String withSiteName(String title) =>
      title.contains(SiteConfig.siteName) ? title : '$title | ${SiteConfig.siteName}';

  /// Turns a site-relative or stored image path into an absolute first-party URL,
  /// falling back to the bundled share image.
  static String resolveImage(String? image) {
    if (image == null || image.isEmpty) return SiteConfig.defaultOgImage;
    if (image.startsWith('http://') || image.startsWith('https://')) return image;
    return '${SiteConfig.domain}${image.startsWith('/') ? '' : '/'}$image';
  }
}
