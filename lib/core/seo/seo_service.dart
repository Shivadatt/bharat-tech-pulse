import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../app/config/site_config.dart';

/// Centralized SEO service managing web document title, metadata, and JSON-LD schemas.
class SeoService extends GetxService {
  void updateMeta({
    required String title,
    String? description,
    String? canonicalPath,
    String? ogImage,
    String? ogType = 'website',
    Map<String, dynamic>? jsonLdSchema,
  }) {
    final fullTitle = '$title | ${SiteConfig.siteName}';
    final desc = description ?? SiteConfig.description;
    final image = ogImage ?? SiteConfig.defaultOgImage;
    final url = canonicalPath != null
        ? '${SiteConfig.domain}$canonicalPath'
        : SiteConfig.domain;

    if (kIsWeb) {
      _setWebTitle(fullTitle);
    }

    if (kDebugMode) {
      debugPrint('[SEO] Title="$fullTitle", Desc="$desc", Image="$image", URL="$url", Type="$ogType"');
    }
  }

  void updateArticleMeta({
    required String title,
    required String excerpt,
    required String slug,
    required String authorName,
    required DateTime publishedAt,
    required String featuredImage,
    required String categoryName,
  }) {
    final articleUrl = '${SiteConfig.domain}/article/$slug';
    final schema = {
      '@context': 'https://schema.org',
      '@type': 'TechArticle',
      'headline': title,
      'description': excerpt,
      'image': featuredImage,
      'datePublished': publishedAt.toIso8601String(),
      'author': {
        '@type': 'Person',
        'name': authorName,
      },
      'publisher': {
        '@type': 'Organization',
        'name': SiteConfig.siteName,
        'url': SiteConfig.domain,
      },
      'mainEntityOfPage': articleUrl,
      'articleSection': categoryName,
    };

    updateMeta(
      title: title,
      description: excerpt,
      canonicalPath: '/article/$slug',
      ogImage: featuredImage,
      ogType: 'article',
      jsonLdSchema: schema,
    );
  }

  void _setWebTitle(String title) {
    // In Flutter Web, SystemChrome / Title widget handles this via runApp or Title
  }
}
