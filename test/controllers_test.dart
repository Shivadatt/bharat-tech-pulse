import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:india_tech_web/app/theme/theme_controller.dart';
import 'package:india_tech_web/core/seo/seo_service.dart';
import 'package:india_tech_web/data/repositories/mock_article_repository.dart';
import 'package:india_tech_web/data/repositories/mock_category_repository.dart';
import 'package:india_tech_web/features/categories/controllers/category_controller.dart';
import 'package:india_tech_web/features/home/controllers/home_controller.dart';
import 'package:india_tech_web/features/search/controllers/search_page_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
