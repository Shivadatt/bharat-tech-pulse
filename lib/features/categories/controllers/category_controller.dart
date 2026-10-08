import 'package:get/get.dart';
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

  String get currentSlug {
    final route = Get.currentRoute;
    if (route.contains('/ai')) return 'ai';
    if (route.contains('/smartphones')) return 'smartphones';
    if (route.contains('/apps')) return 'apps';
    if (route.contains('/how-to')) return 'how-to';
    if (route.contains('/tech-news')) return 'tech-news';
    if (route.contains('/comparisons')) return 'comparisons';
    if (route.contains('/cyber-safety')) return 'cyber-safety';
    if (route.contains('/buying-guides')) return 'buying-guides';
    final paramSlug = Get.parameters['slug'];
    return paramSlug ?? 'ai';
  }

  @override
  void onInit() {
    super.onInit();
    loadCategory(currentSlug);
  }

  Future<void> loadCategory(String slug) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final cat = await categoryRepository.getCategoryBySlug(slug);
      category.value = cat;

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

      if (cat != null) {
        seoService.updateMeta(
          title: '${cat.name} — Bharat Tech Pulse',
          description: cat.description,
          canonicalPath: '/$slug/',
        );
      }
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
