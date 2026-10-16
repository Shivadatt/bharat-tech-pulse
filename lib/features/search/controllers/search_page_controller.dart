import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/config/site_config.dart';
import '../../../core/errors/app_exceptions.dart';
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
      title: 'Search Articles — ${SiteConfig.siteName}',
      description: 'Search technology guides, smartphone comparisons, and AI tutorials.',
      canonicalPath: '/search',
      robots: 'noindex, follow',
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

  int _requestId = 0;

  void clearSearch() {
    _requestId++;
    searchController.clear();
    currentQuery.value = '';
    hasSearched.value = false;
    errorMessage.value = '';
    searchResults.clear();
    isLoading.value = false;
  }

  /// GetX keys controllers by type, so this instance outlives a visit to an
  /// article and back, and `onInit` never runs a second time. Each route entry
  /// calls this from `initState` to put the screen back in sync with its URL.
  void syncRouteQuery() {
    final query = (Get.parameters['q'] ?? '').trim();
    if (query.isEmpty) {
      if (currentQuery.value.isNotEmpty || hasSearched.value) clearSearch();
      return;
    }
    if (query == currentQuery.value) return;
    searchController.text = query;
    performSearch(query);
  }

  Future<void> performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      // Returning early left the previous result set and the
      // `Found N stories for "…"` header on screen after the field was emptied.
      clearSearch();
      return;
    }

    final request = ++_requestId;
    currentQuery.value = cleanQuery;
    hasSearched.value = true;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final results = await articleRepository.searchArticles(cleanQuery);
      if (request != _requestId) return;
      searchResults.assignAll(results);
    } catch (e) {
      if (request != _requestId) return;
      errorMessage.value =
          e is AppException ? e.message : 'We could not run this search.';
    } finally {
      if (request == _requestId) isLoading.value = false;
    }
  }
}
