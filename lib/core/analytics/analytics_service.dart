import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Analytics abstraction ready for future Google Analytics 4 / Plausible integration.
class AnalyticsService extends GetxService {
  void trackPageView(String routeName) {
    if (kDebugMode) {
      debugPrint('[Analytics] PageView: $routeName');
    }
  }

  void trackEvent(String eventName, [Map<String, dynamic>? parameters]) {
    if (kDebugMode) {
      debugPrint('[Analytics] Event: $eventName, Params: $parameters');
    }
  }

  void trackArticleRead(String slug, String category) {
    trackEvent('article_read', {
      'slug': slug,
      'category': category,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
