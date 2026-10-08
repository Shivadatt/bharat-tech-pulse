import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../features/static_pages/views/not_found_view.dart';
import '../shared/widgets/page_seo_init.dart';
import 'config/site_config.dart';
import 'routes/app_pages.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class BharatTechApp extends StatelessWidget {
  const BharatTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      return GetMaterialApp(
        title: SiteConfig.siteName,
        debugShowCheckedModeBanner: false,
        // No hardcoded initialRoute: on web the browser URL boots the
        // matching page so deep links like /article/slug resolve directly.
        getPages: AppPages.routes,
        unknownRoute: GetPage(
          name: '/404',
          // PageSeoInit (not a middleware) because GetX skips middleware on
          // the initial deep link, and boots home beneath the unknown route —
          // initState here runs after HomeController and wins the title.
          page: () => PageSeoInit(
            title: 'Page Not Found',
            description: SiteConfig.description,
            child: const NotFoundView(),
          ),
        ),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeMode.value,
        defaultTransition: Transition.fadeIn,
        transitionDuration: const Duration(milliseconds: 200),
      );
    });
  }
}
