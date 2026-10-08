import 'package:get/get.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/repositories/article_repository.dart';
import '../controllers/search_page_controller.dart';

class SearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SearchPageController>(
      () => SearchPageController(
        articleRepository: Get.find<ArticleRepository>(),
        seoService: Get.find<SeoService>(),
      ),
    );
  }
}
