import 'package:get/get.dart';
import '../../../app/config/site_config.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_exceptions.dart';
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
    if (slug != _loadedSlug) {
      loadCategory(slug);
    }
  }

  /// False once a newer route has superseded this load, so a slow response for
  /// category A can never paint over the category the reader is on.
  bool _isCurrent(String slug) => _loadedSlug == slug;

  Future<void> loadCategory(String slug) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      // Recorded at request time, not on success: a route change that lands
      // mid-flight must be recognised as the newer request.
      _loadedSlug = slug;

      // Declared before the request: when the lookup itself fails, this URL
      // keeps its own canonical and stays out of the index instead of
      // inheriting the SPA shell's homepage canonical with `index, follow`.
      seoService.updateMeta(
        title: 'Articles',
        description: SiteConfig.description,
        canonicalPath: '/$slug/',
        robots: 'noindex, follow',
      );

      final cat = await categoryRepository.getCategoryBySlug(slug);
      if (!_isCurrent(slug)) return;
      if (cat == null) {
        Get.offNamed(AppRoutes.notFound);
        return;
      }
      category.value = cat;
      // Written before the article lists load: a failing follow-up request
      // must not leave the previous page's title and canonical on an
      // indexable category.
      seoService.updateCategorySeo(cat);

      final articles = await articleRepository.getArticlesByCategory(slug);
      if (!_isCurrent(slug)) return;
      if (articles.isNotEmpty) {
        featuredArticle.value = articles.first;
        categoryArticles.assignAll(articles.skip(1).toList());
      } else {
        featuredArticle.value = null;
        categoryArticles.clear();
      }

      final rails = await Future.wait([
        articleRepository.getTrendingArticles(limit: 5),
        articleRepository.getPopularArticles(limit: 4),
      ]);
      if (!_isCurrent(slug)) return;
      trendingArticles.assignAll(rails[0]);
      popularArticles.assignAll(rails[1]);
    } catch (e) {
      if (!_isCurrent(slug)) return;
      // A PostgREST/`AppException.toString()` reaches the visitor through
      // `ErrorState`; only the human-readable message may.
      errorMessage.value =
          e is AppException ? e.message : 'We could not load this section.';
    } finally {
      if (_isCurrent(slug)) isLoading.value = false;
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
