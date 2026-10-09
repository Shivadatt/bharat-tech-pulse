import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/admin_article_stats_model.dart';
import '../models/article_model.dart';
import '../models/post_revision_model.dart';
import 'post_admin_repository.dart';
import 'supabase_article_repository.dart';

/// Supabase implementation of [PostAdminRepository].
///
/// Counts come from the database (`CountOption.exact`), never from list
/// lengths, so pagination can never make the dashboard under-report. Every
/// write is scoped with `.eq('site_id', siteId)` and verified through the
/// returned rows, so a no-op update is reported as a failure.
class SupabasePostAdminRepository implements PostAdminRepository {
  /// `view_count` has no PostgREST aggregate, so the read total is summed
  /// client-side over at most this many rows.
  static const int readsScanLimit = 1000;

  final SiteContext _site;
  SupabasePostAdminRepository({SiteContext? siteContext})
      : _site = siteContext ?? SiteContext();

  SupabaseClient get _client => SupabaseService.client;

  /// Lifecycle/flag columns an admin may patch. Deliberately independent from
  /// the editorial update map so a toggle can never rewrite the body.
  static Map<String, dynamic> patchToColumns({
    ArticleStatus? status,
    DateTime? scheduledFor,
    bool? clearScheduledFor,
    DateTime? publishedAt,
    bool? isTrending,
    bool? isFeatured,
    bool? isPopular,
  }) {
    final map = <String, dynamic>{};
    if (status != null) map['status'] = status.name;
    if (scheduledFor != null) {
      map['scheduled_for'] = scheduledFor.toUtc().toIso8601String();
    } else if (clearScheduledFor == true) {
      map['scheduled_for'] = null;
    }
    if (publishedAt != null) {
      map['published_at'] = publishedAt.toUtc().toIso8601String();
    }
    if (isTrending != null) map['is_trending'] = isTrending;
    if (isFeatured != null) map['is_featured'] = isFeatured;
    if (isPopular != null) map['is_popular'] = isPopular;
    return map;
  }

  /// `post_revisions` insert map. The table has no `site_id`; RLS authorises it
  /// through the parent post, so `post_id` is the only scope key sent.
  static Map<String, dynamic> revisionToColumns(PostRevisionModel revision,
          {String? editedBy}) =>
      {
        'post_id': revision.postId,
        'title': revision.title,
        'excerpt': revision.excerpt,
        'content': revision.content,
        'revision_number': revision.revisionNumber,
        'edited_by': editedBy,
      };

  static PostRevisionModel rowToRevision(Map<String, dynamic> row) =>
      PostRevisionModel.fromJson(row);

  static int sumViewCounts(List<Map<String, dynamic>> rows) =>
      rows.fold<int>(
          0, (sum, r) => sum + ((r['view_count'] as num?)?.toInt() ?? 0));

  Future<int> _count(String siteId, {ArticleStatus? status}) {
    final query =
        _client.from('posts').count(CountOption.exact).eq('site_id', siteId);
    return status == null ? query : query.eq('status', status.name);
  }

  @override
  Future<AdminArticleStats> stats() => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final total = await _count(siteId);
        final published = await _count(siteId, status: ArticleStatus.published);
        final draft = await _count(siteId, status: ArticleStatus.draft);
        final scheduled = await _count(siteId, status: ArticleStatus.scheduled);
        final archived = await _count(siteId, status: ArticleStatus.archived);

        final readRows = await _client
            .from('posts')
            .select('view_count')
            .eq('site_id', siteId)
            .range(0, readsScanLimit - 1);
        final totalReads = sumViewCounts(readRows);

        return AdminArticleStats(
          total: total,
          published: published,
          draft: draft,
          scheduled: scheduled,
          archived: archived,
          totalReads: totalReads,
          truncatedReads: total > readRows.length,
        );
      });

  @override
  Future<List<ArticleModel>> listAll({int limit = 20, int offset = 0}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('posts')
            .select(SupabaseArticleRepository.selectExpression)
            .eq('site_id', siteId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        return rows.map((r) => SupabaseArticleRepository.rowToArticle(r)).toList();
      });

  @override
  Future<List<ArticleModel>> listScheduled({
    bool upcomingOnly = true,
    int limit = 50,
    int offset = 0,
  }) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        var query = _client
            .from('posts')
            .select(SupabaseArticleRepository.selectExpression)
            .eq('site_id', siteId)
            .eq('status', ArticleStatus.scheduled.name);
        if (upcomingOnly) {
          query = query.gt(
              'scheduled_for', DateTime.now().toUtc().toIso8601String());
        }
        final rows = await query
            .order('scheduled_for', ascending: true)
            .range(offset, offset + limit - 1);
        return rows.map((r) => SupabaseArticleRepository.rowToArticle(r)).toList();
      });

  @override
  Future<bool> patch(
    String id, {
    ArticleStatus? status,
    DateTime? scheduledFor,
    bool? clearScheduledFor,
    DateTime? publishedAt,
    bool? isTrending,
    bool? isFeatured,
    bool? isPopular,
  }) =>
      guardPostgrest(() async {
        final columns = patchToColumns(
          status: status,
          scheduledFor: scheduledFor,
          clearScheduledFor: clearScheduledFor,
          publishedAt: publishedAt,
          isTrending: isTrending,
          isFeatured: isFeatured,
          isPopular: isPopular,
        );
        if (columns.isEmpty) return false;
        final siteId = await _site.siteId;
        final rows = await _client
            .from('posts')
            .update(columns)
            .eq('id', id)
            .eq('site_id', siteId)
            .select('id');
        return rows.isNotEmpty;
      });

  @override
  Future<List<PostRevisionModel>> revisions(String postId) =>
      guardPostgrest(() async {
        final rows = await _client
            .from('post_revisions')
            .select()
            .eq('post_id', postId)
            .order('revision_number', ascending: false)
            .range(0, 49);
        return rows.map((r) => rowToRevision(r)).toList();
      });

  @override
  Future<int> nextRevisionNumber(String postId) => guardPostgrest(() async {
        final rows = await _client
            .from('post_revisions')
            .select('revision_number')
            .eq('post_id', postId)
            .order('revision_number', ascending: false)
            .limit(1);
        final highest = rows.isEmpty
            ? 0
            : ((rows.first['revision_number'] as num?)?.toInt() ?? 0);
        return highest + 1;
      });

  @override
  Future<bool> createRevision(PostRevisionModel revision) =>
      guardPostgrest(() async {
        final userId = _client.auth.currentUser?.id;
        try {
          final row = await _client
              .from('post_revisions')
              .insert(revisionToColumns(revision, editedBy: userId))
              .select('id')
              .single();
          return row['id'] != null;
        } on PostgrestException catch (e) {
          // (post_id, revision_number) is unique: a concurrent edit claimed the
          // number first, so recompute it once and retry rather than losing
          // the snapshot.
          if (e.code == '23505') {
            final retry = await _client
                .from('post_revisions')
                .insert(revisionToColumns(
                  revision,
                  editedBy: userId,
                )..['revision_number'] = await nextRevisionNumber(revision.postId))
                .select('id')
                .single();
            return retry['id'] != null;
          }
          throw mapPostgrestException(e);
        }
      });
}
