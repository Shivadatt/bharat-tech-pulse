import 'package:get/get.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/repositories/article_repository.dart';
import '../controllers/article_controller.dart';

class ArticleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ArticleController>(
      () => ArticleController(
        articleRepository: Get.find<ArticleRepository>(),
        seoService: Get.find<SeoService>(),
        analyticsService: Get.find<AnalyticsService>(),
      ),
    );
  }
}
