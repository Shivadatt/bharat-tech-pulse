import 'dart:typed_data';

import '../models/media_model.dart';
import 'media_repository.dart';

/// In-memory [MediaRepository] so the media library works (upload, list, alt
/// text, delete) without a provisioned Storage bucket.
class MockMediaRepository implements MediaRepository {
  static const int maxUploadBytes = 5 * 1024 * 1024;

  final List<MediaModel> _storage = [
    MediaModel(
      id: 'media-1',
      fileName: 'ai-summit-hero.jpg',
      storagePath: 'india_tech/ai-summit-hero.jpg',
      publicUrl: 'https://images.unsplash.com/photo-1677442136015-f60dec4415f1',
      mimeType: 'image/jpeg',
      fileSize: 284160,
      width: 1600,
      height: 900,
      altText: 'AI Summit stage in Bengaluru',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1717200000000),
    ),
    MediaModel(
      id: 'media-2',
      fileName: 'semiconductor-fab.png',
      storagePath: 'india_tech/semiconductor-fab.png',
      publicUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475',
      mimeType: 'image/png',
      fileSize: 512040,
      width: 1200,
      height: 800,
      altText: 'Semiconductor wafer close-up',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1717804800000),
    ),
  ];

  static String mimeTypeForFileName(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'avif':
        return 'image/avif';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Future<List<MediaModel>> listMedia({int limit = 50, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final sorted = List<MediaModel>.from(_storage)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= sorted.length) return [];
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<MediaModel> uploadMedia({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? altText,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (fileName.trim().isEmpty) {
      throw ArgumentError('A file name is required.');
    }
    if (bytes.lengthInBytes > maxUploadBytes) {
      throw StateError('File is larger than the 5MB upload limit.');
    }
    final now = DateTime.now();
    final model = MediaModel(
      id: 'media-${now.microsecondsSinceEpoch}',
      fileName: fileName,
      storagePath: 'india_tech/${now.millisecondsSinceEpoch}-$fileName',
      publicUrl: 'blob://local/$fileName',
      mimeType: mimeType.isEmpty ? mimeTypeForFileName(fileName) : mimeType,
      fileSize: bytes.lengthInBytes,
      altText: altText,
      createdAt: now,
    );
    _storage.add(model);
    return model;
  }

  @override
  Future<MediaModel?> updateMediaMetadata(String id, {String? altText}) async {
    await Future.delayed(const Duration(milliseconds: 40));
    final index = _storage.indexWhere((m) => m.id == id);
    if (index == -1) return null;
    final current = _storage[index];
    final updated = MediaModel(
      id: current.id,
      fileName: current.fileName,
      storagePath: current.storagePath,
      publicUrl: current.publicUrl,
      mimeType: current.mimeType,
      fileSize: current.fileSize,
      width: current.width,
      height: current.height,
      altText: altText ?? current.altText,
      createdAt: current.createdAt,
    );
    _storage[index] = updated;
    return updated;
  }

  @override
  Future<bool> deleteMedia(String id) async {
    await Future.delayed(const Duration(milliseconds: 60));
    final index = _storage.indexWhere((m) => m.id == id);
    if (index == -1) return false;
    _storage.removeAt(index);
    return true;
  }
}
