import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/role_permissions.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/analytics_summary_model.dart';
import 'analytics_repository.dart';
import 'profile_repository.dart';
import 'supabase_profile_repository.dart';

/// Supabase implementation of [AnalyticsRepository].
///
/// The `analytics_events` INSERT policy is restricted to the two whitelisted
/// event types, and its SELECT policy is `is_site_editor(site_id)` — so
/// [getSummary] resolves the caller's real site role first and throws instead
/// of rendering server-blocked reads as a suspiciously quiet zero.
class SupabaseAnalyticsRepository implements AnalyticsRepository {
  static const Set<String> _allowedEvents = {'page_view', 'article_view'};

  /// Cap on the scan used to count distinct sessions (PostgREST has no
  /// COUNT(DISTINCT)); [AnalyticsSummary.eventsScanned] reports it.
  static const int sessionScanLimit = 1000;

  final SiteContext _site;
  final ProfileRepository _profiles;

  SupabaseAnalyticsRepository({
    SiteContext? siteContext,
    ProfileRepository? profileRepository,
  })  : _site = siteContext ?? SiteContext(),
        _profiles = profileRepository ?? SupabaseProfileRepository();

  SupabaseClient get _client => SupabaseService.client;

  static Map<String, dynamic> eventInsertColumns({
    required String siteId,
    required String eventType,
    required String sessionId,
    String? path,
    String? referrer,
    String? postId,
  }) =>
      {
        'site_id': siteId,
        'event_type': eventType,
        'session_id': sessionId,
        'path': (path ?? '').isEmpty ? null : path,
        'referrer': (referrer ?? '').isEmpty ? null : referrer,
        'post_id': (postId ?? '').isEmpty ? null : postId,
      };

  /// Pure helper: distinct non-null session ids across a scanned window.
  static Set<String> distinctSessions(List<Map<String, dynamic>> rows) {
    final ids = <String>{};
    for (final r in rows) {
      final s = r['session_id'] as String?;
      if (s != null && s.isNotEmpty) ids.add(s);
    }
    return ids;
  }

  static TopPostStat rowToTopPost(Map<String, dynamic> row) => TopPostStat(
        id: row['id'] as String? ?? '',
        title: row['title'] as String? ?? '',
        slug: row['slug'] as String? ?? '',
        viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
      );

  @override
  Future<void> track({
    required String eventType,
    required String sessionId,
    String? path,
    String? referrer,
    String? postId,
  }) async {
    if (!_allowedEvents.contains(eventType)) {
      throw ValidationException('Event type "$eventType" is not accepted.');
    }
    try {
      final siteId = await _site.siteId;
      await _client
          .from('analytics_events')
          .insert(eventInsertColumns(
            siteId: siteId,
            eventType: eventType,
            sessionId: sessionId,
            path: path,
            referrer: referrer,
            postId: postId,
          ))
          .select('id')
          .single();
    } on PostgrestException catch (e) {
      debugPrint('analytics beacon rejected: ${e.code}');
    } on AppException catch (e) {
      debugPrint('analytics beacon failed: ${e.message}');
    } catch (_) {
      debugPrint('analytics beacon failed');
    }
  }

  Future<bool> _canReadReports() async {
    final profile = await _profiles.loadCurrentProfile();
    if (profile == null || !profile.isActive) return false;
    if (!profile.hasSiteAccess) return false;
    return RolePermissions.canViewReports(profile.effectiveRole);
  }

  @override
  Future<AnalyticsSummary> getSummary({int days = 30}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final canRead = await _canReadReports();
        if (!canRead) {
          throw const AppException(
            "You don't have permission to view analytics reports for this site.",
          );
        }

        final since =
            DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

        Future<int> eventCount(String type) => _client
            .from('analytics_events')
            .count(CountOption.exact)
            .eq('site_id', siteId)
            .eq('event_type', type)
            .gte('created_at', since);

        final pageViews = await eventCount('page_view');
        final articleViews = await eventCount('article_view');
        final totalEvents = await _client
            .from('analytics_events')
            .count(CountOption.exact)
            .eq('site_id', siteId)
            .gte('created_at', since);

        final scanRows = await _client
            .from('analytics_events')
            .select('session_id')
            .eq('site_id', siteId)
            .gte('created_at', since)
            .range(0, sessionScanLimit - 1);
        final uniqueSessions = distinctSessions(scanRows).length;

        int? subscribers;
        try {
          subscribers =
              await _client.from('subscribers').count(CountOption.exact).eq('site_id', siteId);
        } on PostgrestException {
          subscribers = null;
        }

        final topRows = await _client
            .from('posts')
            .select('id,title,slug,view_count')
            .eq('site_id', siteId)
            .order('view_count', ascending: false)
            .limit(5);

        return AnalyticsSummary(
          pageViews: pageViews,
          articleViews: articleViews,
          uniqueSessions: uniqueSessions,
          eventsScanned: totalEvents < sessionScanLimit ? totalEvents : scanRows.length,
          subscribers: subscribers,
          topPosts: topRows.map(rowToTopPost).toList(),
        );
      });
}
