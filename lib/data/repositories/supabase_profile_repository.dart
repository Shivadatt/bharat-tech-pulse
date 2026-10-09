import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/profile_model.dart';
import 'profile_repository.dart';

/// Reads the caller's `profiles` row plus their `profile_sites` membership for
/// the active site.
///
/// `profile_sites_select_own` lets any authenticated user read their own
/// membership rows, so the effective role is resolvable on the client — but it
/// is only ever a UI hint; RLS still enforces every write server-side.
class SupabaseProfileRepository implements ProfileRepository {
  final SiteContext _site;
  SupabaseProfileRepository({SiteContext? siteContext})
      : _site = siteContext ?? SiteContext();

  SupabaseClient get _client => SupabaseService.client;

  /// Maps a `profile_sites` row to its role string, or null when the
  /// membership is inactive (an archived membership grants nothing).
  static String? siteRoleFromRow(Map<String, dynamic> row) =>
      row['is_active'] == true ? row['role'] as String? : null;

  @override
  Future<ProfileModel?> loadCurrentProfile() => guardPostgrest(() async {
        final user = _client.auth.currentUser;
        if (user == null) return null;
        final row = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (row == null) return null;

        String? siteRole;
        try {
          final siteId = await _site.siteId;
          final membership = await _client
              .from('profile_sites')
              .select('role,is_active')
              .eq('profile_id', user.id)
              .eq('site_id', siteId)
              .maybeSingle();
          siteRole = membership == null ? null : siteRoleFromRow(membership);
        } on AppException {
          // A site/membership lookup failure must not masquerade as "signed
          // out": the profile still loads, just without site-level rights.
          siteRole = null;
        }

        return ProfileModel.fromJson(row, siteRole: siteRole);
      });
}
