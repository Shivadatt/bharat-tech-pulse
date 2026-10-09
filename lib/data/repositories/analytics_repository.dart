import '../models/analytics_summary_model.dart';

/// Contract for the append-only `analytics_events` stream: public write,
/// editor-and-above read.
abstract class AnalyticsRepository {
  /// Records one beacon. Only `page_view` and `article_view` are accepted by
  /// the backend policy; other event types are rejected server-side.
  Future<void> track({
    required String eventType,
    required String sessionId,
    String? path,
    String? referrer,
    String? postId,
  });

  /// Aggregate numbers for the dashboard/analytics screens (editors+ only).
  Future<AnalyticsSummary> getSummary({int days = 30});
}
