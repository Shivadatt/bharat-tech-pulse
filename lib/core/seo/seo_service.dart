import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../app/config/site_config.dart';
import '../../data/models/article_model.dart';
import '../../data/models/category_model.dart';
import 'seo_dom.dart';
import 'seo_meta.dart';
import 'seo_schema.dart';

/// Centralized SEO service: title, meta, canonical, OpenGraph/Twitter and
/// JSON-LD structured data for every route.
///
/// The *values* are computed by [SeoMeta] (a pure class shared with
/// `tool/generate_prerender.dart`); this service only writes them into the live
/// document, so a JS-executing crawler and a static shell can no longer report
/// different metadata for the same article.
class SeoService extends GetxService {
  /// Search Console ownership token, supplied only at build time
  /// (`--dart-define=GOOGLE_SITE_VERIFICATION=...`). Empty means unclaimed.
  static const String _siteVerification =
      String.fromEnvironment('GOOGLE_SITE_VERIFICATION', defaultValue: '');

  @override
  void onInit() {
    super.onInit();
    if (kIsWeb && _siteVerification.isNotEmpty) {
      SeoDom.setGoogleSiteVerification(_siteVerification);
    }
  }

  void updateMeta({
    required String title,
    String? description,
    String? canonicalPath,
    String? ogImage,
    String? ogType = 'website',
    Map<String, dynamic>? jsonLdSchema,
    Map<String, String> properties = const {},
    Map<String, String> names = const {},
  }) {
    applyMeta(SeoMeta.page(
      title: title,
      description: description,
      canonicalPath: canonicalPath,
      ogImage: ogImage,
      ogType: ogType ?? 'website',
      jsonLd: jsonLdSchema,
      properties: properties,
      names: names,
    ));
  }

  /// Writes an already-resolved [SeoMeta] into the document.
  void applyMeta(SeoMeta meta) {
    if (kIsWeb) {
      SeoDom.apply(
        title: meta.title,
        description: meta.description,
        canonicalUrl: meta.canonicalUrl,
        ogImage: meta.ogImage,
        ogType: meta.ogType,
        ogSiteName: SiteConfig.siteName,
        twitterHandle: SiteConfig.twitterHandle,
        jsonLd: meta.jsonLd,
        properties: meta.properties,
        names: meta.names,
      );
    }

    if (kDebugMode) {
      debugPrint('[SEO] Title="${meta.title}", Desc="${meta.description}", '
          'Image="${meta.ogImage}", URL="${meta.canonicalUrl}", Type="${meta.ogType}"');
    }
  }

  /// Sitewide brand metadata used by pages with no editorial entity.
  void updateSiteMeta({String? title, String? description}) {
    updateMeta(
      title: title ?? SiteConfig.siteName,
      description: description ?? SiteConfig.description,
      jsonLdSchema: SeoSchema.siteGraph(),
    );
  }

  /// Full article metadata + BlogPosting / FAQPage / BreadcrumbList graph,
  /// built from the loaded [ArticleModel] so existing FAQ and ToC data is
  /// reused rather than re-supplied.
  void updateArticleSeo(ArticleModel art) => applyMeta(SeoMeta.forArticle(art));

  void updateCategorySeo(CategoryModel cat) => applyMeta(SeoMeta.forCategory(cat));

  /// Legacy entry point kept for callers that only have primitive fields;
  /// delegates to a minimal BlogPosting graph.
  void updateArticleMeta({
    required String title,
    required String excerpt,
    required String slug,
    required String authorName,
    required DateTime publishedAt,
    required DateTime updatedAt,
    required String featuredImage,
    required String categoryName,
  }) {
    final articleUrl = '${SiteConfig.domain}/article/$slug';
    final graph = SeoSchema.articleGraph(
      title: title,
      description: excerpt,
      url: articleUrl,
      imageUrl: SeoMeta.resolveImage(featuredImage),
      authorName: authorName,
      publishedAt: publishedAt,
      modifiedAt: updatedAt,
      categoryName: categoryName,
    );

    updateMeta(
      title: title,
      description: excerpt,
      canonicalPath: '/article/$slug',
      ogImage: featuredImage,
      ogType: 'article',
      jsonLdSchema: graph,
    );
  }
}
