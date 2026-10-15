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
    required String ogTitle,
    required String ogDescription,
    required String canonicalUrl,
    required String ogImage,
    required String ogType,
    required String robots,
    required String ogSiteName,
    required String twitterHandle,
    Map<String, dynamic>? jsonLd,
    Map<String, String> properties = const {},
    Map<String, String> names = const {},
  }) {
    web.document.title = title;

    _setMeta('name', 'description', description);
    // Written on every apply so navigating away from a noindex page (404)
    // resets the directive instead of leaving a stale one on an indexable page.
    _setMeta('name', 'robots', robots);

    _setMeta('property', 'og:site_name', ogSiteName);
    _setMeta('property', 'og:title', ogTitle);
    _setMeta('property', 'og:description', ogDescription);
    _setMeta('property', 'og:url', canonicalUrl);
    _setMeta('property', 'og:image', ogImage);
    _setMeta('property', 'og:type', ogType);
    _setMeta('property', 'og:locale', 'en_IN');

    _setMeta('name', 'twitter:card', 'summary_large_image');
    _setMeta('name', 'twitter:site', twitterHandle);
    _setMeta('name', 'twitter:title', ogTitle);
    _setMeta('name', 'twitter:description', ogDescription);
    _setMeta('name', 'twitter:image', ogImage);

    // Article-only tags are additive by nature: after a reader visits a story,
    // `/about`, `/search`, a category and the soft-404 kept that article's
    // `article:published_time`, `article:section` and `name=author`, because
    // `_setMeta` only ever writes or creates - it never removes.
    _removeMatching('meta[property^="article:"]');
    _removeMatching('meta[name="author"]');

    properties.forEach((key, value) => _setMeta('property', key, value));
    names.forEach((key, value) => _setMeta('name', key, value));

    _setCanonical(canonicalUrl);
    _setJsonLd(jsonLd);
  }

  static void _removeMatching(String selector) {
    final found = web.document.querySelectorAll(selector);
    for (var i = found.length - 1; i >= 0; i--) {
      found.item(i)?.remove();
    }
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
    // An empty canonicalUrl is SeoMeta's "suppress the tag" signal (a noindex
    // route with no declared path). Writing `href=""` would resolve to the
    // page's own URL, which is the opposite of what the shell renderer does.
    if (href.isEmpty) {
      _removeMatching('link[rel="canonical"]');
      return;
    }
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
