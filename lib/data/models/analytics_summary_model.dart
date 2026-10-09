/// Aggregated read-side numbers for the analytics screen. Every field comes
/// from a backend count, never a client-side estimate.
class AnalyticsSummary {
  /// `analytics_events` rows of type `page_view` inside the window. Null when
  /// the caller cannot read the event stream (site editor tier and above).
  final int? pageViews;
  final int? articleViews;

  /// Distinct `session_id` values seen in the scanned window.
  final int? uniqueSessions;

  /// Rows actually scanned while computing [uniqueSessions]; the backend has
  /// no aggregate RPC, so this is a capped scan and the number is a floor.
  final int eventsScanned;

  /// Newsletter subscribers, null when the caller may not read that table.
  final int? subscribers;

  final List<TopPostStat> topPosts;

  const AnalyticsSummary({
    this.pageViews,
    this.articleViews,
    this.uniqueSessions,
    this.eventsScanned = 0,
    this.subscribers,
    this.topPosts = const [],
  });

  /// False when the caller's role can read none of the private tables, which
  /// the analytics screen surfaces instead of rendering zeros as if they were
  /// real measurements.
  bool get hasAccess =>
      pageViews != null || articleViews != null || subscribers != null;
}

/// A post with its server-side read count.
class TopPostStat {
  final String id;
  final String title;
  final String slug;
  final int viewCount;

  const TopPostStat({
    required this.id,
    required this.title,
    required this.slug,
    required this.viewCount,
  });
}
