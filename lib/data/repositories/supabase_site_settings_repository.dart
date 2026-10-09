import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/site_settings_model.dart';
import 'site_settings_repository.dart';

/// Supabase implementation of [SiteSettingsRepository]: the single
/// `site_settings` row of the active site.
class SupabaseSiteSettingsRepository implements SiteSettingsRepository {
  final SiteContext _site;
  SupabaseSiteSettingsRepository({SiteContext? siteContext})
      : _site = siteContext ?? SiteContext();

  SupabaseClient get _client => SupabaseService.client;

  /// Model -> writable columns. `site_id` is deliberately absent: it is
  /// supplied by the caller's scope, never trusted from the edit form.
  static Map<String, dynamic> settingsToColumns(SiteSettingsModel s) => {
        'site_name': s.siteName,
        'tagline': s.tagline,
        'logo_url': s.logoUrl,
        'favicon_url': s.faviconUrl,
        'default_meta_title': s.defaultMetaTitle,
        'default_meta_description': s.defaultMetaDescription,
        'contact_email': s.contactEmail,
        'social_links': s.socialLinks,
        'footer_text': s.footerText,
        'copyright_text': s.copyrightText,
        'google_analytics_id': s.googleAnalyticsId,
      };

  static SiteSettingsModel rowToSettings(Map<String, dynamic> row) =>
      SiteSettingsModel.fromJson(row);

  @override
  Future<SiteSettingsModel?> getSettings() => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _client
            .from('site_settings')
            .select()
            .eq('site_id', siteId)
            .maybeSingle();
        return row == null ? null : rowToSettings(row);
      });

  @override
  Future<SiteSettingsModel> saveSettings(SiteSettingsModel settings) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final columns = settingsToColumns(settings);
        final existing = await _client
            .from('site_settings')
            .select('id')
            .eq('site_id', siteId)
            .maybeSingle();

        final Map<String, dynamic> row;
        if (existing == null) {
          row = await _client
              .from('site_settings')
              .insert({...columns, 'site_id': siteId})
              .select()
              .single();
        } else {
          // Strict update of the located row, scoped to this site.
          final updated = await _client
              .from('site_settings')
              .update(columns)
              .eq('id', existing['id'] as String)
              .eq('site_id', siteId)
              .select();
          if (updated.isEmpty) {
            throw const AuthException(
              'You do not have permission to change site settings.',
            );
          }
          row = updated.first;
        }
        return rowToSettings(row);
      });
}
