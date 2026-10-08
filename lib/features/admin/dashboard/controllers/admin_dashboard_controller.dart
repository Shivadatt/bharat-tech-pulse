import 'package:get/get.dart';
import '../../../../data/models/article_model.dart';
import '../../../../data/repositories/article_repository.dart';

class AdminDashboardController extends GetxController {
  final ArticleRepository articleRepository;

  AdminDashboardController({required this.articleRepository});

  final RxBool isLoading = true.obs;
  final RxList<ArticleModel> recentArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> topArticles = <ArticleModel>[].obs;

  // Mock dashboard metric counters
  final RxInt totalArticles = 21.obs;
  final RxInt publishedArticles = 19.obs;
  final RxInt draftArticles = 2.obs;
  final RxInt scheduledArticles = 3.obs;
  final RxInt totalViews = 345000.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardMetrics();
  }

  Future<void> loadDashboardMetrics() async {
    try {
      isLoading.value = true;
      final recent = await articleRepository.getLatestArticles(limit: 5);
      recentArticles.assignAll(recent);

      final top = await articleRepository.getPopularArticles(limit: 5);
      topArticles.assignAll(top);
    } finally {
      isLoading.value = false;
    }
  }
}
