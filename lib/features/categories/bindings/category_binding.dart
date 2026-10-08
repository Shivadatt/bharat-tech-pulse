import 'package:get/get.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../controllers/category_controller.dart';

class CategoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CategoryController>(
      () => CategoryController(
        articleRepository: Get.find<ArticleRepository>(),
        categoryRepository: Get.find<CategoryRepository>(),
        seoService: Get.find<SeoService>(),
      ),
    );
  }
}
