/// Media library item backed by the `media` table + Storage object.
class MediaModel {
  final String id;
  final String fileName;
  final String storagePath;
  final String publicUrl;
  final String mimeType;
  final int fileSize;
  final int? width;
  final int? height;
  final String? altText;
  final DateTime createdAt;

  const MediaModel({
    required this.id,
    required this.fileName,
    required this.storagePath,
    required this.publicUrl,
    required this.mimeType,
    required this.fileSize,
    this.width,
    this.height,
    this.altText,
    required this.createdAt,
  });

  factory MediaModel.fromJson(Map<String, dynamic> json) => MediaModel(
        id: json['id'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        storagePath: json['storage_path'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
        mimeType: json['mime_type'] as String? ?? '',
        fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        altText: json['alt_text'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'file_name': fileName,
        'storage_path': storagePath,
        'public_url': publicUrl,
        'mime_type': mimeType,
        'file_size': fileSize,
        'width': width,
        'height': height,
        'alt_text': altText,
        'created_at': createdAt.toIso8601String(),
      };
}
