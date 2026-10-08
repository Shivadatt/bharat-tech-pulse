import 'package:get/get.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../controllers/author_controller.dart';

class AuthorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthorController>(
      () => AuthorController(
        articleRepository: Get.find<ArticleRepository>(),
        categoryRepository: Get.find<CategoryRepository>(),
        seoService: Get.find<SeoService>(),
      ),
    );
  }
}
