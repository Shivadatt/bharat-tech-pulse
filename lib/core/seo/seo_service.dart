import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../app/config/site_config.dart';
import 'seo_dom.dart';

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
    // Callers that already include the site name (e.g. "AI — Bharat Tech Pulse")
    // must not get a duplicated " | Bharat Tech Pulse" suffix.
    final fullTitle = title.contains(SiteConfig.siteName)
        ? title
        : '$title | ${SiteConfig.siteName}';
    final desc = description ?? SiteConfig.description;
    final image = ogImage ?? SiteConfig.defaultOgImage;
    final url = canonicalPath != null
        ? '${SiteConfig.domain}$canonicalPath'
        : SiteConfig.domain;

    if (kIsWeb) {
      SeoDom.apply(
        title: fullTitle,
        description: desc,
        canonicalUrl: url,
        ogImage: image,
        ogType: ogType ?? 'website',
        ogSiteName: SiteConfig.siteName,
        twitterHandle: SiteConfig.twitterHandle,
        jsonLd: jsonLdSchema,
      );
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
    required DateTime updatedAt,
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
      'datePublished': publishedAt.toUtc().toIso8601String(),
      'dateModified': updatedAt.toUtc().toIso8601String(),
      'author': {
        '@type': 'Person',
        'name': authorName,
      },
      'publisher': {
        '@type': 'Organization',
        'name': SiteConfig.siteName,
        'url': SiteConfig.domain,
        'logo': {
          '@type': 'ImageObject',
          'url': '${SiteConfig.domain}/favicon.png',
        },
      },
      'mainEntityOfPage': articleUrl,
      'url': articleUrl,
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
}
