import 'dart:convert';

import '../../app/config/site_config.dart';

/// Pure-Dart schema.org JSON-LD builders. No Flutter or `dart:html` imports so
/// the offline prerenderer (`tool/generate_prerender.dart`) and the live
/// `SeoService` emit byte-identical structured data from one source of truth.
class SeoSchema {
  static const String context = 'https://schema.org';

  static Map<String, dynamic> organization() => <String, dynamic>{
        '@type': 'Organization',
        'name': SiteConfig.siteName,
        'url': SiteConfig.domain,
        'description': SiteConfig.description,
        'email': SiteConfig.contactEmail,
        'logo': <String, dynamic>{
          '@type': 'ImageObject',
          'url': '${SiteConfig.domain}/favicon.png',
        },
        'sameAs': <String>[
          'https://twitter.com/${SiteConfig.twitterHandle.replaceFirst('@', '')}',
          'https://www.youtube.com/@${SiteConfig.youtubeChannel}',
          'https://t.me/${SiteConfig.telegramChannel}',
          'https://www.linkedin.com/${SiteConfig.linkedinPage}',
        ],
      };

  static Map<String, dynamic> webSite() => <String, dynamic>{
        '@type': 'WebSite',
        '@id': '${SiteConfig.domain}/#website',
        'url': SiteConfig.domain,
        'name': SiteConfig.siteName,
        'description': SiteConfig.description,
        'inLanguage': 'en-IN',
        'publisher': organization(),
      };

  static Map<String, dynamic> siteGraph() => <String, dynamic>{
        '@context': context,
        '@graph': <Map<String, dynamic>>[
          organization(),
          webSite(),
        ],
      };

  /// A `BlogPosting` carrying author, dates, image and `mainEntityOfPage`,
  /// wired back to the `WebSite`/`Organization` through `isPartOf`/`publisher`.
  static Map<String, dynamic> blogPosting({
    required String title,
    required String description,
    required String url,
    required String imageUrl,
    required String authorName,
    String? authorUrl,
    List<String> authorSameAs = const [],
    required DateTime publishedAt,
    required DateTime modifiedAt,
    String categoryName = '',
    List<String> keywords = const [],
    String body = '',
  }) {
    final author = <String, dynamic>{
      '@type': 'Person',
      'name': authorName,
      if (authorUrl != null && authorUrl.isNotEmpty) 'url': authorUrl,
      if (authorSameAs.isNotEmpty) 'sameAs': authorSameAs,
    };
    return <String, dynamic>{
      '@type': 'BlogPosting',
      '@id': '$url#article',
      'headline': title,
      'description': description,
      'image': <String>[imageUrl],
      'inLanguage': 'en-IN',
      'datePublished': publishedAt.toUtc().toIso8601String(),
      'dateModified': modifiedAt.toUtc().toIso8601String(),
      'author': author,
      'publisher': organization(),
      'mainEntityOfPage': <String, dynamic>{
        '@type': <String>['WebPage', 'Article'],
        '@id': url,
      },
      'url': url,
      'isPartOf': <String, dynamic>{
        '@type': 'WebSite',
        '@id': '${SiteConfig.domain}/#website',
      },
      if (categoryName.isNotEmpty) 'articleSection': categoryName,
      if (keywords.isNotEmpty) 'keywords': keywords.join(','),
      // `wordCount` from the real body text when it is available; omitted
      // rather than guessed when the caller has no content (the old
      // `readingMinutes * 238` figure was a fabricated number).
      if (body.trim().isNotEmpty) 'wordCount': _wordCount(body),
    };
  }

  /// Words in the Markdown body once markers and URLs cannot masquerade as
  /// words: closer to what an editor would call the length of the text.
  static int _wordCount(String body) => body
      .replaceAll(RegExp(r'https?://\S+'), ' ')
      .split(RegExp(r'[\s]+'))
      .where((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9\u0900-\u097F]'), '').isNotEmpty)
      .length;

  /// `FAQPage` built from the model's existing FAQs; returns null when empty
  /// so callers never emit an empty mainEntity (a rich-result rejection).
  /// The `@id` is absolute like every other node — a bare `#faq` fragment is
  /// document-relative and made the two nodes collide inside the `@graph`.
  static Map<String, dynamic>? faqPage(List<Map<String, String>> faqs, String url) {
    if (faqs.isEmpty) return null;
    return <String, dynamic>{
      '@type': 'FAQPage',
      '@id': '$url#faq',
      'mainEntity': faqs
          .map((f) => <String, dynamic>{
                '@type': 'Question',
                'name': f['question'],
                'acceptedAnswer': <String, dynamic>{
                  '@type': 'Answer',
                  'text': f['answer'],
                },
              })
          .toList(),
    };
  }

  static Map<String, dynamic> _breadcrumb(List<_Crumb> crumbs) => <String, dynamic>{
        '@type': 'BreadcrumbList',
        'itemListElement': <Map<String, dynamic>>[
          for (var i = 0; i < crumbs.length; i++)
            <String, dynamic>{
              '@type': 'ListItem',
              'position': i + 1,
              'name': crumbs[i].name,
              'item': '${SiteConfig.domain}${crumbs[i].path}',
            },
        ],
      };

  /// Full graph for an article route: BlogPosting + FAQPage (if FAQs exist) +
  /// BreadcrumbList (Home > Category > Article).
  static Map<String, dynamic> articleGraph({
    required String title,
    required String description,
    required String url,
    required String imageUrl,
    required String authorName,
    String? authorUrl,
    List<String> authorSameAs = const [],
    required DateTime publishedAt,
    required DateTime modifiedAt,
    String categoryName = '',
    String categorySlug = '',
    List<String> keywords = const [],
    List<Map<String, String>> faqs = const [],
    String body = '',
  }) {
    final graph = <Map<String, dynamic>>[
      blogPosting(
        title: title,
        description: description,
        url: url,
        imageUrl: imageUrl,
        authorName: authorName,
        authorUrl: authorUrl,
        authorSameAs: authorSameAs,
        publishedAt: publishedAt,
        modifiedAt: modifiedAt,
        categoryName: categoryName,
        keywords: keywords,
        body: body,
      ),
    ];
    final faq = faqPage(faqs, url);
    if (faq != null) graph.add(faq);
    graph.add(_breadcrumb(<_Crumb>[
      _Crumb('Home', '/'),
      if (categorySlug.isNotEmpty) _Crumb(categoryName, '/$categorySlug/'),
      _Crumb(title, Uri.parse(url).path),
    ]));
    return <String, dynamic>{'@context': context, '@graph': graph};
  }

  /// CollectionPage + breadcrumb for a category route.
  static Map<String, dynamic> categoryGraph({
    required String name,
    required String slug,
    required String description,
    required String url,
  }) {
    final page = <String, dynamic>{
      '@type': 'CollectionPage',
      '@id': '$url#collection',
      'url': url,
      'name': name,
      'description': description,
      'isPartOf': <String, dynamic>{
        '@type': 'WebSite',
        '@id': '${SiteConfig.domain}/#website',
      },
    };
    return <String, dynamic>{
      '@context': context,
      '@graph': <Map<String, dynamic>>[
        page,
        _breadcrumb(<_Crumb>[
          _Crumb('Home', '/'),
          _Crumb(name, '/$slug/'),
        ]),
      ],
    };
  }

  /// Absolute `sameAs` URLs from an author's stored social fields: `twitter`
  /// is a handle (`@name`), `linkedin` a path (`in/foo`) — the same shape
  /// [organization] builds for the sitewide channels. Full URLs pass through,
  /// empty fields are skipped so no half-built profile URL is ever invented.
  static List<String> socialSameAs({String twitter = '', String linkedin = ''}) {
    final out = <String>[];
    final t = twitter.trim();
    if (t.isNotEmpty) {
      out.add(t.startsWith('http') ? t : 'https://twitter.com/${t.replaceFirst('@', '')}');
    }
    final l = linkedin.trim();
    if (l.isNotEmpty) {
      out.add(l.startsWith('http')
          ? l
          : 'https://www.linkedin.com/${l.startsWith('/') ? l.substring(1) : l}');
    }
    return out;
  }

  /// Person + ProfilePage + breadcrumb graph for an `/author/:slug` profile.
  static Map<String, dynamic> authorGraph({
    required String name,
    required String slug,
    String bio = '',
    String imageUrl = '',
    List<String> sameAs = const [],
  }) {
    final url = '${SiteConfig.domain}/author/$slug';
    final person = <String, dynamic>{
      '@type': 'Person',
      '@id': '$url#person',
      'name': name,
      'url': url,
      if (bio.isNotEmpty) 'description': bio,
      if (imageUrl.isNotEmpty) 'image': imageUrl,
      if (sameAs.isNotEmpty) 'sameAs': sameAs,
    };
    final page = <String, dynamic>{
      '@type': 'ProfilePage',
      '@id': '$url#profilepage',
      'url': url,
      'name': '$name — Author Profile',
      'inLanguage': 'en-IN',
      'mainEntity': person,
      'isPartOf': <String, dynamic>{
        '@type': 'WebSite',
        '@id': '${SiteConfig.domain}/#website',
      },
    };
    return <String, dynamic>{
      '@context': context,
      '@graph': <Map<String, dynamic>>[
        page,
        person,
        _breadcrumb(<_Crumb>[
          _Crumb('Home', '/'),
          _Crumb(name, '/author/$slug'),
        ]),
      ],
    };
  }

  static String encode(Map<String, dynamic> jsonLd) =>
      jsonEncode(jsonLd);
}

class _Crumb {
  final String name;
  final String path;
  const _Crumb(this.name, this.path);
}
