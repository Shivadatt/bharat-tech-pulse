import 'package:get/get.dart';
import '../../../../data/models/article_model.dart';
import '../../../../data/repositories/article_repository.dart';
import '../../../../data/repositories/post_admin_repository.dart';

/// Dashboard overview. Metric counts come from [PostAdminRepository.stats]
/// (backend counts, never list lengths); recent/top lists come from the
/// public [ArticleRepository].
class AdminDashboardController extends GetxController {
  final ArticleRepository articleRepository;
  final PostAdminRepository postAdminRepository;

  AdminDashboardController({
    required this.articleRepository,
    required this.postAdminRepository,
  });

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxList<ArticleModel> recentArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> topArticles = <ArticleModel>[].obs;

  final RxInt totalArticles = 0.obs;
  final RxInt publishedArticles = 0.obs;
  final RxInt draftArticles = 0.obs;
  final RxInt scheduledArticles = 0.obs;
  final RxInt totalViews = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardMetrics();
  }

  Future<void> loadDashboardMetrics() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final recent = await articleRepository.getLatestArticles(limit: 5);
      recentArticles.assignAll(recent);

      final top = await articleRepository.getPopularArticles(limit: 5);
      topArticles.assignAll(top);

      final stats = await postAdminRepository.stats();
      totalArticles.value = stats.total;
      publishedArticles.value = stats.published;
      draftArticles.value = stats.draft;
      scheduledArticles.value = stats.scheduled;
      totalViews.value = stats.totalReads;
    } on Object catch (e) {
      errorMessage.value = 'Could not load dashboard metrics ($e).';
    } finally {
      isLoading.value = false;
    }
  }
}
