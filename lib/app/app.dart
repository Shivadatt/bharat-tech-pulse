import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../features/static_pages/views/not_found_view.dart';
import 'bindings/initial_binding.dart';
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
        initialBinding: InitialBinding(),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        unknownRoute: GetPage(
          name: '/404',
          page: () => const NotFoundView(),
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
