import 'package:get/get.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/seo/seo_service.dart';
import '../../core/storage/storage_service.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/mock_article_repository.dart';
import '../../data/repositories/mock_category_repository.dart';
import '../../features/admin/articles/controllers/admin_article_controller.dart';
import '../../features/admin/auth/controllers/admin_auth_controller.dart';
import '../theme/theme_controller.dart';

/// App-wide initial dependency registration.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Core Services
    Get.put<StorageService>(StorageService(), permanent: true);
    Get.put<ThemeController>(ThemeController(), permanent: true);
    Get.put<SeoService>(SeoService(), permanent: true);
    Get.put<AnalyticsService>(AnalyticsService(), permanent: true);

    // Repository Inversion of Control (swappable with Supabase in Phase 2)
    Get.put<ArticleRepository>(MockArticleRepository(), permanent: true);
    Get.put<CategoryRepository>(MockCategoryRepository(), permanent: true);

    // Admin Controllers
    Get.lazyPut<AdminAuthController>(() => AdminAuthController(), fenix: true);
    Get.lazyPut<AdminArticleController>(
      () => AdminArticleController(
        articleRepository: Get.find<ArticleRepository>(),
        categoryRepository: Get.find<CategoryRepository>(),
      ),
      fenix: true,
    );
  }
}
