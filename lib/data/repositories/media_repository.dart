import 'dart:typed_data';

import '../models/media_model.dart';

/// Abstract contract for the media library (Storage-backed).
abstract class MediaRepository {
  Future<List<MediaModel>> listMedia({int limit = 50, int offset = 0});

  /// Uploads [bytes] to the site-scoped storage bucket and inserts the
  /// tracking `media` row. Returns the created model.
  Future<MediaModel> uploadMedia({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? altText,
  });

  Future<MediaModel?> updateMediaMetadata(String id, {String? altText});

  /// Removes the storage object first, then the `media` row.
  Future<bool> deleteMedia(String id);
}
