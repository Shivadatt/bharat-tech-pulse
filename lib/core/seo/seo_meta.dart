import '../../app/config/site_config.dart';
import '../../data/models/article_model.dart';
import '../../data/models/author_model.dart';
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

  /// CMS-supplied `og_title` / `og_description` overrides (articles only today).
  /// The getters fall back to [title] / [description] when they are absent, so
  /// an editor's OG override actually reaches both renderers instead of being
  /// stored and silently ignored.
  final String? ogTitleOverride;
  final String? ogDescriptionOverride;

  String get ogTitle =>
      (ogTitleOverride != null && ogTitleOverride!.isNotEmpty)
          ? ogTitleOverride!
          : title;

  String get ogDescription =>
      (ogDescriptionOverride != null && ogDescriptionOverride!.isNotEmpty)
          ? ogDescriptionOverride!
          : description;

  /// The `robots` meta value. Defaults to `index, follow`; the not-found route
  /// passes `noindex, follow` so a soft-404 URL is not added to the index.
  /// SeoDom writes this on *every* apply so client-side navigation can never
  /// leave a stale directive from the previous page.
  final String robots;

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
    required this.robots,
    required this.jsonLd,
    required this.properties,
    required this.names,
    this.ogTitleOverride,
    this.ogDescriptionOverride,
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
    String robots = 'index, follow',
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
          : canonicalPath != null && canonicalPath.isNotEmpty
              ? '${SiteConfig.domain}$canonicalPath'
              // A noindex route with no declared path gets an EMPTY canonical
              // (both renderers omit the tag when empty) instead of inheriting
              // the site root, so soft-404s and /admin can never declare the
              // homepage as their canonical.
              : robots.contains('noindex')
                  ? ''
                  : '${SiteConfig.domain}/',
      ogImage: resolveImage(ogImage),
      ogType: ogType,
      robots: robots,
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
      robots: 'index, follow',
      ogTitleOverride: art.ogTitle,
      ogDescriptionOverride: art.ogDescription,
      jsonLd: SeoSchema.articleGraph(
        title: art.title,
        description: description,
        url: url,
        imageUrl: resolveImage(art.ogImage.isNotEmpty ? art.ogImage : art.featuredImage),
        authorName: art.author.name,
        authorUrl: art.author.slug.isNotEmpty
            ? '${SiteConfig.domain}/author/${art.author.slug}'
            : null,
        authorSameAs: SeoSchema.socialSameAs(
          twitter: art.author.twitter,
          linkedin: art.author.linkedin,
        ),
        publishedAt: art.publishedAt,
        modifiedAt: art.updatedAt,
        categoryName: art.categoryName,
        categorySlug: art.categorySlug,
        keywords: art.tags,
        faqs: art.faqs
            .map((f) => <String, String>{'question': f.question, 'answer': f.answer})
            .toList(),
        body: art.content,
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
      robots: 'index, follow',
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

  /// Author profile route (`/author/:slug`): Person + ProfilePage graph.
  /// The title/description/canonical mirror what `AuthorController` writes at
  /// runtime, so the prerendered shells and the live page agree.
  factory SeoMeta.forAuthor(AuthorModel author) {
    return SeoMeta.page(
      title: '${author.name} — Author Profile',
      description: author.bio,
      canonicalPath: '/author/${author.slug}',
      ogImage: author.avatarUrl,
      ogType: 'profile',
      jsonLd: SeoSchema.authorGraph(
        name: author.name,
        slug: author.slug,
        bio: author.bio,
        imageUrl: resolveImage(author.avatarUrl),
        sameAs: SeoSchema.socialSameAs(
          twitter: author.twitter,
          linkedin: author.linkedin,
        ),
      ),
      names: <String, String>{'author': author.name},
    );
  }

  // Hand-authored static pages. `app_pages.dart` feeds these exact constants
  // into its `PageSeoInit` widgets and `tool/generate_prerender.dart` bakes
  // shells from them, so the runtime tags and the crawler shells cannot drift
  // and the strings exist in one copy only.
  static const StaticPageSeo about = StaticPageSeo(
    '/about',
    'About Us',
    'Meet the Bharat Tech Pulse editorial team and our mission of jargon-free, high-integrity technology journalism for India.',
  );
  static const StaticPageSeo contact = StaticPageSeo(
    '/contact',
    'Contact Us',
    'Get in touch with the Bharat Tech Pulse team for tips, corrections, feedback, and partnership enquiries.',
  );
  static const StaticPageSeo editorialPolicy = StaticPageSeo(
    '/editorial-policy',
    'Editorial Policy',
    'How Bharat Tech Pulse tests, reviews, and fact-checks technology for Indian readers.',
  );
  static const StaticPageSeo privacyPolicy = StaticPageSeo(
    '/privacy-policy',
    'Privacy Policy',
    'How Bharat Tech Pulse collects, uses, and protects visitor information.',
  );
  static const StaticPageSeo terms = StaticPageSeo(
    '/terms',
    'Terms of Use',
    'Terms governing the use of the Bharat Tech Pulse website.',
  );
  static const StaticPageSeo disclaimer = StaticPageSeo(
    '/disclaimer',
    'Disclaimer',
    'Editorial, affiliate, and accuracy disclaimers for Bharat Tech Pulse content.',
  );

  /// Every indexable static page, in sitemap order.
  static const List<StaticPageSeo> staticPages = [
    about,
    contact,
    editorialPolicy,
    privacyPolicy,
    terms,
    disclaimer,
  ];

  /// Resolves a [StaticPageSeo] into full page metadata (indexable, sitewide
  /// Organization + WebSite graph), used by both the runtime and the shells.
  static SeoMeta forStaticPage(StaticPageSeo page) => SeoMeta.page(
        title: page.title,
        description: page.description,
        canonicalPath: page.path,
      );

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

/// SEO identity of one hand-authored static page: its route path, page title
/// and meta description. Declared once in [SeoMeta] and consumed by the
/// `PageSeoInit` widgets in `app_pages.dart` and by the prerenderer's shells,
/// so neither path can fork a stale copy of the strings.
class StaticPageSeo {
  /// Site-relative route path, exactly as advertised in web/sitemap.xml.
  final String path;
  final String title;
  final String description;

  const StaticPageSeo(this.path, this.title, this.description);
}
