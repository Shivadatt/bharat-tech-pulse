import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence service abstraction.
class StorageService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> setString(String key, String value) async {
    await init();
    return _prefs!.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  Future<bool> setBool(String key, bool value) async {
    await init();
    return _prefs!.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  Future<bool> remove(String key) async {
    await init();
    return _prefs!.remove(key);
  }

  Future<bool> clear() async {
    await init();
    return _prefs!.clear();
  }
}
