import 'package:get/get.dart';
import '../../../../data/repositories/article_repository.dart';
import '../../../../data/repositories/post_admin_repository.dart';
import '../controllers/admin_dashboard_controller.dart';

class AdminDashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminDashboardController>(
      () => AdminDashboardController(
        articleRepository: Get.find<ArticleRepository>(),
        postAdminRepository: Get.find<PostAdminRepository>(),
      ),
    );
  }
}
