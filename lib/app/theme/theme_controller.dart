import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages dynamic theme switching (System, Light, Dark) and persists preference.
class ThemeController extends GetxController {
  static const String _storageKey = 'selected_theme_mode';

  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;

  bool get isDarkMode {
    if (themeMode.value == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return themeMode.value == ThemeMode.dark;
  }

  @override
  void onInit() {
    super.onInit();
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_storageKey);
      if (savedMode != null) {
        switch (savedMode) {
          case 'light':
            themeMode.value = ThemeMode.light;
            break;
          case 'dark':
            themeMode.value = ThemeMode.dark;
            break;
          case 'system':
          default:
            themeMode.value = ThemeMode.system;
            break;
        }
      } else {
        // Default modern tech site to dark mode
        themeMode.value = ThemeMode.dark;
      }
      Get.changeThemeMode(themeMode.value);
    } catch (_) {
      themeMode.value = ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeString = 'dark';
      if (mode == ThemeMode.light) {
        modeString = 'light';
      } else if (mode == ThemeMode.system) {
        modeString = 'system';
      }
      await prefs.setString(_storageKey, modeString);
    } catch (_) {}
  }

  void toggleTheme() {
    if (isDarkMode) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}
