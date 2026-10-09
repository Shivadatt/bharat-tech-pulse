/// One immutable `post_revisions` snapshot taken before an editorial overwrite.
class PostRevisionModel {
  final String id;
  final String postId;
  final String title;
  final String excerpt;
  final String content;
  final int revisionNumber;
  final String? editedBy;
  final DateTime createdAt;

  const PostRevisionModel({
    required this.id,
    required this.postId,
    required this.revisionNumber,
    required this.createdAt,
    this.title = '',
    this.excerpt = '',
    this.content = '',
    this.editedBy,
  });

  factory PostRevisionModel.fromJson(Map<String, dynamic> json) =>
      PostRevisionModel(
        id: json['id'] as String? ?? '',
        postId: json['post_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
        content: json['content'] as String? ?? '',
        revisionNumber: (json['revision_number'] as num?)?.toInt() ?? 0,
        editedBy: json['edited_by'] as String?,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
