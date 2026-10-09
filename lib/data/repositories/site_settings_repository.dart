import '../models/site_settings_model.dart';

/// Contract for the per-site `site_settings` row. Reads are public, writes
/// require the site-admin tier (enforced by RLS).
abstract class SiteSettingsRepository {
  Future<SiteSettingsModel?> getSettings();

  /// Writes the single settings row for the active site (insert on first
  /// save, update afterwards). Throws [AppException] on failure.
  Future<SiteSettingsModel> saveSettings(SiteSettingsModel settings);
}
