import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/seo/seo_service.dart';
import '../../core/storage/storage_service.dart';
import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/mock_analytics_repository.dart';
import '../../data/repositories/mock_article_repository.dart';
import '../../data/repositories/mock_category_repository.dart';
import '../../data/repositories/mock_media_repository.dart';
import '../../data/repositories/mock_post_admin_repository.dart';
import '../../data/repositories/mock_profile_repository.dart';
import '../../data/repositories/mock_redirect_repository.dart';
import '../../data/repositories/mock_site_settings_repository.dart';
import '../../data/repositories/mock_subscriber_repository.dart';
import '../../data/repositories/post_admin_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/redirect_repository.dart';
import '../../data/repositories/site_settings_repository.dart';
import '../../data/repositories/subscriber_repository.dart';
import '../../data/repositories/supabase_analytics_repository.dart';
import '../../data/repositories/supabase_article_repository.dart';
import '../../data/repositories/supabase_category_repository.dart';
import '../../data/repositories/supabase_media_repository.dart';
import '../../data/repositories/supabase_post_admin_repository.dart';
import '../../data/repositories/supabase_profile_repository.dart';
import '../../data/repositories/supabase_redirect_repository.dart';
import '../../data/repositories/supabase_site_settings_repository.dart';
import '../../data/repositories/supabase_subscriber_repository.dart';
import '../../features/admin/articles/controllers/admin_article_controller.dart';
import '../../features/admin/auth/controllers/admin_auth_controller.dart';
import '../config/environment_config.dart';
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

    // Repository Inversion of Control. Supabase repositories register only
    // when the backend was actually initialized; every default build/test
    // keeps the in-memory mocks so the site always boots.
    final useSupabase = EnvironmentConfig.useSupabase && SupabaseService.initialized;
    if (useSupabase) {
      Get.lazyPut<AuthService>(() => AuthService(), fenix: true);
      Get.put<ArticleRepository>(
          SupabaseArticleRepository(), permanent: true);
      Get.put<CategoryRepository>(
          SupabaseCategoryRepository(), permanent: true);
      Get.put<MediaRepository>(SupabaseMediaRepository(), permanent: true);
      final profiles = SupabaseProfileRepository();
      Get.put<ProfileRepository>(profiles, permanent: true);
      Get.put<PostAdminRepository>(
          SupabasePostAdminRepository(), permanent: true);
      Get.put<AnalyticsRepository>(
          SupabaseAnalyticsRepository(profileRepository: profiles),
          permanent: true);
      Get.put<RedirectRepository>(
          SupabaseRedirectRepository(), permanent: true);
      Get.put<SiteSettingsRepository>(
          SupabaseSiteSettingsRepository(), permanent: true);
      Get.put<SubscriberRepository>(
          SupabaseSubscriberRepository(), permanent: true);
    } else {
      Get.put<ArticleRepository>(MockArticleRepository(), permanent: true);
      Get.put<CategoryRepository>(MockCategoryRepository(), permanent: true);
      Get.put<MediaRepository>(MockMediaRepository(), permanent: true);
      Get.put<ProfileRepository>(MockProfileRepository(), permanent: true);
      Get.put<PostAdminRepository>(
          MockPostAdminRepository(), permanent: true);
      Get.put<AnalyticsRepository>(
          MockAnalyticsRepository.withDemoData(), permanent: true);
      Get.put<RedirectRepository>(
          MockRedirectRepository(), permanent: true);
      Get.put<SiteSettingsRepository>(
          MockSiteSettingsRepository(), permanent: true);
      Get.put<SubscriberRepository>(
          MockSubscriberRepository(), permanent: true);
    }

    // Admin Controllers
    Get.lazyPut<AdminAuthController>(() => AdminAuthController(), fenix: true);
    Get.lazyPut<AdminArticleController>(
      () => AdminArticleController(
        articleRepository: Get.find<ArticleRepository>(),
        categoryRepository: Get.find<CategoryRepository>(),
      ),
      fenix: true,
    );

    // Rehydrate a persisted admin session when the real backend is live.
    if (useSupabase) {
      try {
        unawaited(Get.find<AdminAuthController>().restoreSession());
      } catch (e) {
        debugPrint('Failed to restore admin session: $e');
      }
    }
  }
}
