import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/repositories/analytics_repository.dart';

/// Visitor-facing beacon. Writes the two event types the public
/// `analytics_events` RLS insert policy accepts (`page_view`, `article_view`)
/// and nothing else, so an anonymous visitor can never be denied mid-read.
///
/// Every call is fire-and-forget: a rejected beacon must never surface on a
/// public page. [AnalyticsRepository.track] already swallows PostgREST and
/// transport errors; `catchError` here only guards the paths it cannot see.
class AnalyticsService extends GetxService {
  static const _articlePathPrefix = '/article/';

  String? _sessionId;

  /// One id per app run. Persisting it would need a storage round-trip before
  /// the first beacon fires, which is not worth blocking the read path.
  String get _session => _sessionId ??=
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
      '-${Random().nextDouble().toStringAsFixed(10).substring(2)}';

  AnalyticsRepository? get _repository =>
      Get.isRegistered<AnalyticsRepository>()
          ? Get.find<AnalyticsRepository>()
          : null;

  void trackPageView(String routeName) {
    if (kDebugMode) {
      debugPrint('[Analytics] PageView: $routeName');
    }
    _beacon(() => _repository?.track(
          eventType: 'page_view',
          sessionId: _session,
          path: routeName,
        ));
  }

  void trackArticleRead(String slug, String category, {String? postId}) {
    if (kDebugMode) {
      debugPrint('[Analytics] Event: article_read, Params: '
          '{slug: $slug, category: $category}');
    }
    _beacon(() => _repository?.track(
          eventType: 'article_view',
          sessionId: _session,
          path: '$_articlePathPrefix$slug',
          postId: postId,
        ));
  }

  /// Unknown event names have no policy that would accept them, so this stays
  /// a debug-only hook for a future GA4/Plausible adapter.
  void trackEvent(String eventName, [Map<String, dynamic>? parameters]) {
    if (kDebugMode) {
      debugPrint('[Analytics] Event: $eventName, Params: $parameters');
    }
  }

  void _beacon(Future<void>? Function()? send) {
    try {
      final pending = send?.call();
      if (pending != null) {
        unawaited(pending.catchError((Object e) {
          if (kDebugMode) {
            debugPrint('[Analytics] beacon dropped: $e');
          }
        }));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Analytics] beacon dropped: $e');
      }
    }
  }
}
