import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_tech_web/app/config/site_config.dart';
import 'package:india_tech_web/core/seo/seo_meta.dart';
import 'package:india_tech_web/core/seo/seo_schema.dart';
import 'package:india_tech_web/core/seo/seo_service.dart';
import 'package:india_tech_web/data/models/article_model.dart';
import 'package:india_tech_web/data/models/author_model.dart';
import 'package:india_tech_web/data/repositories/supabase_article_repository.dart';

// The offline prerenderer is a tool, not a library — this test is the seam that
// keeps it honest. Everything below is pure and offline: no network, no
// database, no browser.
import '../tool/generate_prerender.dart';

const String _seedPath = 'supabase/migrations/006_seed_data.sql';
const String _builtBundle = 'build/web';

void main() {
  final seed = File(_seedPath).readAsStringSync();
  final data = SeedData.parse(seed);
  final shells = <String, String>{
    for (final a in data.publishedPosts) a.slug: buildArticleShell(a),
  };

  group('seed parsing matches the runtime Supabase mapper', () {
    test('the seed has the shape the prerenderer assumes', () {
      expect(data.publishedPosts.length, 15,
          reason: '006_seed_data.sql must hold 15 published posts');
      expect(data.categories.length, 8);
      expect(data.authors.length, 4);
      for (final a in data.publishedPosts) {
        expect(a.slug, isNotEmpty);
        expect(a.title, isNotEmpty);
        expect(a.author.name, isNotEmpty,
            reason: '${a.slug} lost its author during seed parsing');
        expect(a.categoryName, isNotEmpty,
            reason: '${a.slug} lost its category during seed parsing');
        expect(a.content, contains('## '));
        expect(a.tags, isNotEmpty,
            reason: '${a.slug} has no tags — check the post_tags parse');
        expect(a.faqs, hasLength(3));
        expect(a.keyTakeaways, hasLength(4));
      }
    });

    test('seedToArticle and rowToArticle agree on every published post', () {
      for (final parsed in data.publishedPosts) {
        final viaRepository =
            SupabaseArticleRepository.rowToArticle(_joinedPostRow(parsed, seed));
        expect(viaRepository.slug, parsed.slug);
        expect(viaRepository.title, parsed.title);
        expect(viaRepository.excerpt, parsed.excerpt);
        expect(viaRepository.content, parsed.content);
        expect(viaRepository.categorySlug, parsed.categorySlug);
        expect(viaRepository.categoryName, parsed.categoryName);
        expect(viaRepository.tags, parsed.tags);
        expect(viaRepository.author.name, parsed.author.name);
        expect(viaRepository.author.slug, parsed.author.slug);
        expect(viaRepository.author.role, parsed.author.role);
        expect(viaRepository.publishedAt.toUtc(), parsed.publishedAt.toUtc());
        expect(viaRepository.updatedAt.toUtc(), parsed.updatedAt.toUtc());
        expect(viaRepository.featuredImage, parsed.featuredImage);
        expect(viaRepository.readingTimeMinutes, parsed.readingTimeMinutes);
        expect(viaRepository.seoTitle, parsed.seoTitle);
        expect(viaRepository.seoDescription, parsed.seoDescription);
        expect(viaRepository.canonicalUrl, parsed.canonicalUrl);
        expect(viaRepository.ogImage, parsed.ogImage);
        expect(viaRepository.keyTakeaways, parsed.keyTakeaways);
        expect(viaRepository.faqs.map((f) => f.question),
            parsed.faqs.map((f) => f.question));
        expect(viaRepository.faqs.map((f) => f.answer),
            parsed.faqs.map((f) => f.answer));
        expect(viaRepository.toc.map((t) => t.id), parsed.toc.map((t) => t.id));
      }
    });
  });

  group('shell head metadata equals what the app computes', () {
    test('every published post: title / description / canonical / image', () {
      for (final art in data.publishedPosts) {
        final shell = shells[art.slug]!;
        final meta = SeoMeta.forArticle(art);

        expect(_tag(shell, 'title'), meta.title, reason: art.slug);
        expect(_meta(shell, 'name', 'description'), meta.description,
            reason: art.slug);
        expect(_link(shell, 'canonical'), meta.canonicalUrl, reason: art.slug);
        expect(_meta(shell, 'property', 'og:url'), meta.canonicalUrl,
            reason: art.slug);
        expect(_meta(shell, 'property', 'og:image'), meta.ogImage,
            reason: art.slug);
        expect(_meta(shell, 'name', 'twitter:image'), meta.ogImage,
            reason: art.slug);
        expect(_meta(shell, 'property', 'og:title'), meta.title,
            reason: art.slug);
        expect(_meta(shell, 'property', 'og:type'), 'article', reason: art.slug);

        // og:image / twitter:image must be absolute first-party URLs, never a
        // bare storage path or a protocol-relative URL.
        expect(meta.ogImage, startsWith('https://'), reason: art.slug);
        expect(meta.canonicalUrl, startsWith(SiteConfig.domain),
            reason: art.slug);

        // The seed stores an explicit canonical_url; shell and app must both
        // honour it instead of re-deriving a different URL.
        expect(meta.canonicalUrl,
            art.canonicalUrl.isNotEmpty
                ? art.canonicalUrl
                : '${SiteConfig.domain}/article/${art.slug}',
            reason: art.slug);
      }
    });

    test('the runtime SeoService writes the same values the shell carries', () {
      final logPattern = RegExp(
          r'\[SEO\] Title="(?<title>.*?)", Desc="(?<desc>.*?)", '
          r'Image="(?<image>.*?)", URL="(?<url>.*?)", Type="(?<type>.*?)"');
      for (final art in data.publishedPosts) {
        final shell = shells[art.slug]!;
        final log = captureDebugPrint(
            () => SeoService().updateArticleSeo(art));
        final match = logPattern.firstMatch(log);
        expect(match, isNotNull,
            reason: '${art.slug}: SeoService produced no metadata log');
        expect(match!.namedGroup('title'), _tag(shell, 'title'),
            reason: art.slug);
        expect(match.namedGroup('desc'), _meta(shell, 'name', 'description'),
            reason: art.slug);
        expect(match.namedGroup('image'), _meta(shell, 'property', 'og:image'),
            reason: art.slug);
        expect(match.namedGroup('url'), _link(shell, 'canonical'),
            reason: art.slug);
        expect(match.namedGroup('type'), 'article', reason: art.slug);
      }
    });

    test('category shells agree with updateCategorySeo', () {
      for (final cat in data.categories) {
        final shell = buildCategoryShell(cat);
        final meta = SeoMeta.forCategory(cat);
        expect(_tag(shell, 'title'), meta.title, reason: cat.slug);
        expect(_link(shell, 'canonical'), '${SiteConfig.domain}/${cat.slug}/',
            reason: 'category routes keep the trailing slash: ${cat.slug}');
        expect(_meta(shell, 'property', 'og:type'), 'website');
        expect(_meta(shell, 'property', 'og:image'), meta.ogImage,
            reason: '${cat.slug}: shell and app pick the same share image');
        final log = captureDebugPrint(
            () => SeoService().updateCategorySeo(cat));
        expect(_logTitle(log), _tag(shell, 'title'), reason: cat.slug);
      }
    });

    test('article:published_time / modified_time / section / author are set',
        () {
      for (final art in data.publishedPosts) {
        final shell = shells[art.slug]!;
        expect(_meta(shell, 'property', 'article:published_time'),
            art.publishedAt.toUtc().toIso8601String(),
            reason: art.slug);
        expect(_meta(shell, 'property', 'article:modified_time'),
            art.updatedAt.toUtc().toIso8601String(), reason: art.slug);
        expect(_meta(shell, 'property', 'article:section'), art.categoryName,
            reason: art.slug);
        expect(_meta(shell, 'name', 'author'), art.author.name, reason: art.slug);
      }
    });

    test('a custom seo_title without the brand still gets one title', () {
      // The shell used to trust seo_title verbatim while the runtime appended
      // " | Bharat Tech Pulse"; SeoMeta removes the divergence by construction.
      final art = _copy(_minimalArticle(), seoTitle: 'Editor Custom Title');
      final shell = buildArticleShell(art);
      expect(_tag(shell, 'title'), 'Editor Custom Title | Bharat Tech Pulse');
      expect(
          _tag(shell, 'title'),
          _logTitle(
              captureDebugPrint(() => SeoService().updateArticleSeo(art))));
    });
  });

  group('shell JSON-LD', () {
    test(
        'exactly one structured-data block per shell, with the runtime slot id',
        () {
      for (final art in data.publishedPosts) {
        final shell = shells[art.slug]!;
        expect(shell.split('application/ld+json').length - 1, 1,
            reason: art.slug);
        expect(shell, contains('id="app-seo-json-ld"'),
            reason: '${art.slug}: without the shared id SeoDom injects a '
                'SECOND BlogPosting for JS-capable crawlers');
      }
      for (final cat in data.categories) {
        expect(buildCategoryShell(cat), contains('id="app-seo-json-ld"'));
      }
    });

    test('every BlogPosting carries the required keys', () {
      for (final art in data.publishedPosts) {
        final graph = _jsonLd(shells[art.slug]!);
        final nodes = (graph['@graph'] as List).cast<Map<String, dynamic>>();
        final posting =
            nodes.singleWhere((n) => n['@type'] == 'BlogPosting', orElse: () => fail('no BlogPosting in ${art.slug}'));

        for (final key in [
          'headline',
          'author',
          'datePublished',
          'dateModified',
          'image',
          'mainEntityOfPage',
          'publisher',
          'url',
        ]) {
          expect(posting.containsKey(key), isTrue,
              reason: '${art.slug}: BlogPosting missing "$key"');
        }
        expect(posting['headline'], art.title);
        expect((posting['author'] as Map)['name'], art.author.name);
        expect((posting['author'] as Map)['url'],
            '${SiteConfig.domain}/author/${art.author.slug}');
        expect(posting['image'], [SeoMeta.forArticle(art).ogImage]);
        expect((posting['mainEntityOfPage'] as Map)['@id'],
            SeoMeta.forArticle(art).canonicalUrl);
        expect((posting['publisher'] as Map)['name'], SiteConfig.siteName);
        expect(posting['datePublished'],
            art.publishedAt.toUtc().toIso8601String());
        expect(posting['dateModified'], art.updatedAt.toUtc().toIso8601String());
        expect(posting['keywords'], art.tags.join(','),
            reason: '${art.slug}: the shell used to drop tags, so the static '
                'and runtime graphs disagreed');

        nodes.singleWhere((n) => n['@type'] == 'BreadcrumbList',
            orElse: () => fail('no BreadcrumbList in ${art.slug}'));
        expect(graph, SeoMeta.forArticle(art).jsonLd, reason: art.slug);
      }
    });

    test('FAQPage node count equals the row faqs length', () {
      for (final art in data.publishedPosts) {
        final shell = shells[art.slug]!;
        final nodes =
            (_jsonLd(shell)['@graph'] as List).cast<Map<String, dynamic>>();
        final faq = nodes.where((n) => n['@type'] == 'FAQPage').toList();
        if (art.faqs.isEmpty) {
          expect(faq, isEmpty, reason: art.slug);
          continue;
        }
        expect(faq, hasLength(1), reason: art.slug);
        final main = faq.single['mainEntity'] as List;
        expect(main, hasLength(art.faqs.length), reason: art.slug);
        for (var i = 0; i < main.length; i++) {
          final node = main[i] as Map<String, dynamic>;
          expect(node['@type'], 'Question');
          expect(node['name'], art.faqs[i].question);
          expect((node['acceptedAnswer'] as Map)['text'], art.faqs[i].answer);
        }
        // The same FAQ text must be visible in the shell body, or Google has a
        // structured-data-only FAQ (rich-result rejection risk).
        final body = _prerenderedBody(shell);
        expect(body, contains(escapeHtml(art.faqs.first.question)));
        expect(body, contains(escapeHtml(art.faqs.first.answer)));
      }
    });

    test('breadcrumb mirrors Home > Category > Article', () {
      for (final art in data.publishedPosts) {
        final nodes =
            (_jsonLd(shells[art.slug]!)['@graph'] as List)
                .cast<Map<String, dynamic>>();
        final crumb = nodes.singleWhere((n) => n['@type'] == 'BreadcrumbList');
        final items = (crumb['itemListElement'] as List).cast<Map>();
        expect(items.map((e) => e['position']).toList(), [1, 2, 3],
            reason: art.slug);
        expect(items[0]['name'], 'Home');
        expect(items[1]['name'], art.categoryName);
        expect(items[1]['item'], '${SiteConfig.domain}/${art.categorySlug}/');
        expect(items[2]['name'], art.title);
        expect(items[2]['item'], '${SiteConfig.domain}/article/${art.slug}');
      }
    });

    test('the sitewide graph in web/index.html equals SeoSchema.siteGraph()',
        () {
      final index = File('web/index.html').readAsStringSync();
      final block = RegExp(
              '<script type="application/ld\\+json"[^>]*>(.*?)</script>',
              dotAll: true)
          .firstMatch(index);
      expect(block, isNotNull);
      expect(index, contains('id="app-seo-json-ld"'),
          reason: 'otherwise the runtime block is a duplicate Organization');
      expect(jsonDecode(block!.group(1)!), SeoSchema.siteGraph());
    });
  });

  group('shell body content fidelity', () {
    test('headings rendered per shell equal the seed "##" headings', () {
      for (final art in data.publishedPosts) {
        final body = _prerenderedBody(shells[art.slug]!);
        final seedH2 = art.content
            .split('\n')
            .where((l) => l.trim().startsWith('## '))
            .length;
        final rendered =
            body.split('\n').where((l) => l.startsWith('<h2>')).length;
        expect(
            rendered,
            seedH2 +
                (art.faqs.isEmpty ? 0 : 1) +
                (art.keyTakeaways.isEmpty ? 0 : 1),
            reason: art.slug);
        for (final line in art.content.split('\n')) {
          final t = line.trim();
          if (t.startsWith('## ')) {
            expect(body, contains('<h2>${escapeHtml(t.substring(3))}</h2>'),
                reason: '${art.slug}: "$t"');
          }
        }
      }
    });

    test('the visible copy carries the blocks ArticleView renders', () {
      for (final art in data.publishedPosts) {
        final body = _prerenderedBody(shells[art.slug]!);
        expect(body, contains('<h1>${escapeHtml(art.title)}</h1>'),
            reason: art.slug);
        expect(body, contains(escapeHtml(art.excerpt)), reason: art.slug);
        expect(body, contains('By ${escapeHtml(art.author.name)}'),
            reason: art.slug);
        if (art.keyTakeaways.isNotEmpty) {
          expect(body, contains('<h2>Key Takeaways</h2>'), reason: art.slug);
          expect(body, contains(escapeHtml(art.keyTakeaways.first)),
              reason: art.slug);
        }
        expect(body, contains('Topics: #'), reason: art.slug);
        // Nothing in the shipped copy may be a raw Markdown marker any more.
        expect(body, isNot(contains('<h2>## ')));
        expect(body, isNot(contains('## ')),
            reason: '${art.slug}: an unrendered heading marker leaked');
      }
    });

    test('an inline "1) …, 2) …" sentence stays a paragraph, not a fake <ol>',
        () {
      // Regression: the old line-based renderer matched `1)` and swallowed the
      // marker, rewriting one published post's closing checklist into a
      // one-item ordered list the app never displays.
      final post = data.publishedPosts
          .firstWhere((a) => a.slug == 'how-long-should-your-next-phone-last');
      final body = _prerenderedBody(buildArticleShell(post));
      expect(body, isNot(contains('<ol')));
      expect(body, contains('<p>1) Update commitment in years'));
      expect(body, contains('5) the specs everyone argues about first'));
    });

    test('markdown subset renders and unsupported constructs stay plain text',
        () {
      const source = '## Heading two\n'
          '\n'
          '### Heading three\n'
          '\n'
          'A paragraph with **bold** and `code`. Stay literal: '
          '[link](https://example.com), | a | table |, > block quote, 1.2 GHz.\n'
          '\n'
          '1. first\n'
          '2. second\n'
          '3. third\n'
          '\n'
          '5. five\n'
          '6. six\n'
          '\n'
          '- apple\n'
          '- pear\n'
          '\n'
          'Trailing **unpaired marker\n'
          '\n'
          'line one\n'
          'line two';
      final html = markdownToHtml(source);

      expect(html, contains('<h2>Heading two</h2>'));
      expect(html, contains('<h3>Heading three</h3>'));
      expect(html, contains('<strong>bold</strong>'));
      expect(html, contains('<code>code</code>'));
      // Deliberately plain text — the app renders these literally too:
      expect(html, contains('[link](https://example.com)'));
      expect(html, contains('| a | table |'));
      expect(html, contains('&gt; block quote'));
      expect(html, contains('1.2 GHz.'));
      expect(html, contains('Trailing **unpaired marker'));
      // Decimals and `1)` prose must never be turned into a list: the only
      // `<li>` items in this render come from the explicit fixtures below.
      expect(html, isNot(contains('<li>1.2 GHz')));
      for (final inline in const [
        '1) Update commitment in years, 2) battery health, 3) repairability',
        'Speed grade (1) to (5), storage (2 TB), price (3).',
        'Version 10.2 GHz. 1.25x faster than 1.0.',
      ]) {
        expect(markdownToHtml(inline), isNot(contains('<ol')),
            reason: inline);
        expect(markdownToHtml(inline), startsWith('<p>'), reason: inline);
      }
      // Real lists, with the original numbering preserved:
      const realLists = '1. first\n2. second\n\n5. five\n6. six\n\n'
          '- apple\n- pear';
      final listHtml = markdownToHtml(realLists);
      expect(listHtml, contains('<ol>\n<li>first</li>'));
      expect(listHtml, contains('<ol start="5">'));
      expect(listHtml, contains('<ul>\n<li>apple</li>'));
      // A multi-line block stays one paragraph with explicit breaks, matching
      // the single Text node the app builds for it.
      expect(html, contains('<p>line one<br>line two</p>'));
    });
  });

  group('shell escaping and HTML-injection safety', () {
    test('no raw <, > or " from editorial content reaches real shell markup',
        () {
      for (final art in data.publishedPosts) {
        final shell = shells[art.slug]!;
        final head = shell.substring(0, shell.indexOf('<body'));
        for (final m in RegExp(r'content="([^"]*)"|href="([^"]*)"')
            .allMatches(head)) {
          final value = (m.group(1) ?? m.group(2))!;
          expect(value, isNot(contains('<')), reason: art.slug);
          expect(value, isNot(contains('>')), reason: art.slug);
          expect(value, isNot(contains('"')), reason: art.slug);
        }
      }
    });

    test('every shipped shell exposes only the prerenderer\'s own attributes',
        () {
      // Whitelist of attribute names the prerenderer is allowed to emit. A
      // content-driven payload can only execute by adding an attribute that is
      // not in this set (an event handler, `formaction`, …).
      const allowed = {
        'charset', 'lang', 'name', 'content', 'property', 'rel', 'href',
        'type', 'id', 'src', 'async', 'style', 'http-equiv', 'sizes',
        'crossorigin', 'media',
      };
      final all = <String, String>{
        for (final a in data.publishedPosts) a.slug: shells[a.slug]!,
        for (final c in data.categories) c.slug: buildCategoryShell(c),
        'web/index.html': File('web/index.html').readAsStringSync(),
      };
      for (final entry in all.entries) {
        final live = _liveAttributeNames(entry.value);
        expect(live.difference(allowed), isEmpty, reason: entry.key);
        expect(live.where((a) => a.startsWith('on')), isEmpty,
            reason: '${entry.key}: event handler attribute');
        expect(_liveUrlAttributes(entry.value).where(_isExecutableUrl), isEmpty,
            reason: '${entry.key}: scriptable URL attribute');
        // Nothing may add a script element beyond the two the prerenderer
        // itself writes (structured data + Flutter bootstrap).
        expect(entry.value.split('<script').length - 1, lessThanOrEqualTo(2),
            reason: '${entry.key}: unexpected script element');
        expect(_tagsOf(entry.value).where((t) => RegExp('^<(img|svg|iframe|object|embed|link\\s+rel=stylesheet)')
            .hasMatch(t)), isEmpty, reason: '${entry.key}: foreign element');
      }
    });

    test('ampersands are entity-encoded in markup and raw in the JSON payload',
        () {
      final arts =
          data.publishedPosts.where((a) => a.categoryName.contains('&')).toList();
      expect(arts, isNotEmpty, reason: 'seed needs a category with an ampersand');
      for (final art in arts) {
        final shell = shells[art.slug]!;
        expect(_meta(shell, 'property', 'article:section'), art.categoryName,
            reason: '${art.slug}: decoded back to the raw value');
        final encodedSection = art.categoryName.replaceAll('&', '&amp;');
        expect(shell, contains(encodedSection),
            reason: '${art.slug}: markup must carry &amp;');
        final posting = (_jsonLd(shell)['@graph'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((n) => n['@type'] == 'BlogPosting');
        expect((posting['publisher'] as Map)['name'], SiteConfig.siteName);
        expect(jsonEncode(_jsonLd(shell)), contains(art.categoryName),
            reason: 'the JSON payload keeps the raw ampersand, not &amp;');
      }
    });

    test('escapeHtml covers every HTML-significant character', () {
      // A raw (backtick-free) string: the payload must reach escapeHtml intact.
      const raw = r'''<script>alert("x")</script> & 'quote' "''';
      final out = escapeHtml(raw);
      expect(out,
          '&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; &#39;quote&#39; &quot;');
      expect(out, isNot(contains('<')));
      expect(out, isNot(contains('>')));
      expect(out, isNot(contains('"')));
      expect(out, isNot(contains("'")));
    });

    test('hostile content cannot escape the JSON-LD script element', () {
      final shell = buildArticleShell(_hostileArticle());
      // One script element for the graph, one for the bootstrap: a breakout
      // would add more.
      expect(shell.split('<script').length - 1, 2, reason: shell);
      expect(shell.split('</script').length - 1, 2, reason: shell);
      expect(shell, isNot(contains('<img')));
      expect(shell, isNot(contains('<svg')));
      expect(shell, isNot(contains('<script>alert')));
      // The payload text does survive inside the document — but only as escaped
      // element content (`&lt;img …`) and as JSON string data. The one position
      // that would execute is an attribute of a real element, so assert on that
      // context instead of on the literal characters.
      expect(shell, contains('&lt;img src=x onerror=alert(1)&gt;'));
      expect(_liveAttributeNames(shell).where((a) => a.startsWith('on')),
          isEmpty,
          reason: 'an event handler reached a real HTML attribute: $shell');
      expect(_liveUrlAttributes(shell).where(_isExecutableUrl), isEmpty,
          reason: 'a javascript:/data: URL reached a real attribute: $shell');
      // The payload survives as data, not as markup.
      expect(shell, contains(r'\u003c/script'));
      final graph = _jsonLd(shell);
      final posting = (graph['@graph'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((n) => n['@type'] == 'BlogPosting');
      expect(posting['headline'], '</script><img src=x onerror=alert(1)>');
      expect(graph, SeoMeta.forArticle(_hostileArticle()).jsonLd);
    });

    test('hostile content cannot break attributes or inject body markup', () {
      final shell = buildArticleShell(_hostileArticle());
      final head = shell.substring(0, shell.indexOf('<body'));
      for (final m in RegExp(r'content="([^"]*)"|href="([^"]*)"')
          .allMatches(head)) {
        final value = (m.group(1) ?? m.group(2))!;
        expect(value, isNot(contains('<')));
        expect(value, isNot(contains('"')));
        expect(value, isNot(contains('>')));
      }
      final body = _prerenderedBody(shell);
      // Only the renderer's own tags may exist in the body.
      final tags = RegExp(r'<(/?[a-zA-Z0-9]+)[^>]*>')
          .allMatches(body)
          .map((m) => m.group(1)!.toLowerCase())
          .toSet();
      expect(
          tags.difference({
            'h1', 'h2', 'h3', 'p', 'ul', 'ol', 'li', 'br', 'strong', 'code',
            'div', '/h1', '/h2', '/h3', '/p', '/ul', '/ol', '/li', '/strong',
            '/code', '/div'
          }),
          isEmpty,
          reason: 'unexpected element(s) rendered from editorial content');
      // A "javascript:" URL only ever appears as visible text, never as a link.
      expect(body, isNot(contains('<a')));
      expect(body, isNot(contains('href=')));
      expect(body, contains('javascript:alert(4)'),
          reason: 'the literal text must still be shown, just inert');
      expect(body, isNot(contains('<img')));
      expect(body, contains('&lt;img'));
    });

    test('the encoder used for the injected graph is lossless', () {
      final graph = SeoMeta.forArticle(_hostileArticle()).jsonLd;
      final encoded = encodeJsonForScript(graph);
      expect(encoded, isNot(contains('<')));
      expect(encoded, isNot(contains('>')));
      expect(jsonDecode(encoded), graph);
    });
  });

  group('prerendered bundle on disk is current', () {
    test('every shell in build/web matches a fresh render (no stale shells)',
        () {
      if (!Directory(_builtBundle).existsSync()) {
        return; // nothing built yet — the build script owns this proof
      }
      var checked = 0;
      for (final art in data.publishedPosts) {
        final file = File('$_builtBundle/article/${art.slug}/index.html');
        expect(file.existsSync(), isTrue,
            reason: '${file.path} is missing — run '
                '`fvm.bat dart run tool/generate_prerender.dart` after the build');
        expect(file.readAsStringSync(), shells[art.slug],
            reason: '${art.slug}: the shipped shell is stale');
        checked++;
      }
      for (final cat in data.categories) {
        final file = File('$_builtBundle/${cat.slug}/index.html');
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
        expect(file.readAsStringSync(), buildCategoryShell(cat),
            reason: '${cat.slug}: the shipped category shell is stale');
        checked++;
      }
      expect(checked, 23, reason: '15 article + 8 category shells');
    });
  });
}

// ── helpers ───────────────────────────────────────────────────────────────

/// Captures everything printed by `debugPrint` while [body] runs.
String captureDebugPrint(void Function() body) {
  final buffer = StringBuffer();
  final previous = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) buffer.writeln(message);
  };
  try {
    body();
  } finally {
    debugPrint = previous;
  }
  return buffer.toString();
}

/// The `<...>` substrings of [html], ignoring comments and `<style>` bodies so
/// prose inside them is never mistaken for markup.
Iterable<String> _tagsOf(String html) => RegExp('<[^>]*>')
    .allMatches(html
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '<style>'))
    .map((m) => m.group(0)!);

/// Strips quoted attribute values so text that only *looks* like an attribute
/// because it is escaped data (`content="… &quot; onmouseover=&quot;alert(8)"`)
/// stops matching, while a genuine quote breakout (`content="x" onmouseover=`)
/// keeps matching. This is the context an XSS payload would need.
String _blankQuotedValues(String tag) => tag
    .replaceAll(RegExp(r'''"[^"]*"'''), '""')
    .replaceAll(RegExp(r"'[^']*'"), "''");

/// Lower-cased attribute *names* that exist outside quoted values.
Set<String> _liveAttributeNames(String html) => {
      for (final tag in _tagsOf(html))
        for (final m in RegExp(r'[a-zA-Z_:][-a-zA-Z0-9_:.]*(?=\s*=)')
            .allMatches(_blankQuotedValues(tag)))
          m.group(0)!.toLowerCase(),
    };

/// URL-bearing attribute values that are real attributes, not escaped data.
List<String> _liveUrlAttributes(String html) => [
      for (final tag in _tagsOf(html))
        for (final m in RegExp(
                r'\b(href|src|action|formaction|xlink:href|poster|data)\s*=\s*"([^"]*)"')
            .allMatches(tag))
          m.group(2)!,
    ];

bool _isExecutableUrl(String value) {
  final v = value.trimLeft().toLowerCase();
  return v.startsWith('javascript:') ||
      v.startsWith('vbscript:') ||
      v.startsWith('data:text/html');
}

/// The title the runtime `SeoService` claims it wrote, read back out of the
/// debug log line (the DOM layer is web-only, so this is the observation port).
String _logTitle(String log) {
  final m = RegExp('Title="(?<t>[^"]*)"').firstMatch(log);
  expect(m, isNotNull, reason: 'no [SEO] log line in: $log');
  return m!.namedGroup('t')!;
}

String _tag(String html, String tag) {
  final m = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(html);
  expect(m, isNotNull, reason: 'no <$tag> in the shell');
  return _unescape(m!.group(1)!);
}

/// Value of a `<meta name="…">` / `<meta property="…">` tag.
String? _meta(String html, String attribute, String key) {
  final m = RegExp(
          '<meta[^>]*$attribute="${RegExp.escape(key)}"[^>]*content="([^"]*)"')
      .firstMatch(html);
  return m == null ? null : _unescape(m.group(1)!);
}

/// Value of a `<link rel="…">` tag.
String? _link(String html, String rel) {
  final m = RegExp('<link[^>]*rel="${RegExp.escape(rel)}"[^>]*href="([^"]*)"')
      .firstMatch(html);
  return m == null ? null : _unescape(m.group(1)!);
}

String _unescape(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

String _prerenderedBody(String shell) {
  final m = RegExp('<div id="btp-prerendered-content">(.*)</div>', dotAll: true)
      .firstMatch(shell);
  expect(m, isNotNull, reason: 'shell has no prerendered body block');
  return m!.group(1)!;
}

Map<String, dynamic> _jsonLd(String shell) {
  final m = RegExp('<script type="application/ld\\+json"[^>]*>(.*?)</script>',
          dotAll: true)
      .firstMatch(shell);
  expect(m, isNotNull, reason: 'shell carries no JSON-LD');
  return Map<String, dynamic>.from(jsonDecode(m!.group(1)!) as Map);
}

/// The joined `posts` row PostgREST would return for [article], so the runtime
/// mapper can be pointed at the same data the seed holds.
Map<String, dynamic> _joinedPostRow(ArticleModel article, String seed) {
  final posts = parseTable(seed, 'public.posts', 30);
  final row = posts.firstWhere((p) => p.fields[5] == article.slug).fields;
  final category =
      parseTable(seed, 'public.categories', 12).firstWhere((c) => c.id == row[3]);
  final author =
      parseTable(seed, 'public.authors', 10).firstWhere((a) => a.id == row[2]);
  String? text(String v) => v == 'NULL' ? null : v;

  return <String, dynamic>{
    'id': row[0],
    'slug': row[5],
    'title': text(row[4]),
    'excerpt': text(row[6]),
    'content': text(row[7]),
    'featured_image': text(row[8]),
    'thumbnail_image': text(row[9]),
    'status': row[10],
    'published_at': text(row[11]),
    'updated_at': text(row[29]),
    'reading_time': int.tryParse(row[13]),
    'subcategory': text(row[24]),
    'is_featured': row[20] == 'true',
    'is_trending': row[21] == 'true',
    'is_popular': row[22] == 'true',
    'view_count': int.tryParse(row[23]),
    'key_takeaways': jsonDecode(row[25]),
    'faqs': jsonDecode(row[26]),
    'toc': jsonDecode(row[27]),
    'seo_title': text(row[14]),
    'seo_description': text(row[15]),
    'canonical_url': text(row[16]),
    'og_title': text(row[17]),
    'og_description': text(row[18]),
    'og_image': text(row[19]),
    'categories': {
      'name': category.fields[2],
      'slug': category.fields[3],
    },
    'authors': {
      'id': author.id,
      'name': author.fields[3],
      'slug': author.fields[4],
      'bio': author.fields[5],
      'avatar_url': author.fields[6],
      'designation': author.fields[7],
      'social_links': jsonDecode(author.fields[8]),
    },
    'tags': [
      for (final slug in article.tags) {'id': slug, 'name': slug, 'slug': slug}
    ],
  };
}

ArticleModel _hostileArticle() => _copy(
      _minimalArticle(),
      title: '</script><img src=x onerror=alert(1)>',
      excerpt: '"> <script>alert(1)</script>',
      content: '</script><svg onload=alert(2)>\n\n'
          '## </script><img src=x onerror=alert(3)>\n\n'
          'See [pwn](javascript:alert(4)) and **<img src=y onerror=alert(5)>** '
          'plus `</code></p><script>alert(6)</script>`.',
      seoTitle: '</title><script>alert(7)</script>',
      seoDescription: '" onmouseover="alert(8)',
      canonicalUrl: 'https://evil.example/"><script>alert(9)</script>',
      ogImage: 'x" onerror="alert(10)',
    );

/// A hand-built article with the same shape the repository produces, used for
/// injection probes (the seed itself is clean by design).
ArticleModel _minimalArticle() => ArticleModel(
      id: 'hostile-id',
      slug: 'hostile-probe',
      title: 'Baseline title',
      excerpt: 'Baseline excerpt.',
      content: '## Baseline\n\nBaseline paragraph.',
      categorySlug: 'ai',
      categoryName: 'AI & AI Tools',
      subcategory: '',
      tags: const ['ai', 'security'],
      author: const AuthorModel(
        id: 'author-id',
        slug: 'aravind-sharma',
        name: 'Aravind Sharma',
        role: 'Senior Editor',
        bio: 'Bio',
        avatarUrl: '',
        twitter: '',
        linkedin: '',
        email: '',
      ),
      publishedAt: DateTime.utc(2026, 10, 1, 9),
      updatedAt: DateTime.utc(2026, 10, 2, 9),
      featuredImage: '/images/hero.jpg',
      readingTimeMinutes: 4,
      keyTakeaways: const ['</script><img src=x onerror=alert(11)>'],
      faqs: const [
        ArticleFaq(
          question: '</script><b>bold question</b>',
          answer: '" onmouseover="alert(12) and <script>alert(13)</script>',
        ),
      ],
      toc: const [ArticleTocItem(id: 'baseline', title: 'Baseline')],
      seoTitle: 'Baseline SEO Title | Bharat Tech Pulse',
      seoDescription: 'Baseline description.',
      canonicalUrl: '${SiteConfig.domain}/article/hostile-probe',
      ogImage: '${SiteConfig.domain}/images/hero.jpg',
    );

/// `ArticleModel.copyWith` does not cover the SEO fields, so copy explicitly.
ArticleModel _copy(
  ArticleModel a, {
  String? title,
  String? excerpt,
  String? content,
  String? seoTitle,
  String? seoDescription,
  String? canonicalUrl,
  String? ogImage,
}) =>
    ArticleModel(
      id: a.id,
      slug: a.slug,
      title: title ?? a.title,
      excerpt: excerpt ?? a.excerpt,
      content: content ?? a.content,
      categorySlug: a.categorySlug,
      categoryName: a.categoryName,
      subcategory: a.subcategory,
      tags: a.tags,
      author: a.author,
      publishedAt: a.publishedAt,
      updatedAt: a.updatedAt,
      featuredImage: a.featuredImage,
      readingTimeMinutes: a.readingTimeMinutes,
      status: a.status,
      keyTakeaways: a.keyTakeaways,
      faqs: a.faqs,
      toc: a.toc,
      seoTitle: seoTitle ?? a.seoTitle,
      seoDescription: seoDescription ?? a.seoDescription,
      canonicalUrl: canonicalUrl ?? a.canonicalUrl,
      ogTitle: a.ogTitle,
      ogDescription: a.ogDescription,
      ogImage: ogImage ?? a.ogImage,
    );
