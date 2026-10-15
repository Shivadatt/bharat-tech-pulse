import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';
import 'app/app.dart';
import 'app/bindings/initial_binding.dart';
import 'app/config/site_config.dart';
import 'app/routes/app_routes.dart';
import 'core/analytics/analytics_service.dart';
import 'core/platform/browser_path.dart';
import 'core/seo/seo_dom.dart';
import 'core/seo/seo_service.dart';
import 'core/supabase/supabase_service.dart';
import 'data/repositories/site_settings_repository.dart';

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

/// Trailing-slash-insensitive form of [_exactRoutes].
///
/// GetX compiles a declared route name `/ai/` into `^/ai/?$`
/// (see `GetPage._nameToRegex`: the name is suffixed with `/?`), so `/ai` and
/// `/ai/` BOTH render CategoryView. The cold-boot guard has to agree with that
/// or a valid page briefly carries "Page Not Found" metadata — and on a route
/// whose SEO is only applied after an async load, permanently if the load fails.
final Set<String> _normalizedRoutes =
    _exactRoutes.map(_withoutTrailingSlash).toSet();

String _withoutTrailingSlash(String path) =>
    (path.length > 1 && path.endsWith('/')) ? path.substring(0, path.length - 1) : path;

/// Public for tests: does this browser path resolve to a real GetPage on a cold
/// boot, or will the app render home beneath a not-found page?
bool isKnownColdBootPath(String rawPath) {
  final path = _withoutTrailingSlash(rawPath);
  return _normalizedRoutes.contains(path) ||
      (path.startsWith('/article/') && path.length > '/article/'.length) ||
      (path.startsWith('/author/') && path.length > '/author/'.length) ||
      (path.startsWith('/admin/articles/edit/') &&
          path.length > '/admin/articles/edit/'.length);
}

/// Reads the DB-held GA4 id without delaying first paint; the build-time
/// `GA_MEASUREMENT_ID` always wins inside AnalyticsService.
Future<void> _applyDatabaseGaId() async {
  try {
    final settings = await Get.find<SiteSettingsRepository>().getSettings();
    Get.find<AnalyticsService>().configureGa(settings?.googleAnalyticsId);
  } catch (e) {
    if (kDebugMode) debugPrint('[Analytics] no site_settings GA id: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bootstrap Supabase when configured (DATA_SOURCE=supabase + real
  // credentials). Failure is tolerated so development keeps running on mock
  // data; InitialBinding's guard is what refuses that in a production build.
  try {
    await SupabaseService.initialize();
  } catch (e, stackTrace) {
    debugPrint(
      'Supabase initialization failed; continuing without it. '
      'Error: $e\n$stackTrace',
    );
  }

  // Single dependency registration point; must run before runApp so the
  // root ThemeController lookup in BharatTechApp.build succeeds.
  InitialBinding().dependencies();

  // The GA4 id may live in site_settings rather than the build environment.
  unawaited(_applyDatabaseGaId());

  if (kIsWeb) {
    usePathUrlStrategy();

    if (!isKnownColdBootPath(browserPath())) {
      void applyNotFoundMeta() {
        Get.find<SeoService>().updateMeta(
          title: 'Page Not Found',
          description: SiteConfig.description,
          robots: 'noindex, follow',
        );
      }

      applyNotFoundMeta();
      // Material's Title widget rewrites document.title to the bare app name
      // while the first frame builds; re-assert once it is done.
      WidgetsBinding.instance.addPostFrameCallback((_) => applyNotFoundMeta());
    }
  }

  runApp(const BharatTechApp());

  if (kIsWeb) {
    // Prerendered shells carry the real article HTML for crawlers; drop that
    // copy once Flutter has painted, so visitors never see it twice.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => SeoDom.clearPrerenderedContent());
  }
}
