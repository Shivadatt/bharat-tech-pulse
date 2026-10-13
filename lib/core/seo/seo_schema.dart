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
    int readingMinutes = 0,
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
      if (readingMinutes > 0) 'wordCount': readingMinutes * 238,
    };
  }

  /// `FAQPage` built from the model's existing FAQs; returns null when empty
  /// so callers never emit an empty mainEntity (a rich-result rejection).
  static Map<String, dynamic>? faqPage(List<Map<String, String>> faqs) {
    if (faqs.isEmpty) return null;
    return <String, dynamic>{
      '@type': 'FAQPage',
      '@id': '#faq',
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
    required DateTime publishedAt,
    required DateTime modifiedAt,
    String categoryName = '',
    String categorySlug = '',
    List<String> keywords = const [],
    List<Map<String, String>> faqs = const [],
    int readingMinutes = 0,
  }) {
    final graph = <Map<String, dynamic>>[
      blogPosting(
        title: title,
        description: description,
        url: url,
        imageUrl: imageUrl,
        authorName: authorName,
        authorUrl: authorUrl,
        publishedAt: publishedAt,
        modifiedAt: modifiedAt,
        categoryName: categoryName,
        keywords: keywords,
        readingMinutes: readingMinutes,
      ),
    ];
    final faq = faqPage(faqs);
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

  static String encode(Map<String, dynamic> jsonLd) =>
      jsonEncode(jsonLd);
}

class _Crumb {
  final String name;
  final String path;
  const _Crumb(this.name, this.path);
}
