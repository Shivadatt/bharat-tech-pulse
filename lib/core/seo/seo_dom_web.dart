import 'dart:convert';
import 'package:web/web.dart' as web;

/// Web implementation: writes document title, meta tags, canonical link and
/// JSON-LD into the live document. Only JS-executing crawlers (Googlebot) ever
/// reach this — non-JS scrapers are served by the prerenderer instead.
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
    Map<String, String> properties = const {},
    Map<String, String> names = const {},
  }) {
    web.document.title = title;

    _setMeta('name', 'description', description);

    _setMeta('property', 'og:site_name', ogSiteName);
    _setMeta('property', 'og:title', title);
    _setMeta('property', 'og:description', description);
    _setMeta('property', 'og:url', canonicalUrl);
    _setMeta('property', 'og:image', ogImage);
    _setMeta('property', 'og:type', ogType);
    _setMeta('property', 'og:locale', 'en_IN');

    _setMeta('name', 'twitter:card', 'summary_large_image');
    _setMeta('name', 'twitter:site', twitterHandle);
    _setMeta('name', 'twitter:title', title);
    _setMeta('name', 'twitter:description', description);
    _setMeta('name', 'twitter:image', ogImage);

    properties.forEach((key, value) => _setMeta('property', key, value));
    names.forEach((key, value) => _setMeta('name', key, value));

    _setCanonical(canonicalUrl);
    _setJsonLd(jsonLd);
  }

  // Creates the tag when it is absent: the pre-remediation version only
  // mutated existing tags, so any meta not baked into index.html was silently
  // dropped and never reached a crawler.
  static void _setMeta(String attribute, String key, String content) {
    final selector = 'meta[$attribute="$key"]';
    var element =
        web.document.querySelector(selector) as web.HTMLMetaElement?;
    if (element == null) {
      element = web.HTMLMetaElement();
      element.setAttribute(attribute, key);
      web.document.head?.append(element);
    }
    element.content = content;
  }

  static void _setCanonical(String href) {
    var element =
        web.document.querySelector('link[rel="canonical"]') as web.HTMLLinkElement?;
    if (element == null) {
      element = web.HTMLLinkElement();
      element.rel = 'canonical';
      web.document.head?.append(element);
    }
    element.href = href;
  }

  /// Injects `google-site-verification` from `--dart-define` so Search Console
  /// ownership can be claimed without baking a real token into source. A no-op
  /// when the token is absent.
  static void setGoogleSiteVerification(String value) {
    if (value.isEmpty) return;
    _setMeta('name', 'google-site-verification', value);
  }

  /// The build-time shells written by tool/generate_prerender.dart embed the
  /// real article HTML so a crawler that never runs JavaScript still sees the
  /// content. Flutter paints its own surface over that copy, so main.dart calls
  /// this after the first frame.
  static void clearPrerenderedContent() {
    web.document.getElementById('btp-prerendered-content')?.remove();
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
