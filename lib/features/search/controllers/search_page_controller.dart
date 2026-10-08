import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/models/article_model.dart';
import '../../../data/repositories/article_repository.dart';

class SearchPageController extends GetxController {
  final ArticleRepository articleRepository;
  final SeoService seoService;

  SearchPageController({
    required this.articleRepository,
    required this.seoService,
  });

  final searchController = TextEditingController();
  final RxString currentQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<ArticleModel> searchResults = <ArticleModel>[].obs;
  final RxBool hasSearched = false.obs;

  @override
  void onInit() {
    super.onInit();
    seoService.updateMeta(
      title: 'Search Articles — Bharat Tech Pulse',
      description: 'Search technology guides, smartphone comparisons, and AI tutorials.',
      canonicalPath: '/search',
    );

    final initialQuery = Get.parameters['q'] ?? '';
    if (initialQuery.isNotEmpty) {
      searchController.text = initialQuery;
      performSearch(initialQuery);
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    currentQuery.value = cleanQuery;
    hasSearched.value = true;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final results = await articleRepository.searchArticles(cleanQuery);
      searchResults.assignAll(results);
    } catch (e) {
      errorMessage.value = 'Failed to execute search: $e';
    } finally {
      isLoading.value = false;
    }
  }
}
