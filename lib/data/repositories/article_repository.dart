import '../models/article_model.dart';

/// Abstract contract for Article data access.
/// Decouples UI controllers from concrete data sources (Mock vs Supabase).
abstract class ArticleRepository {
  Future<List<ArticleModel>> getLatestArticles({int limit = 12, int offset = 0});
  Future<List<ArticleModel>> getTrendingArticles({int limit = 6});
  Future<List<ArticleModel>> getPopularArticles({int limit = 6});
  Future<ArticleModel?> getFeaturedArticle();
  Future<ArticleModel?> getArticleBySlug(String slug);
  Future<List<ArticleModel>> getArticlesByCategory(String categorySlug, {int limit = 12});
  Future<List<ArticleModel>> getRelatedArticles(String currentSlug, String categorySlug, {int limit = 3});
  Future<List<ArticleModel>> getArticlesByAuthor(String authorSlug, {int limit = 10});
  Future<List<ArticleModel>> getArticlesByTag(String tagSlug, {int limit = 10});
  Future<List<ArticleModel>> searchArticles(String query);

  // Admin / CRUD methods
  Future<List<ArticleModel>> getAllArticlesForAdmin();
  Future<ArticleModel> createArticle(ArticleModel article);

  /// Updates an existing article. Returns false when [article.id] does not
  /// exist — implementations must never silently insert in this case.
  Future<bool> updateArticle(ArticleModel article);
  Future<bool> deleteArticle(String id);
}
