import '../../app/config/site_config.dart';
import '../models/site_settings_model.dart';
import 'site_settings_repository.dart';

/// In-memory stand-in so the app boots and tests run without a backend.
class MockSiteSettingsRepository implements SiteSettingsRepository {
  SiteSettingsModel? _settings;

  SiteSettingsModel get _seed => SiteSettingsModel(
        id: 'mock-site-settings',
        siteName: SiteConfig.siteName,
        tagline: SiteConfig.tagline,
        logoUrl: '',
        faviconUrl: '',
        defaultMetaTitle: '${SiteConfig.siteName} — Technology for Everyday India',
        defaultMetaDescription: SiteConfig.description,
        contactEmail: SiteConfig.contactEmail,
        socialLinks: {
          'twitter': SiteConfig.twitterHandle,
          'youtube': SiteConfig.youtubeChannel,
          'telegram': SiteConfig.telegramChannel,
          'linkedin': SiteConfig.linkedinPage,
        },
        footerText: SiteConfig.description,
        copyrightText: SiteConfig.copyrightNotice,
        googleAnalyticsId: '',
        updatedAt: DateTime.now(),
      );

  @override
  Future<SiteSettingsModel?> getSettings() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return _settings ?? _seed;
  }

  @override
  Future<SiteSettingsModel> saveSettings(SiteSettingsModel settings) async {
    await Future.delayed(const Duration(milliseconds: 40));
    _settings = SiteSettingsModel(
      id: settings.id.isEmpty ? 'mock-site-settings' : settings.id,
      siteName: settings.siteName,
      tagline: settings.tagline,
      logoUrl: settings.logoUrl,
      faviconUrl: settings.faviconUrl,
      defaultMetaTitle: settings.defaultMetaTitle,
      defaultMetaDescription: settings.defaultMetaDescription,
      contactEmail: settings.contactEmail,
      socialLinks: Map.of(settings.socialLinks),
      footerText: settings.footerText,
      copyrightText: settings.copyrightText,
      googleAnalyticsId: settings.googleAnalyticsId,
      updatedAt: DateTime.now(),
    );
    return _settings!;
  }
}
