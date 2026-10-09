import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/redirect_model.dart';
import 'redirect_repository.dart';

/// Supabase implementation of [RedirectRepository].
class SupabaseRedirectRepository implements RedirectRepository {
  static final RegExp _pathPattern = RegExp(r'^/[^\s]*$');

  final SiteContext _site;
  SupabaseRedirectRepository({SiteContext? siteContext})
      : _site = siteContext ?? SiteContext();

  SupabaseClient get _client => SupabaseService.client;

  static Map<String, dynamic> redirectInsertColumns(
    String oldPath,
    String newPath,
    int statusCode, {
    required String siteId,
  }) =>
      {
        'site_id': siteId,
        'old_path': oldPath,
        'new_path': newPath,
        'status_code': statusCode,
      };

  static RedirectModel rowToRedirect(Map<String, dynamic> row) =>
      RedirectModel.fromJson(row);

  @override
  Future<List<RedirectModel>> getRedirects({
    int limit = 50,
    int offset = 0,
  }) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('redirects')
            .select()
            .eq('site_id', siteId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        return rows.map((r) => rowToRedirect(r)).toList();
      });

  @override
  Future<RedirectModel?> createRedirect(
    String oldPath,
    String newPath, {
    int statusCode = 301,
  }) =>
      guardPostgrest(() async {
        final from = oldPath.trim();
        final to = newPath.trim();
        if (!_pathPattern.hasMatch(from) || !_pathPattern.hasMatch(to)) {
          throw const ValidationException(
            'Redirect paths must start with "/" and contain no spaces.',
          );
        }
        if (from == to) {
          throw const ValidationException(
            'A redirect cannot point at itself.',
          );
        }
        if (statusCode != 301 && statusCode != 302 && statusCode != 307) {
          throw const ValidationException(
            'Status code must be 301, 302 or 307.',
          );
        }
        final siteId = await _site.siteId;
        try {
          final row = await _client
              .from('redirects')
              .insert(redirectInsertColumns(from, to, statusCode,
                  siteId: siteId))
              .select()
              .single();
          return rowToRedirect(row);
        } on PostgrestException catch (e) {
          if (e.code == '23505') return null;
          throw mapPostgrestException(e);
        }
      });

  @override
  Future<bool> deleteRedirect(String id) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('redirects')
            .delete()
            .eq('site_id', siteId)
            .eq('id', id)
            .select('id');
        return rows.isNotEmpty;
      });
}
