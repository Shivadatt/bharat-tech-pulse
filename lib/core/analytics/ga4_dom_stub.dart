/// VM/test stub: GA4 is a no-op outside a real browser. Kept API-identical to
/// the web implementation so [AnalyticsService] stays platform-agnostic.
class Ga4Dom {
  static bool isLoaded = false;

  static void init(String measurementId) {}

  static void pageView(String path, {String? title}) {}

  static void event(String name, [Map<String, Object?>? params]) {}
}
