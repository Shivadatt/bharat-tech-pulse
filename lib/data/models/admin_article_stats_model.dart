/// Backend counts of the posts visible to the caller, per lifecycle status.
class AdminArticleStats {
  final int total;
  final int published;
  final int draft;
  final int scheduled;
  final int archived;

  /// Sum of `posts.view_count` over the caller's visible posts. PostgREST has
  /// no aggregate, so this is computed from a capped column read — see
  /// [AdminArticleStats.truncatedReads].
  final int totalReads;

  /// True when more posts exist than the column read covered, i.e. when
  /// [totalReads] is a floor rather than the exact sum.
  final bool truncatedReads;

  const AdminArticleStats({
    required this.total,
    required this.published,
    required this.draft,
    required this.scheduled,
    required this.archived,
    required this.totalReads,
    this.truncatedReads = false,
  });
}
