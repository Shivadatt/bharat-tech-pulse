import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/repositories/category_repository.dart';

class CategoryController extends GetxController {
  final ArticleRepository articleRepository;
  final CategoryRepository categoryRepository;
  final SeoService seoService;

  CategoryController({
    required this.articleRepository,
    required this.categoryRepository,
    required this.seoService,
  });

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rx<CategoryModel?> category = Rx<CategoryModel?>(null);
  final Rx<ArticleModel?> featuredArticle = Rx<ArticleModel?>(null);
  final RxList<ArticleModel> categoryArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> trendingArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> popularArticles = <ArticleModel>[].obs;
  final RxString selectedSubcategory = ''.obs;

  // The controller is type-keyed, so GetX keeps this same instance alive when
  // the user navigates from one category route straight into another. Track
  // which slug is loaded so the view can reload on route change.
  String? _loadedSlug;

  String get currentSlug {
    return Get.parameters['slug'] ?? 'ai';
  }

  @override
  void onInit() {
    super.onInit();
    loadCategory(currentSlug);
  }

  void ensureCurrentRouteLoaded() {
    final slug = currentSlug;
    if (slug != _loadedSlug && !isLoading.value) {
      loadCategory(slug);
    }
  }

  Future<void> loadCategory(String slug) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final cat = await categoryRepository.getCategoryBySlug(slug);
      if (cat == null) {
        Get.offNamed(AppRoutes.notFound);
        return;
      }
      category.value = cat;
      _loadedSlug = slug;

      final articles = await articleRepository.getArticlesByCategory(slug);
      if (articles.isNotEmpty) {
        featuredArticle.value = articles.first;
        categoryArticles.assignAll(articles.skip(1).toList());
      } else {
        featuredArticle.value = null;
        categoryArticles.clear();
      }

      final trending = await articleRepository.getTrendingArticles(limit: 5);
      trendingArticles.assignAll(trending);

      final popular = await articleRepository.getPopularArticles(limit: 4);
      popularArticles.assignAll(popular);

      seoService.updateMeta(
        title: '${cat.name} — Bharat Tech Pulse',
        description: cat.description,
        canonicalPath: '/$slug/',
      );
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void filterSubcategory(String subcategory) {
    if (selectedSubcategory.value == subcategory) {
      selectedSubcategory.value = '';
    } else {
      selectedSubcategory.value = subcategory;
    }
  }

  List<ArticleModel> get filteredArticles {
    if (selectedSubcategory.value.isEmpty) {
      return categoryArticles;
    }
    return categoryArticles
        .where((a) => a.subcategory.toLowerCase() == selectedSubcategory.value.toLowerCase())
        .toList();
  }
}
