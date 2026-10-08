import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:india_tech_web/app/app.dart';
import 'package:india_tech_web/app/bindings/initial_binding.dart';
import 'package:india_tech_web/app/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    InitialBinding().dependencies();
  });

  testWidgets('BharatTechApp bootstraps and displays branding', (WidgetTester tester) async {
    await tester.pumpWidget(const BharatTechApp());
    await tester.pumpAndSettle();

    // Verify brand text rendered in RichText
    expect(
      find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('BHARAT')),
      findsWidgets,
    );
  });

  testWidgets('ThemeController switches modes reactively', (WidgetTester tester) async {
    await tester.pumpWidget(const BharatTechApp());
    await tester.pumpAndSettle();

    final themeController = Get.find<ThemeController>();
    themeController.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(themeController.isDarkMode, true);

    themeController.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();

    expect(themeController.isDarkMode, false);
  });
}
