import 'package:get/get.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/models/article_model.dart';
import '../../../data/repositories/article_repository.dart';

class ArticleController extends GetxController {
  final ArticleRepository articleRepository;
  final SeoService seoService;
  final AnalyticsService analyticsService;

  ArticleController({
    required this.articleRepository,
    required this.seoService,
    required this.analyticsService,
  });

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rx<ArticleModel?> article = Rx<ArticleModel?>(null);
  final RxList<ArticleModel> relatedArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> trendingArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> popularArticles = <ArticleModel>[].obs;

  String get currentSlug => Get.parameters['slug'] ?? '';

  @override
  void onInit() {
    super.onInit();
    final slug = currentSlug;
    if (slug.isNotEmpty) {
      loadArticle(slug);
    }
  }

  Future<void> loadArticle(String slug) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final art = await articleRepository.getArticleBySlug(slug);
      if (art == null) {
        errorMessage.value = 'Article not found.';
        return;
      }
      article.value = art;

      // Update SEO and Analytics
      seoService.updateArticleMeta(
        title: art.title,
        excerpt: art.excerpt,
        slug: art.slug,
        authorName: art.author.name,
        publishedAt: art.publishedAt,
        updatedAt: art.updatedAt,
        featuredImage: art.featuredImage,
        categoryName: art.categoryName,
      );

      analyticsService.trackArticleRead(art.slug, art.categorySlug);

      final related = await articleRepository.getRelatedArticles(art.slug, art.categorySlug);
      relatedArticles.assignAll(related);

      final trending = await articleRepository.getTrendingArticles(limit: 5);
      trendingArticles.assignAll(trending);

      final popular = await articleRepository.getPopularArticles(limit: 4);
      popularArticles.assignAll(popular);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
