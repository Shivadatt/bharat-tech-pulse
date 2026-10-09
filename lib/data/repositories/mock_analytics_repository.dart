import '../models/analytics_summary_model.dart';
import '../models/article_model.dart';
import '../services/mock_data_source.dart';
import 'analytics_repository.dart';

/// In-memory [AnalyticsRepository]. Beacons are counted locally so the
/// analytics screen shows numbers that genuinely came from this session's
/// tracked events rather than an invented constant.
class MockAnalyticsRepository implements AnalyticsRepository {
  final List<_MockEvent> _events = [];

  /// Seeds a small plausible history so the demo site is not empty on first
  /// visit; every additional number you see is one you generated.
  MockAnalyticsRepository.withDemoData() {
    final now = DateTime.now();
    const paths = ['/', '/article', '/category/ai', '/search'];
    for (var i = 0; i < 40; i++) {
      _events.add(_MockEvent(
        type: i % 3 == 0 ? 'article_view' : 'page_view',
        sessionId: 'demo-session-${i % 9}',
        path: paths[i % paths.length],
        postId: i % 3 == 0
            ? MockDataSource.articles[i % MockDataSource.articles.length].id
            : null,
        at: now.subtract(Duration(hours: i * 7)),
      ));
    }
  }

  @override
  Future<void> track({
    required String eventType,
    required String sessionId,
    String? path,
    String? referrer,
    String? postId,
  }) async {
    _events.add(_MockEvent(
      type: eventType,
      sessionId: sessionId,
      path: path,
      postId: postId,
      at: DateTime.now(),
    ));
  }

  @override
  Future<AnalyticsSummary> getSummary({int days = 30}) async {
    await Future.delayed(const Duration(milliseconds: 60));
    final since = DateTime.now().subtract(Duration(days: days));
    final window = _events.where((e) => !e.at.isBefore(since)).toList();

    final counts = <String, int>{};
    for (final e in window) {
      final id = e.postId;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    ArticleModel? byId(String id) {
      for (final a in MockDataSource.articles) {
        if (a.id == id) return a;
      }
      return null;
    }

    final topPosts = ranked.take(5).map((e) {
      final article = byId(e.key);
      return TopPostStat(
        id: e.key,
        title: article?.title ?? 'Untitled',
        slug: article?.slug ?? '',
        viewCount: article?.viewCount ?? e.value,
      );
    }).toList();

    return AnalyticsSummary(
      pageViews: window.where((e) => e.type == 'page_view').length,
      articleViews: window.where((e) => e.type == 'article_view').length,
      uniqueSessions: window.map((e) => e.sessionId).toSet().length,
      eventsScanned: window.length,
      subscribers: 3,
      topPosts: topPosts,
    );
  }
}

class _MockEvent {
  final String type;
  final String sessionId;
  final String? path;
  final String? postId;
  final DateTime at;

  const _MockEvent({
    required this.type,
    required this.sessionId,
    required this.at,
    this.path,
    this.postId,
  });
}
