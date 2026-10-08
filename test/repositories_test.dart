import 'package:flutter_test/flutter_test.dart';
import 'package:india_tech_web/data/models/article_model.dart';
import 'package:india_tech_web/data/models/author_model.dart';
import 'package:india_tech_web/data/repositories/mock_article_repository.dart';
import 'package:india_tech_web/data/repositories/mock_category_repository.dart';

void main() {
  group('Mock Repositories Tests', () {
    late MockArticleRepository articleRepo;
    late MockCategoryRepository categoryRepo;

    setUp(() {
      articleRepo = MockArticleRepository();
      categoryRepo = MockCategoryRepository();
    });

    test('MockArticleRepository loads latest and trending articles', () async {
      final latest = await articleRepo.getLatestArticles(limit: 5);
      expect(latest.isNotEmpty, true);
      expect(latest.length <= 5, true);

      final trending = await articleRepo.getTrendingArticles(limit: 3);
      expect(trending.isNotEmpty, true);
      for (final art in trending) {
        expect(art.isTrending, true);
      }
    });

    test('MockArticleRepository searches articles by keyword', () async {
      final results = await articleRepo.searchArticles('AI');
      expect(results.isNotEmpty, true);
    });

    test('MockArticleRepository CRUD operations', () async {
      final newArticle = ArticleModel(
        id: 'test-crud-1',
        slug: 'test-crud-slug',
        title: 'New CRUD Test Story',
        excerpt: 'Short excerpt',
        content: 'Long body',
        categorySlug: 'ai',
        categoryName: 'AI & Tools',
        subcategory: 'Indic LLMs',
        tags: ['test'],
        author: const AuthorModel(
          id: 'auth-1',
          slug: 'author',
          name: 'Author',
          role: 'Writer',
          bio: '',
          avatarUrl: '',
          twitter: '',
          linkedin: '',
          email: '',
        ),
        publishedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        featuredImage: 'https://example.com/img.jpg',
        readingTimeMinutes: 4,
      );

      // Create
      await articleRepo.createArticle(newArticle);
      final fetched = await articleRepo.getArticleBySlug('test-crud-slug');
      expect(fetched, isNotNull);
      expect(fetched?.title, 'New CRUD Test Story');

      // Update
      final updatedArticle = fetched!.copyWith(title: 'Updated CRUD Story');
      await articleRepo.updateArticle(updatedArticle);
      final refetched = await articleRepo.getArticleBySlug('test-crud-slug');
      expect(refetched?.title, 'Updated CRUD Story');

      // Delete
      final deleted = await articleRepo.deleteArticle('test-crud-1');
      expect(deleted, true);
      final afterDelete = await articleRepo.getArticleBySlug('test-crud-slug');
      expect(afterDelete, isNull);
    });

    test('MockCategoryRepository returns categories and authors', () async {
      final categories = await categoryRepo.getCategories();
      expect(categories.length, 8);

      final authors = await categoryRepo.getAuthors();
      expect(authors.length >= 4, true);

      final aiCat = await categoryRepo.getCategoryBySlug('ai');
      expect(aiCat?.name, 'AI & AI Tools');
    });
  });
}
