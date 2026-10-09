import '../models/admin_article_stats_model.dart';
import '../models/article_model.dart';
import '../models/post_revision_model.dart';

/// Admin-only reads and targeted writes over `posts`.
///
/// Split from [ArticleRepository] because the public site never needs backend
/// counts, revision history or partial status patches, and because the
/// editorial update path (`ArticleRepository.updateArticle`) deliberately
/// overwrites the whole body while these helpers must touch only the columns
/// an admin toggles.
abstract class PostAdminRepository {
  /// Counts straight from the backend for the caller's visible posts.
  Future<AdminArticleStats> stats();

  /// Every post the caller may see (RLS-filtered), newest first, paginated.
  Future<List<ArticleModel>> listAll({int limit = 20, int offset = 0});

  /// Scheduled posts. [upcomingOnly] keeps future go-live times only, which is
  /// what the scheduled screen shows versus the already-live backlog.
  Future<List<ArticleModel>> listScheduled({
    bool upcomingOnly = true,
    int limit = 50,
    int offset = 0,
  });

  /// Patches only the lifecycle/flag columns. Returns false when no row was
  /// matched, i.e. the post is gone or belongs to another site.
  Future<bool> patch(
    String id, {
    ArticleStatus? status,
    DateTime? scheduledFor,
    bool? clearScheduledFor,
    DateTime? publishedAt,
    bool? isTrending,
    bool? isFeatured,
    bool? isPopular,
  });

  /// Revision history for one post, newest first.
  Future<List<PostRevisionModel>> revisions(String postId);

  /// Snapshots the current body into `post_revisions` before an editorial
  /// overwrite. `revision_number` is client-computed as max+1 per the schema
  /// note in `005_functions_and_triggers.sql`. Returns false when the post is
  /// not editable by the caller.
  Future<bool> createRevision(PostRevisionModel revision);

  /// Convenience for the editor: next revision number for [postId] (1 when the
  /// post has no history yet).
  Future<int> nextRevisionNumber(String postId);
}
