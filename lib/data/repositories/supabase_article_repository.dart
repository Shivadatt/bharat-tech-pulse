import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/site_config.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/utils/slug_generator.dart';
import '../models/article_model.dart';
import '../models/author_model.dart';
import 'article_repository.dart';

/// Supabase/PostgREST implementation of [ArticleRepository].
///
/// All reads are site-scoped and public reads filter to
/// `status = published OR (status = scheduled AND scheduled_for <= now)`,
/// mirroring the RLS policy. Admin reads ([getAllArticlesForAdmin]) are
/// intentionally unfiltered.
class SupabaseArticleRepository implements ArticleRepository {
  /// Joined select used by every posts query. `tags` embeds through the
  /// `post_tags` junction (many-to-many detected by PostgREST).
  static const String selectExpression =
      '*, categories(name,slug), '
      'authors(id,name,slug,bio,avatar_url,designation,social_links), '
      'tags(name,slug)';

  /// Same embeds, but `tags` is an inner join so a single tag id can filter the
  /// parent posts. The `tags` array then holds only the matched tag.
  static const String tagFilteredSelect =
      '*, categories(name,slug), '
      'authors(id,name,slug,bio,avatar_url,designation,social_links), '
      'tags!inner(id,name,slug)';

  final SiteContext _site;
  SupabaseArticleRepository({SiteContext? siteContext})
      : _site = siteContext ?? SiteContext();

  SupabaseClient get _client => SupabaseService.client;

  // ---------------------------------------------------------------------------
  // Mapping (pure functions — unit-testable without network)
  // ---------------------------------------------------------------------------

  /// Blank author used when a post has no author row attached.
  static AuthorModel blankAuthor() => const AuthorModel(
        id: '',
        slug: '',
        name: '',
        role: '',
        bio: '',
        avatarUrl: '',
        twitter: '',
        linkedin: '',
        email: '',
      );

  /// Maps an `authors` table row onto [AuthorModel] (social_links jsonb is
  /// flattened into the legacy twitter/linkedin/email fields).
  static AuthorModel rowToAuthor(Map<String, dynamic> row) {
    final social = row['social_links'];
    return AuthorModel(
      id: row['id'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      name: row['name'] as String? ?? '',
      role: row['designation'] as String? ?? 'Tech Writer',
      bio: row['bio'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String? ?? '',
      twitter: social is Map ? (social['twitter'] as String? ?? '') : '',
      linkedin: social is Map ? (social['linkedin'] as String? ?? '') : '',
      email: social is Map ? (social['email'] as String? ?? '') : '',
    );
  }

  /// Maps a joined posts row (embeds from `categories`, `authors`, `tags`)
  /// onto [ArticleModel]. Falls back gracefully when embeds are absent.
  static ArticleModel rowToArticle(Map<String, dynamic> row) {
    final category = row['categories'];
    final authorRow = row['authors'];
    final tagRows = row['tags'];

    final publishedAt = DateTime.tryParse(
            row['published_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return ArticleModel(
      id: row['id'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      title: row['title'] as String? ?? '',
      excerpt: row['excerpt'] as String? ?? '',
      content: row['content'] as String? ?? '',
      categorySlug: category is Map
          ? (category['slug'] as String? ?? '')
          : (row['category_slug'] as String? ?? ''),
      categoryName: category is Map
          ? (category['name'] as String? ?? '')
          : (row['category_name'] as String? ?? ''),
      subcategory: row['subcategory'] as String? ?? '',
      tags: tagRows is List
          ? tagRows
              .map((e) =>
                  e is Map ? ((e['slug'] ?? e['name'] ?? '') as String) : e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
      author: authorRow is Map
          ? rowToAuthor(authorRow as Map<String, dynamic>)
          : blankAuthor(),
      publishedAt: publishedAt,
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          publishedAt,
      featuredImage: (row['featured_image'] as String? ?? '').isNotEmpty
          ? row['featured_image'] as String
          : (row['thumbnail_image'] as String? ?? ''),
      readingTimeMinutes: (row['reading_time'] as num?)?.toInt() ??
          (row['reading_time_minutes'] as num?)?.toInt() ??
          5,
      status: ArticleStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => ArticleStatus.published,
      ),
      scheduledFor: row['scheduled_for'] != null
          ? DateTime.tryParse(row['scheduled_for'].toString())
          : null,
      isFeatured: row['is_featured'] as bool? ?? false,
      isTrending: row['is_trending'] as bool? ?? false,
      isPopular: row['is_popular'] as bool? ?? false,
      viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
      keyTakeaways: (row['key_takeaways'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      faqs: (row['faqs'] as List?)
              ?.map((e) => ArticleFaq.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      toc: (row['toc'] as List?)
              ?.map((e) => ArticleTocItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Builds the flat `posts` insert map from a model. `view_count` is always
  /// initialized to 0 — clients never set counters. Pass [siteId],
  /// [categoryId] and [authorId] once resolved.
  static Map<String, dynamic> articleToInsertMap(
    ArticleModel article, {
    String? siteId,
    String? categoryId,
    String? authorId,
  }) {
    final map = <String, dynamic>{
      'slug': article.slug,
      'title': article.title,
      'excerpt': article.excerpt,
      'content': article.content,
      'subcategory': article.subcategory,
      'featured_image': article.featuredImage,
      'thumbnail_image': article.featuredImage,
      'status': article.status.name,
      'published_at': article.publishedAt.toIso8601String(),
      'scheduled_for': article.scheduledFor?.toIso8601String(),
      'reading_time': article.readingTimeMinutes,
      'seo_title': article.title,
      'seo_description': article.excerpt,
      'canonical_url': '${SiteConfig.domain}/article/${article.slug}',
      'og_title': article.title,
      'og_description': article.excerpt,
      'og_image': article.featuredImage,
      'is_featured': article.isFeatured,
      'is_trending': article.isTrending,
      'is_popular': article.isPopular,
      'view_count': 0,
      'key_takeaways': article.keyTakeaways,
      'faqs': article.faqs.map((f) => f.toJson()).toList(),
      'toc': article.toc.map((t) => t.toJson()).toList(),
    };
    if (siteId != null) map['site_id'] = siteId;
    if (categoryId != null) map['category_id'] = categoryId;
    if (authorId != null) map['author_id'] = authorId;
    return map;
  }

  /// Subset of columns safe to overwrite on update. Excludes identity,
  /// counters and SEO defaults so existing SEO customisations and
  /// `view_count` are never clobbered by a client edit.
  ///
  /// [categoryId]/[authorId] are always written — a null clears the foreign
  /// key, so a stale category/author from a previous edit can never linger.
  static Map<String, dynamic> articleToUpdateMap(
    ArticleModel article, {
    String? categoryId,
    String? authorId,
  }) {
    final map = articleToInsertMap(article);
    map.remove('site_id');
    map.remove('view_count');
    map.remove('published_at');
    map.remove('scheduled_for');
    map.remove('seo_title');
    map.remove('seo_description');
    map.remove('canonical_url');
    map.remove('og_title');
    map.remove('og_description');
    map.remove('og_image');
    map['category_id'] = categoryId;
    map['author_id'] = authorId;
    return map;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Posts query filtered to publicly visible articles:
  /// published, or scheduled with a go-live time already reached.
  /// [select] overrides the embed list (see [getArticlesByTag]).
  dynamic _publicQuery(String siteId, {String? select}) {
    final now = DateTime.now().toUtc().toIso8601String();
    return _client
        .from('posts')
        .select(select ?? selectExpression)
        .eq('site_id', siteId)
        .or('status.eq.published,and(status.eq.scheduled,'
            'scheduled_for.lte.$now)');
  }

  Future<String?> _resolveCategoryId(String siteId, String categorySlug) async {
    if (categorySlug.isEmpty) return null;
    final row = await _client
        .from('categories')
        .select('id')
        .eq('site_id', siteId)
        .eq('slug', categorySlug)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<String?> _resolveAuthorId(String siteId, AuthorModel author) async {
    if (author.id.isNotEmpty) {
      final byId = await _client
          .from('authors')
          .select('id')
          .eq('site_id', siteId)
          .eq('id', author.id)
          .maybeSingle();
      if (byId != null) return byId['id'] as String;
    }
    if (author.slug.isEmpty) return null;
    final bySlug = await _client
        .from('authors')
        .select('id')
        .eq('site_id', siteId)
        .eq('slug', author.slug)
        .maybeSingle();
    return bySlug?['id'] as String?;
  }

  /// Replaces the post's tag links. Resolves each tag by slug (creating
  /// missing tags site-scoped, admin flow only) and rewrites `post_tags`.
  Future<void> _syncTags(String siteId, String postId, List<String> tags) async {
    await _client.from('post_tags').delete().eq('post_id', postId);
    final seen = <String>{};
    for (final raw in tags) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      String slug;
      try {
        slug = SlugGenerator.generate(name);
      } on ValidationException {
        // A tag that cannot be slugified (e.g. non-Latin script) must not
        // block saving the whole article.
        continue;
      }
      if (!seen.add(slug)) continue;
      final existing = await _client
          .from('tags')
          .select('id')
          .eq('site_id', siteId)
          .eq('slug', slug)
          .maybeSingle();
      String tagId;
      if (existing != null) {
        tagId = existing['id'] as String;
      } else {
        final created = await _client
            .from('tags')
            .insert({'site_id': siteId, 'name': name, 'slug': slug})
            .select('id')
            .single();
        tagId = created['id'] as String;
      }
      await _client.from('post_tags').insert({
        'post_id': postId,
        'tag_id': tagId,
      });
    }
  }

  String _publicArticlePath(String slug) => '/article/$slug';

  // ---------------------------------------------------------------------------
  // Public reads
  // ---------------------------------------------------------------------------

  @override
  Future<List<ArticleModel>> getLatestArticles(
          {int limit = 12, int offset = 0}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _publicQuery(siteId)
            .order('published_at', ascending: false)
            .range(offset, offset + limit - 1);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  @override
  Future<List<ArticleModel>> getTrendingArticles({int limit = 6}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _publicQuery(siteId)
            .eq('is_trending', true)
            .order('published_at', ascending: false)
            .limit(limit);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  @override
  Future<List<ArticleModel>> getPopularArticles({int limit = 6}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _publicQuery(siteId)
            .eq('is_popular', true)
            .order('view_count', ascending: false)
            .limit(limit);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  @override
  Future<ArticleModel?> getFeaturedArticle() => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _publicQuery(siteId)
            .eq('is_featured', true)
            .order('published_at', ascending: false)
            .limit(1)
            .maybeSingle();
        return row == null ? null : rowToArticle(row);
      });

  @override
  Future<ArticleModel?> getArticleBySlug(String slug) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        var effectiveSlug = slug;

        // Single redirect hop: /article/<oldSlug> -> /article/<newSlug>.
        final redirect = await _client
            .from('redirects')
            .select('new_path')
            .eq('site_id', siteId)
            .eq('old_path', _publicArticlePath(slug))
            .maybeSingle();
        if (redirect != null) {
          final newPath = redirect['new_path'] as String?;
          final prefix = _publicArticlePath('');
          if (newPath != null && newPath.startsWith(prefix)) {
            effectiveSlug = newPath.substring(prefix.length);
          }
        }

        final row = await _publicQuery(siteId)
            .eq('slug', effectiveSlug)
            .maybeSingle();
        return row == null ? null : rowToArticle(row);
      });

  @override
  Future<List<ArticleModel>> getArticlesByCategory(String categorySlug,
          {int limit = 12}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final categoryId = await _resolveCategoryId(siteId, categorySlug);
        if (categoryId == null) return const <ArticleModel>[];
        final rows = await _publicQuery(siteId)
            .eq('category_id', categoryId)
            .order('published_at', ascending: false)
            .limit(limit);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  @override
  Future<List<ArticleModel>> getRelatedArticles(
          String currentSlug, String categorySlug,
          {int limit = 3}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final categoryId = await _resolveCategoryId(siteId, categorySlug);
        if (categoryId == null) return const <ArticleModel>[];
        final rows = await _publicQuery(siteId)
            .eq('category_id', categoryId)
            .neq('slug', currentSlug)
            .order('published_at', ascending: false)
            .limit(limit);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  @override
  Future<List<ArticleModel>> getArticlesByAuthor(String authorSlug,
          {int limit = 10}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final author = await _client
            .from('authors')
            .select('id')
            .eq('site_id', siteId)
            .eq('slug', authorSlug)
            .maybeSingle();
        if (author == null) return const <ArticleModel>[];
        final rows = await _publicQuery(siteId)
            .eq('author_id', author['id'])
            .order('published_at', ascending: false)
            .limit(limit);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  @override
  Future<List<ArticleModel>> getArticlesByTag(String tagSlug,
          {int limit = 10}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final tag = await _client
            .from('tags')
            .select('id')
            .eq('site_id', siteId)
            .eq('slug', tagSlug)
            .maybeSingle();
        if (tag == null) return const <ArticleModel>[];
        // Filter through the junction with an inner embed instead of shipping
        // every matching post id in an `in` clause (URL-length limit at scale).
        final rows = await _publicQuery(siteId, select: tagFilteredSelect)
            .eq('tags.id', tag['id'])
            .order('published_at', ascending: false)
            .limit(limit);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  @override
  Future<List<ArticleModel>> searchArticles(String query) =>
      guardPostgrest(() async {
        final q = query.trim();
        if (q.isEmpty) return const <ArticleModel>[];
        // Strip PostgREST/ilike filter metacharacters so free-text search cannot
        // break the or() clause or inject wildcards (`%` and `_`).
        final safe = q.replaceAll(RegExp(r'[,%_()]'), ' ').trim();
        if (safe.isEmpty) return const <ArticleModel>[];
        final siteId = await _site.siteId;
        final rows = await _publicQuery(siteId)
            .or('title.ilike.%$safe%,excerpt.ilike.%$safe%,'
                'content.ilike.%$safe%')
            .order('published_at', ascending: false);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  // ---------------------------------------------------------------------------
  // Admin / CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<List<ArticleModel>> getAllArticlesForAdmin() =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('posts')
            .select(selectExpression)
            .eq('site_id', siteId)
            .order('created_at', ascending: false);
        return rows.map((r) => rowToArticle(r)).toList();
      });

  @override
  Future<ArticleModel> createArticle(ArticleModel article) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final categoryId =
            await _resolveCategoryId(siteId, article.categorySlug);
        final authorId = await _resolveAuthorId(siteId, article.author);

        final row = await _client
            .from('posts')
            .insert(articleToInsertMap(
              article,
              siteId: siteId,
              categoryId: categoryId,
              authorId: authorId,
            ))
            .select(selectExpression)
            .single();
        final postId = row['id'] as String;
        await _syncTags(siteId, postId, article.tags);
        return rowToArticle(row);
      });

  @override
  Future<bool> updateArticle(ArticleModel article) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final existing = await _client
            .from('posts')
            .select('slug,title,content,excerpt,status,published_at,scheduled_for')
            .eq('site_id', siteId)
            .eq('id', article.id)
            .maybeSingle();
        if (existing == null) return false;

        final oldSlug = existing['slug'] as String? ?? '';
        final oldStatus = existing['status'] as String? ?? '';

        // Slug change: register the 301 first so the old URL never 404s.
        if (oldSlug.isNotEmpty && oldSlug != article.slug) {
          await _client.from('redirects').insert({
            'site_id': siteId,
            'old_path': _publicArticlePath(oldSlug),
            'new_path': _publicArticlePath(article.slug),
            'status_code': 301,
          });
        }

        // Editorial change: snapshot a revision before overwriting.
        final contentChanged = existing['title'] != article.title ||
            existing['content'] != article.content ||
            existing['excerpt'] != article.excerpt;
        if (contentChanged) {
          final latest = await _client
              .from('post_revisions')
              .select('revision_number')
              .eq('post_id', article.id)
              .order('revision_number', ascending: false)
              .limit(1)
              .maybeSingle();
          final next =
              ((latest?['revision_number'] as num?)?.toInt() ?? 0) + 1;
          await _client.from('post_revisions').insert({
            'post_id': article.id,
            'edited_by': _client.auth.currentUser?.id,
            'title': article.title,
            'content': article.content,
            'excerpt': article.excerpt,
            'revision_number': next,
          });
        }

        final updates = articleToUpdateMap(
          article,
          categoryId: await _resolveCategoryId(siteId, article.categorySlug),
          authorId: await _resolveAuthorId(siteId, article.author),
        );

        // Status transitions.
        if (article.status == ArticleStatus.published &&
            oldStatus != 'published') {
          updates['published_at'] =
              article.publishedAt.toIso8601String();
        }
        if (article.status == ArticleStatus.scheduled) {
          if (article.scheduledFor == null) {
            throw const ValidationException(
              'Scheduled articles require a scheduled date/time.',
            );
          }
          updates['scheduled_for'] =
              article.scheduledFor!.toUtc().toIso8601String();
        } else if (oldStatus == 'scheduled') {
          updates['scheduled_for'] = null;
        }

        updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

        // Strict update by id, scoped to this site; never upserts.
        await _client
            .from('posts')
            .update(updates)
            .eq('id', article.id)
            .eq('site_id', siteId);
        await _syncTags(siteId, article.id, article.tags);
        return true;
      });

  @override
  Future<bool> deleteArticle(String id) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final deleted = await _client
            .from('posts')
            .delete()
            .eq('site_id', siteId)
            .eq('id', id)
            .select('id');
        return deleted.isNotEmpty;
      });
}
