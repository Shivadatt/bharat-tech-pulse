import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/site_config.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/media_model.dart';
import 'media_repository.dart';

class SupabaseMediaRepository implements MediaRepository {
  static const _bucket = 'media';

  final SiteContext _site;
  SupabaseMediaRepository({SiteContext? siteContext})
      : _site = siteContext ?? SiteContext();

  SupabaseClient get _client => SupabaseService.client;

  @override
  Future<List<MediaModel>> listMedia({int limit = 50, int offset = 0}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('media')
            .select()
            .eq('site_id', siteId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        return rows.map((r) => MediaModel.fromJson(r)).toList();
      });

  @override
  Future<MediaModel> uploadMedia({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? altText,
  }) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final sanitized = _sanitizeFileName(fileName);
        final path = '${SiteConfig.siteId}/${_uuidV4()}-$sanitized';

        await _client.storage.from(_bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: false),
            );
        final publicUrl = _client.storage.from(_bucket).getPublicUrl(path);

        final row = await _client
            .from('media')
            .insert({
              'site_id': siteId,
              'uploaded_by': _client.auth.currentUser?.id,
              'file_name': fileName,
              'storage_path': path,
              'public_url': publicUrl,
              'mime_type': mimeType,
              'file_size': bytes.length,
              'alt_text': altText,
            })
            .select()
            .single();
        return MediaModel.fromJson(row);
      });

  @override
  Future<MediaModel?> updateMediaMetadata(String id, {String? altText}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _client
            .from('media')
            .update({'alt_text': altText})
            .eq('site_id', siteId)
            .eq('id', id)
            .select()
            .maybeSingle();
        return row == null ? null : MediaModel.fromJson(row);
      });

  @override
  Future<bool> deleteMedia(String id) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _client
            .from('media')
            .select('storage_path')
            .eq('site_id', siteId)
            .eq('id', id)
            .maybeSingle();
        if (row == null) return false;
        final path = row['storage_path'] as String?;
        // Remove the DB row first: if storage removal fails afterwards the
        // object is still addressable by path, whereas an RLS-blocked delete
        // would leave a row pointing at a missing file.
        await _client
            .from('media')
            .delete()
            .eq('site_id', siteId)
            .eq('id', id);
        if (path != null && path.isNotEmpty) {
          await _client.storage.from(_bucket).remove([path]);
        }
        return true;
      });

  /// Keeps the extension, replaces everything unsafe with dashes.
  String _sanitizeFileName(String name) {
    final cleaned = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9.\-_]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      throw const ValidationException('Invalid file name.');
    }
    return cleaned;
  }

  /// Dependency-free RFC 4122 version 4 id (the `uuid` package is not a
  /// direct dependency of this app).
  String _uuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }
}
