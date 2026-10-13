import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/repositories/analytics_repository.dart';
import 'ga4_dom.dart';

/// Visitor-facing beacon. Writes the two event types the public
/// `analytics_events` RLS insert policy accepts (`page_view`, `article_view`)
/// and nothing else, so an anonymous visitor can never be denied mid-read.
///
/// Every call is fire-and-forget: a rejected beacon must never surface on a
/// public page. [AnalyticsRepository.track] already swallows PostgREST and
/// transport errors; `catchError` here only guards the paths it cannot see.
class AnalyticsService extends GetxService {
  static const _articlePathPrefix = '/article/';

  /// Build-time GA4 id (`--dart-define=GA_MEASUREMENT_ID=G-XXXXXXXXXX`).
  /// Never hardcoded: an empty string means GA stays inert.
  static const String _envMeasurementId =
      String.fromEnvironment('GA_MEASUREMENT_ID', defaultValue: '');

  String? _sessionId;

  String? _gaId;
  String? _lastGaRoute;
  bool get _gaActive => kIsWeb && _gaId != null && _gaId!.isNotEmpty;

  /// Effective GA id: the build-time value wins, otherwise the DB
  /// `site_settings.google_analytics_id` supplied via [configureGa].
  String? get gaMeasurementId => _gaId;

  void _resolveGa() {
    if (_gaId != null && _gaId!.isNotEmpty) return;
    if (_envMeasurementId.isNotEmpty) {
      _gaId = _envMeasurementId;
      Ga4Dom.init(_envMeasurementId);
    }
  }

  /// Optional runtime override from `site_settings.google_analytics_id`.
  /// Ignored once a build-time id is present and never re-inits the tag.
  void configureGa(String? fromDatabase) {
    final id = fromDatabase?.trim() ?? '';
    if (id.isEmpty) return;
    if (_envMeasurementId.isNotEmpty) return;
    if (_gaId == id) return;
    _gaId = id;
    Ga4Dom.init(id);
  }

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
    _resolveGa();
    if (_gaActive && routeName != _lastGaRoute) {
      _lastGaRoute = routeName;
      Ga4Dom.pageView(routeName);
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
    _resolveGa();
    if (_gaActive) {
      Ga4Dom.event('article_view', <String, Object?>{
        'article_slug': slug,
        'article_category': category,
        'post_id': ?postId,
      });
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
