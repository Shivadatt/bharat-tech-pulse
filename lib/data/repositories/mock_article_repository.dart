import '../models/article_model.dart';
import '../services/mock_data_source.dart';
import 'article_repository.dart';

/// Concrete in-memory mock implementation of [ArticleRepository].
/// Ready to be swapped with SupabaseArticleRepository in the next phase.
class MockArticleRepository implements ArticleRepository {
  final List<ArticleModel> _storage = List.from(MockDataSource.articles);

  @override
  Future<List<ArticleModel>> getLatestArticles({int limit = 12, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 60));
    final sorted = List<ArticleModel>.from(_storage)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (offset >= sorted.length) return [];
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<List<ArticleModel>> getTrendingArticles({int limit = 6}) async {
    await Future.delayed(const Duration(milliseconds: 40));
    return _storage
        .where((a) => a.isTrending)
        .take(limit)
        .toList();
  }

  @override
  Future<List<ArticleModel>> getPopularArticles({int limit = 6}) async {
    await Future.delayed(const Duration(milliseconds: 40));
    final sorted = List<ArticleModel>.from(_storage)
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    return sorted.take(limit).toList();
  }

  @override
  Future<ArticleModel?> getFeaturedArticle() async {
    await Future.delayed(const Duration(milliseconds: 30));
    try {
      return _storage.firstWhere((a) => a.isFeatured);
    } catch (_) {
      return _storage.isNotEmpty ? _storage.first : null;
    }
  }

  @override
  Future<ArticleModel?> getArticleBySlug(String slug) async {
    await Future.delayed(const Duration(milliseconds: 60));
    try {
      return _storage.firstWhere((a) => a.slug == slug);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ArticleModel>> getArticlesByCategory(String categorySlug, {int limit = 12}) async {
    await Future.delayed(const Duration(milliseconds: 60));
    return _storage
        .where((a) => a.categorySlug == categorySlug)
        .take(limit)
        .toList();
  }

  @override
  Future<List<ArticleModel>> getRelatedArticles(
      String currentSlug, String categorySlug, {int limit = 3}) async {
    await Future.delayed(const Duration(milliseconds: 40));
    return _storage
        .where((a) => a.slug != currentSlug && a.categorySlug == categorySlug)
        .take(limit)
        .toList();
  }

  @override
  Future<List<ArticleModel>> getArticlesByAuthor(String authorSlug, {int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _storage
        .where((a) => a.author.slug == authorSlug)
        .take(limit)
        .toList();
  }

  @override
  Future<List<ArticleModel>> getArticlesByTag(String tagSlug, {int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _storage
        .where((a) => a.tags.contains(tagSlug))
        .take(limit)
        .toList();
  }

  @override
  Future<List<ArticleModel>> searchArticles(String query) async {
    await Future.delayed(const Duration(milliseconds: 70));
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    return _storage.where((a) {
      return a.title.toLowerCase().contains(q) ||
          a.excerpt.toLowerCase().contains(q) ||
          a.content.toLowerCase().contains(q) ||
          a.categoryName.toLowerCase().contains(q) ||
          a.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Future<List<ArticleModel>> getAllArticlesForAdmin() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.from(_storage);
  }

  @override
  Future<ArticleModel> createArticle(ArticleModel article) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _storage.insert(0, article);
    return article;
  }

  @override
  Future<ArticleModel> updateArticle(ArticleModel article) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _storage.indexWhere((a) => a.id == article.id);
    if (index != -1) {
      _storage[index] = article;
    } else {
      _storage.add(article);
    }
    return article;
  }

  @override
  Future<bool> deleteArticle(String id) async {
    await Future.delayed(const Duration(milliseconds: 80));
    final countBefore = _storage.length;
    _storage.removeWhere((a) => a.id == id);
    return _storage.length < countBefore;
  }
}
