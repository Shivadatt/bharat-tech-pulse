import 'package:get/get.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/repositories/article_repository.dart';
import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(
        articleRepository: Get.find<ArticleRepository>(),
        seoService: Get.find<SeoService>(),
      ),
    );
  }
}
