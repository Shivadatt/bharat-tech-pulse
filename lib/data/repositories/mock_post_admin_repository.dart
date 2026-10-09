import '../models/admin_article_stats_model.dart';
import '../models/article_model.dart';
import '../models/post_revision_model.dart';
import '../services/mock_data_source.dart';
import 'post_admin_repository.dart';

/// In-memory [PostAdminRepository] so the admin CMS is fully functional
/// (counts, status transitions, revisions) without a provisioned backend.
class MockPostAdminRepository implements PostAdminRepository {
  final List<ArticleModel> _storage = List.from(MockDataSource.articles);
  final List<PostRevisionModel> _revisions = [];

  ArticleModel? _find(String id) {
    for (final a in _storage) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<AdminArticleStats> stats() async {
    await Future.delayed(const Duration(milliseconds: 50));
    int of(ArticleStatus s) =>
        _storage.where((a) => a.status == s).length;
    return AdminArticleStats(
      total: _storage.length,
      published: of(ArticleStatus.published),
      draft: of(ArticleStatus.draft),
      scheduled: of(ArticleStatus.scheduled),
      archived: of(ArticleStatus.archived),
      totalReads:
          _storage.fold<int>(0, (sum, a) => sum + a.viewCount),
    );
  }

  @override
  Future<List<ArticleModel>> listAll({int limit = 20, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 60));
    final sorted = List<ArticleModel>.from(_storage)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (offset >= sorted.length) return [];
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<List<ArticleModel>> listScheduled({
    bool upcomingOnly = true,
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final now = DateTime.now();
    final rows = _storage.where((a) {
      if (a.status != ArticleStatus.scheduled) return false;
      final at = a.scheduledFor;
      return !upcomingOnly || (at != null && at.isAfter(now));
    }).toList()
      ..sort((a, b) {
        final ta = a.scheduledFor ?? a.publishedAt;
        final tb = b.scheduledFor ?? b.publishedAt;
        return ta.compareTo(tb);
      });
    if (offset >= rows.length) return [];
    return rows.skip(offset).take(limit).toList();
  }

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
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _storage.indexWhere((a) => a.id == id);
    if (index == -1) return false;
    final current = _storage[index];
    _storage[index] = current.copyWith(
      status: status,
      scheduledFor: clearScheduledFor == true
          ? current.scheduledFor
          : scheduledFor,
      publishedAt: publishedAt,
      isTrending: isTrending,
      isFeatured: isFeatured,
      isPopular: isPopular,
      updatedAt: DateTime.now(),
    );
    return true;
  }

  @override
  Future<List<PostRevisionModel>> revisions(String postId) async {
    await Future.delayed(const Duration(milliseconds: 40));
    final rows = _revisions
        .where((r) => r.postId == postId)
        .toList()
      ..sort((a, b) => b.revisionNumber.compareTo(a.revisionNumber));
    return rows;
  }

  @override
  Future<int> nextRevisionNumber(String postId) async {
    await Future.delayed(const Duration(milliseconds: 20));
    final highest = _revisions
        .where((r) => r.postId == postId)
        .map((r) => r.revisionNumber)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return highest + 1;
  }

  @override
  Future<bool> createRevision(PostRevisionModel revision) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (_find(revision.postId) == null) return false;
    _revisions.add(PostRevisionModel(
      id: revision.id.isEmpty
          ? 'rev-${DateTime.now().microsecondsSinceEpoch}'
          : revision.id,
      postId: revision.postId,
      title: revision.title,
      excerpt: revision.excerpt,
      content: revision.content,
      revisionNumber: revision.revisionNumber,
      editedBy: revision.editedBy,
      createdAt: revision.createdAt,
    ));
    return true;
  }
}
