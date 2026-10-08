import 'dart:convert';
import 'package:web/web.dart' as web;

/// Web implementation: writes document title, meta tags, canonical link,
/// and JSON-LD into the browser DOM so crawlers and social scrapers can
/// read them from the live document.
class SeoDom {
  static const _jsonLdId = 'app-seo-json-ld';

  static void apply({
    required String title,
    required String description,
    required String canonicalUrl,
    required String ogImage,
    required String ogType,
    required String ogSiteName,
    required String twitterHandle,
    Map<String, dynamic>? jsonLd,
  }) {
    web.document.title = title;

    _setMeta('name', 'description', description);

    _setMeta('property', 'og:site_name', ogSiteName);
    _setMeta('property', 'og:title', title);
    _setMeta('property', 'og:description', description);
    _setMeta('property', 'og:url', canonicalUrl);
    _setMeta('property', 'og:image', ogImage);
    _setMeta('property', 'og:type', ogType);

    _setMeta('name', 'twitter:card', 'summary_large_image');
    _setMeta('name', 'twitter:site', twitterHandle);
    _setMeta('name', 'twitter:title', title);
    _setMeta('name', 'twitter:description', description);
    _setMeta('name', 'twitter:image', ogImage);

    _setCanonical(canonicalUrl);
    _setJsonLd(jsonLd);
  }

  static void _setMeta(String attribute, String key, String content) {
    final element =
        web.document.querySelector('meta[$attribute="$key"]') as web.HTMLMetaElement?;
    element?.content = content;
  }

  static void _setCanonical(String href) {
    final element =
        web.document.querySelector('link[rel="canonical"]') as web.HTMLLinkElement?;
    element?.href = href;
  }

  static void _setJsonLd(Map<String, dynamic>? jsonLd) {
    web.document.querySelector('#$_jsonLdId')?.remove();
    if (jsonLd == null) return;

    final script = web.HTMLScriptElement();
    script.type = 'application/ld+json';
    script.id = _jsonLdId;
    script.text = jsonEncode(jsonLd);
    web.document.head?.append(script);
  }
}
