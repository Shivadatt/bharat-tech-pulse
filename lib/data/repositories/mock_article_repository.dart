import '../../core/errors/app_exceptions.dart';
import '../models/article_model.dart';
import '../models/redirect_model.dart';
import '../services/mock_data_source.dart';
import 'article_repository.dart';

/// Concrete in-memory mock implementation of [ArticleRepository].
/// Ready to be swapped with SupabaseArticleRepository in the next phase.
class MockArticleRepository implements ArticleRepository {
  final List<ArticleModel> _storage = List.from(MockDataSource.articles);

  /// The `redirects` rows a slug rename writes (see [updateArticle]) and the
  /// hop [getArticleBySlug] follows — same demo mapping the redirects mock
  /// table seeds, so both mocks describe one store.
  final List<RedirectModel> _redirects = [
    RedirectModel(
      id: 'redir-1',
      oldPath: '/article/old-slug',
      newPath: '/article/new-slug',
      createdAt: DateTime(2026, 9, 1),
    ),
  ];

  String _articlePath(String slug) => '/article/$slug';

  /// Public read methods must never expose drafts or scheduled posts whose
  /// publish time has not arrived. Mirrors the WHERE clause the future
  /// Supabase implementation will enforce via RLS.
  bool _isPubliclyVisible(ArticleModel a) {
    final now = DateTime.now();
    return (a.status == ArticleStatus.published && !a.publishedAt.isAfter(now)) ||
        (a.status == ArticleStatus.scheduled &&
            a.scheduledFor != null &&
            !a.scheduledFor!.isAfter(now));
  }

  @override
  Future<List<ArticleModel>> getLatestArticles({int limit = 12, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 60));
    final sorted = List<ArticleModel>.from(_storage.where(_isPubliclyVisible))
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (offset >= sorted.length) return [];
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<List<ArticleModel>> getTrendingArticles({int limit = 6}) async {
    await Future.delayed(const Duration(milliseconds: 40));
    final trending = _storage
        .where((a) => a.isTrending && _isPubliclyVisible(a))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return trending.take(limit).toList();
  }

  @override
  Future<List<ArticleModel>> getPopularArticles({int limit = 6}) async {
    await Future.delayed(const Duration(milliseconds: 40));
    // Supabase filters `is_popular = true` first, then ranks the survivors by
    // view_count desc — curating "popular" is an editorial flag, not an
    // automatic top-N over every post.
    final sorted = List<ArticleModel>.from(_storage.where(
        (a) => a.isPopular && _isPubliclyVisible(a)))
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    return sorted.take(limit).toList();
  }

  @override
  Future<ArticleModel?> getFeaturedArticle() async {
    await Future.delayed(const Duration(milliseconds: 30));
    // Supabase takes the newest published_at among is_featured rows, not the
    // first stored match.
    final featured = _storage
        .where((a) => a.isFeatured && _isPubliclyVisible(a))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return featured.isEmpty ? null : featured.first;
  }

  @override
  Future<ArticleModel?> getArticleBySlug(String slug) async {
    await Future.delayed(const Duration(milliseconds: 60));
    // Single redirect hop, mirroring Supabase: /article/<oldSlug> resolves
    // through the redirects table to /article/<newSlug> so a renamed slug
    // never 404s.
    var effectiveSlug = slug;
    final hop = _redirects.where((r) => r.oldPath == _articlePath(slug));
    if (hop.isNotEmpty) {
      final newPath = hop.first.newPath;
      final prefix = _articlePath('');
      if (newPath.startsWith(prefix)) {
        effectiveSlug = newPath.substring(prefix.length);
      }
    }
    try {
      return _storage.firstWhere(
        (a) => a.slug == effectiveSlug && _isPubliclyVisible(a),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ArticleModel>> getArticlesByCategory(String categorySlug, {int limit = 12}) async {
    await Future.delayed(const Duration(milliseconds: 60));
    final rows = _storage
        .where((a) => a.categorySlug == categorySlug && _isPubliclyVisible(a))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return rows.take(limit).toList();
  }

  @override
  Future<List<ArticleModel>> getRelatedArticles(
      String currentSlug, String categorySlug, {int limit = 3}) async {
    await Future.delayed(const Duration(milliseconds: 40));
    final rows = _storage
        .where((a) =>
            a.slug != currentSlug &&
            a.categorySlug == categorySlug &&
            _isPubliclyVisible(a))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return rows.take(limit).toList();
  }

  @override
  Future<List<ArticleModel>> getArticlesByAuthor(String authorSlug, {int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final rows = _storage
        .where((a) => a.author.slug == authorSlug && _isPubliclyVisible(a))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return rows.take(limit).toList();
  }

  @override
  Future<List<ArticleModel>> getArticlesByTag(String tagSlug, {int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final rows = _storage
        .where((a) => a.tags.contains(tagSlug) && _isPubliclyVisible(a))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return rows.take(limit).toList();
  }

  @override
  Future<List<ArticleModel>> searchArticles(String query) async {
    await Future.delayed(const Duration(milliseconds: 70));
    // Mirrors the Supabase ilike search: only title/excerpt/content are
    // searched, PostgREST filter metacharacters (`% _ , ( )`) are stripped,
    // and every surviving term must match at least one of those fields
    // (per-term OR across fields, AND across terms), newest first.
    final terms = query
        .trim()
        .replaceAll(RegExp(r'[,%_()]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return [];
    final results = _storage.where((a) {
      if (!_isPubliclyVisible(a)) return false;
      final fields = [
        a.title.toLowerCase(),
        a.excerpt.toLowerCase(),
        a.content.toLowerCase(),
      ];
      return terms.every((term) {
        final q = term.toLowerCase();
        return fields.any((f) => f.contains(q));
      });
    }).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return results;
  }

  @override
  Future<List<ArticleModel>> getAllArticlesForAdmin() async {
    await Future.delayed(const Duration(milliseconds: 50));
    // Supabase orders this admin read `created_at desc`. ArticleModel carries
    // no created_at, so the mock's storage order is the equivalent: creates
    // prepend (newest first), updates and patches replace in place, so the
    // list is exactly reverse creation order.
    return List.from(_storage);
  }

  @override
  Future<ArticleModel> createArticle(ArticleModel article) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _ensureSlugIsUnique(article);
    _storage.insert(0, article);
    return article;
  }

  @override
  Future<bool> updateArticle(ArticleModel article) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _storage.indexWhere((a) => a.id == article.id);
    if (index == -1) return false;
    _ensureSlugIsUnique(article);
    // Slug change: register the redirect first, exactly like the Supabase
    // update, so /article/<oldSlug> keeps resolving via getArticleBySlug.
    // A pre-existing mapping for the old slug is kept, never overwritten
    // (the backend's UNIQUE (site_id, old_path) 23505 branch).
    final oldSlug = _storage[index].slug;
    if (oldSlug.isNotEmpty && oldSlug != article.slug) {
      final oldPath = _articlePath(oldSlug);
      if (!_redirects.any((r) => r.oldPath == oldPath)) {
        _redirects.insert(0, RedirectModel(
          id: 'redir-${DateTime.now().microsecondsSinceEpoch}',
          oldPath: oldPath,
          newPath: _articlePath(article.slug),
          statusCode: 301,
          createdAt: DateTime.now(),
        ));
      }
    }
    _storage[index] = article;
    return true;
  }

  /// `posts` is `UNIQUE (site_id, slug)` and the mock holds one site, so a
  /// duplicate slug must fail here exactly like the backend's 23505 does.
  /// Otherwise the local CMS happily stores two rows per URL and
  /// `getArticleBySlug` silently orphaned one of them.
  void _ensureSlugIsUnique(ArticleModel article) {
    if (_storage.any(
        (a) => a.slug == article.slug && a.id != article.id)) {
      throw const ValidationException(
        'An article with this slug already exists.',
      );
    }
  }

  @override
  Future<bool> deleteArticle(String id) async {
    await Future.delayed(const Duration(milliseconds: 80));
    final countBefore = _storage.length;
    _storage.removeWhere((a) => a.id == id);
    return _storage.length < countBefore;
  }
}
