import 'package:flutter_test/flutter_test.dart';
import 'package:india_tech_web/core/errors/app_exceptions.dart';
import 'package:india_tech_web/data/models/article_model.dart';
import 'package:india_tech_web/data/models/author_model.dart';
import 'package:india_tech_web/data/repositories/mock_article_repository.dart';
import 'package:india_tech_web/data/repositories/mock_category_repository.dart';

const AuthorModel _testAuthor = AuthorModel(
  id: 'auth-1',
  slug: 'author',
  name: 'Author',
  role: 'Writer',
  bio: '',
  avatarUrl: '',
  twitter: '',
  linkedin: '',
  email: '',
);

ArticleModel _article(String id, String slug) => ArticleModel(
      id: id,
      slug: slug,
      title: 'Story about $slug',
      excerpt: 'Short excerpt',
      content: 'Long body',
      categorySlug: 'ai',
      categoryName: 'AI & Tools',
      subcategory: 'Indic LLMs',
      tags: const ['test'],
      author: _testAuthor,
      publishedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      featuredImage: 'https://example.com/img.jpg',
      readingTimeMinutes: 4,
    );

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

    test('MockArticleRepository search mirrors the production sanitizer',
        () async {
      final seed = await articleRepo.getLatestArticles(limit: 50);
      final words = seed
          .expand((a) => a.title.toLowerCase().split(RegExp(r'[^a-z]+')))
          .where((t) => t.length > 2)
          .toSet()
          .toList();
      expect(words.isNotEmpty, true, reason: 'seed needs a plain word');
      final word = words.first;

      final single = await articleRepo.searchArticles(word);
      expect(single.any((a) => a.title.toLowerCase().contains(word)), true);

      // A term nothing matches must empty the set (AND across terms); silently
      // ignoring it would return the first term's results alone.
      expect(await articleRepo.searchArticles('$word zzzqqxv'), isEmpty);

      // PostgREST ilike metacharacters must never reach the pattern.
      expect(await articleRepo.searchArticles('%'), isEmpty);
      expect(await articleRepo.searchArticles(','), isEmpty);
      expect(await articleRepo.searchArticles('_'), isEmpty);

      // "word's" used to split into "word" + "s"; the one-letter leftover
      // matched nothing, so a query with a real answer returned zero rows.
      final possessive = await articleRepo.searchArticles("$word's");
      expect(possessive.length, single.length);
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

    test('MockArticleRepository enforces the slug uniqueness the backend has',
        () async {
      await articleRepo.createArticle(_article('slug-1', 'shared-slug'));

      // posts is UNIQUE (site_id, slug): a duplicate has to fail the way the
      // Supabase 23505 does, not store a second row nobody can link to.
      await expectLater(
        articleRepo.createArticle(_article('slug-2', 'shared-slug')),
        throwsA(isA<ValidationException>()),
      );

      await articleRepo.createArticle(_article('slug-3', 'own-slug'));
      await expectLater(
        articleRepo.updateArticle(_article('slug-3', 'shared-slug')),
        throwsA(isA<ValidationException>()),
      );

      // Re-saving a row under its own slug is not a collision.
      await articleRepo.updateArticle(_article('slug-3', 'own-slug'));
      expect(await articleRepo.getArticleBySlug('own-slug'), isNotNull);
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
