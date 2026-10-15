import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:india_tech_web/app/theme/theme_controller.dart';
import 'package:india_tech_web/core/analytics/analytics_service.dart';
import 'package:india_tech_web/core/seo/seo_meta.dart';
import 'package:india_tech_web/core/seo/seo_service.dart';
import 'package:india_tech_web/data/repositories/mock_article_repository.dart';
import 'package:india_tech_web/data/repositories/mock_category_repository.dart';
import 'package:india_tech_web/features/articles/controllers/article_controller.dart';
import 'package:india_tech_web/features/authors/controllers/author_controller.dart';
import 'package:india_tech_web/features/categories/controllers/category_controller.dart';
import 'package:india_tech_web/features/home/controllers/home_controller.dart';
import 'package:india_tech_web/features/search/controllers/search_page_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures the metadata a controller resolves instead of writing it to the
/// DOM, which `SeoService` only does when `kIsWeb` is true. `applyMeta` is the
/// single funnel every public entry point funnels through, so overriding it
/// here observes titles, canonicals and `robots` under `flutter test`.
class _RecordingSeoService extends SeoService {
  final List<SeoMeta> applied = [];

  @override
  void applyMeta(SeoMeta meta) => applied.add(meta);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GetX Controllers Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
    });

    test('ThemeController toggles theme between light and dark', () async {
      final themeController = ThemeController();
      themeController.themeMode.value = ThemeMode.dark;
      expect(themeController.isDarkMode, true);

      themeController.toggleTheme();
      expect(themeController.themeMode.value, ThemeMode.light);
      expect(themeController.isDarkMode, false);

      themeController.toggleTheme();
      expect(themeController.themeMode.value, ThemeMode.dark);
      expect(themeController.isDarkMode, true);
    });

    test('HomeController loads all home sections', () async {
      final articleRepo = MockArticleRepository();
      final seoService = SeoService();
      final homeController = HomeController(
        articleRepository: articleRepo,
        seoService: seoService,
      );

      expect(homeController.isLoading.value, true);
      await homeController.loadHomeData();

      expect(homeController.isLoading.value, false);
      expect(homeController.featuredArticle.value, isNotNull);
      expect(homeController.trendingArticles.isNotEmpty, true);
      expect(homeController.latestArticles.isNotEmpty, true);
      expect(homeController.aiArticles.isNotEmpty, true);
      expect(homeController.smartphoneArticles.isNotEmpty, true);
    });

    test('CategoryController filters subcategories', () async {
      final articleRepo = MockArticleRepository();
      final catRepo = MockCategoryRepository();
      final seoService = SeoService();
      final catController = CategoryController(
        articleRepository: articleRepo,
        categoryRepository: catRepo,
        seoService: seoService,
      );

      await catController.loadCategory('ai');
      expect(catController.category.value?.slug, 'ai');

      catController.filterSubcategory('Indic LLMs');
      expect(catController.selectedSubcategory.value, 'Indic LLMs');

      // Toggling same subcategory resets filter
      catController.filterSubcategory('Indic LLMs');
      expect(catController.selectedSubcategory.value, '');
    });

    test('SearchPageController executes search query', () async {
      final articleRepo = MockArticleRepository();
      final seoService = SeoService();
      final searchController = SearchPageController(
        articleRepository: articleRepo,
        seoService: seoService,
      );

      await searchController.performSearch('UPI');
      expect(searchController.hasSearched.value, true);
      expect(searchController.searchResults.isNotEmpty, true);
    });
  });

  group('Soft-404 SEO metadata', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
    });

    test('unknown article slug applies noindex, follow', () async {
      final seo = _RecordingSeoService();
      final controller = ArticleController(
        articleRepository: MockArticleRepository(),
        seoService: seo,
        analyticsService: AnalyticsService(),
      );

      await controller.loadArticle('no-such-article-anywhere');

      expect(controller.errorMessage.value, 'Article not found.');
      expect(seo.applied, hasLength(1));
      expect(seo.applied.single.robots, 'noindex, follow');
      expect(seo.applied.single.title, 'Article not found | Bharat Tech Pulse');
      expect(
        seo.applied.single.canonicalUrl,
        endsWith('/article/no-such-article-anywhere'),
      );
    });

    test('unknown author slug applies noindex, follow', () async {
      final seo = _RecordingSeoService();
      final controller = AuthorController(
        articleRepository: MockArticleRepository(),
        categoryRepository: MockCategoryRepository(),
        seoService: seo,
      );

      await controller.loadAuthor('not-a-real-author');

      expect(controller.errorMessage.value, 'Author not found.');
      expect(seo.applied, hasLength(1));
      expect(seo.applied.single.robots, 'noindex, follow');
      expect(seo.applied.single.title, 'Author not found | Bharat Tech Pulse');
    });

    test('found article keeps indexable robots', () async {
      final repository = MockArticleRepository();
      final seeded = await repository.getLatestArticles(limit: 1);
      final slug = seeded.first.slug;

      final seo = _RecordingSeoService();
      final controller = ArticleController(
        articleRepository: repository,
        seoService: seo,
        analyticsService: AnalyticsService(),
      );

      await controller.loadArticle(slug);

      expect(controller.article.value, isNotNull);
      expect(seo.applied.first.robots, contains('index'));
      expect(seo.applied.first.robots, isNot(contains('noindex')));
    });
  });
}
