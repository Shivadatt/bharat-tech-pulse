import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';
import 'app/app.dart';
import 'app/bindings/initial_binding.dart';
import 'app/config/site_config.dart';
import 'app/routes/app_routes.dart';
import 'core/platform/browser_path.dart';
import 'core/seo/seo_service.dart';

/// Paths GetX can resolve on a cold boot. Anything else is not-found:
/// GetX resolves unmatched deep links to the home route and never mounts
/// the unknownRoute page on boot, so the not-found metadata has to be
/// written into the shell before runApp.
const _exactRoutes = {
  AppRoutes.home,
  '/index.html',
  AppRoutes.search,
  AppRoutes.notFound,
  AppRoutes.ai,
  AppRoutes.smartphones,
  AppRoutes.apps,
  AppRoutes.howTo,
  AppRoutes.techNews,
  AppRoutes.comparisons,
  AppRoutes.cyberSafety,
  AppRoutes.buyingGuides,
  AppRoutes.about,
  AppRoutes.contact,
  AppRoutes.editorialPolicy,
  AppRoutes.privacyPolicy,
  AppRoutes.terms,
  AppRoutes.disclaimer,
  AppRoutes.admin,
  AppRoutes.adminLogin,
  AppRoutes.adminDashboard,
  AppRoutes.adminArticles,
  AppRoutes.adminArticleCreate,
  AppRoutes.adminCategories,
  AppRoutes.adminTags,
  AppRoutes.adminAuthors,
  AppRoutes.adminMedia,
  AppRoutes.adminTrending,
  AppRoutes.adminScheduled,
  AppRoutes.adminSeo,
  AppRoutes.adminAnalytics,
  AppRoutes.adminSettings,
};

bool _isKnownRoute(String path) =>
    _exactRoutes.contains(path) ||
    path.startsWith('/article/') ||
    path.startsWith('/author/') ||
    path.startsWith('/admin/articles/edit/');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Single dependency registration point; must run before runApp so the
  // root ThemeController lookup in BharatTechApp.build succeeds.
  InitialBinding().dependencies();

  if (kIsWeb) {
    usePathUrlStrategy();

    if (!_isKnownRoute(browserPath())) {
      void applyNotFoundMeta() {
        Get.find<SeoService>().updateMeta(
          title: 'Page Not Found',
          description: SiteConfig.description,
        );
      }

      applyNotFoundMeta();
      // Material's Title widget rewrites document.title to the bare app name
      // while the first frame builds; re-assert once it is done.
      WidgetsBinding.instance.addPostFrameCallback((_) => applyNotFoundMeta());
    }
  }

  runApp(const BharatTechApp());
}
