import 'package:get/get.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/models/article_model.dart';
import '../../../data/repositories/article_repository.dart';

class HomeController extends GetxController {
  final ArticleRepository articleRepository;
  final SeoService seoService;

  HomeController({
    required this.articleRepository,
    required this.seoService,
  });

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rx<ArticleModel?> featuredArticle = Rx<ArticleModel?>(null);
  final RxList<ArticleModel> trendingArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> latestArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> aiArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> appArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> howToArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> smartphoneArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> comparisonArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> cyberSafetyArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> popularArticles = <ArticleModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    seoService.updateMeta(
      title: 'Bharat Tech Pulse — Technology for Everyday India',
      description:
          'Actionable AI tools, unbiased smartphone reviews, practical how-to tutorials, and cyber safety alerts for Indian users.',
      canonicalPath: '/',
    );
    loadHomeData();
  }

  Future<void> loadHomeData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final results = await Future.wait([
        articleRepository.getFeaturedArticle(),
        articleRepository.getTrendingArticles(limit: 5),
        articleRepository.getLatestArticles(limit: 6),
        articleRepository.getArticlesByCategory('ai', limit: 3),
        articleRepository.getArticlesByCategory('apps', limit: 3),
        articleRepository.getArticlesByCategory('how-to', limit: 3),
        articleRepository.getArticlesByCategory('smartphones', limit: 3),
        articleRepository.getArticlesByCategory('comparisons', limit: 3),
        articleRepository.getArticlesByCategory('cyber-safety', limit: 3),
        articleRepository.getPopularArticles(limit: 4),
      ]);

      featuredArticle.value = results[0] as ArticleModel?;
      trendingArticles.assignAll(results[1] as List<ArticleModel>);
      latestArticles.assignAll(results[2] as List<ArticleModel>);
      aiArticles.assignAll(results[3] as List<ArticleModel>);
      appArticles.assignAll(results[4] as List<ArticleModel>);
      howToArticles.assignAll(results[5] as List<ArticleModel>);
      smartphoneArticles.assignAll(results[6] as List<ArticleModel>);
      comparisonArticles.assignAll(results[7] as List<ArticleModel>);
      cyberSafetyArticles.assignAll(results[8] as List<ArticleModel>);
      popularArticles.assignAll(results[9] as List<ArticleModel>);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
