/// One `redirects` row: a permanent path mapping written when a slug changes.
class RedirectModel {
  final String id;
  final String oldPath;
  final String newPath;
  final int statusCode;
  final DateTime createdAt;

  const RedirectModel({
    required this.id,
    required this.oldPath,
    required this.newPath,
    this.statusCode = 301,
    required this.createdAt,
  });

  factory RedirectModel.fromJson(Map<String, dynamic> json) => RedirectModel(
        id: json['id'] as String? ?? '',
        oldPath: json['old_path'] as String? ?? '',
        newPath: json['new_path'] as String? ?? '',
        statusCode: (json['status_code'] as num?)?.toInt() ?? 301,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'old_path': oldPath,
        'new_path': newPath,
        'status_code': statusCode,
        'created_at': createdAt.toIso8601String(),
      };
}
