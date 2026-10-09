import 'dart:convert';

/// One row of the per-site `site_settings` table. Publicly readable, so this
/// model must never carry secrets.
class SiteSettingsModel {
  final String id;
  final String siteName;
  final String tagline;
  final String logoUrl;
  final String faviconUrl;
  final String defaultMetaTitle;
  final String defaultMetaDescription;
  final String contactEmail;
  final Map<String, String> socialLinks;
  final String footerText;
  final String copyrightText;
  final String googleAnalyticsId;
  final DateTime? updatedAt;

  const SiteSettingsModel({
    this.id = '',
    this.siteName = '',
    this.tagline = '',
    this.logoUrl = '',
    this.faviconUrl = '',
    this.defaultMetaTitle = '',
    this.defaultMetaDescription = '',
    this.contactEmail = '',
    this.socialLinks = const {},
    this.footerText = '',
    this.copyrightText = '',
    this.googleAnalyticsId = '',
    this.updatedAt,
  });

  static const List<String> socialKeys = [
    'twitter',
    'youtube',
    'telegram',
    'linkedin',
    'instagram',
  ];

  factory SiteSettingsModel.fromJson(Map<String, dynamic> json) =>
      SiteSettingsModel(
        id: json['id'] as String? ?? '',
        siteName: json['site_name'] as String? ?? '',
        tagline: json['tagline'] as String? ?? '',
        logoUrl: json['logo_url'] as String? ?? '',
        faviconUrl: json['favicon_url'] as String? ?? '',
        defaultMetaTitle: json['default_meta_title'] as String? ?? '',
        defaultMetaDescription:
            json['default_meta_description'] as String? ?? '',
        contactEmail: json['contact_email'] as String? ?? '',
        socialLinks: _linksFrom(json['social_links']),
        footerText: json['footer_text'] as String? ?? '',
        copyrightText: json['copyright_text'] as String? ?? '',
        googleAnalyticsId: json['google_analytics_id'] as String? ?? '',
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  /// `social_links` is a jsonb column: the driver may hand back a Map or,
  /// depending on the transport, an encoded String.
  static Map<String, String> _linksFrom(dynamic raw) {
    dynamic decoded = raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return const {};
      }
    }
    if (decoded is! Map) return const {};
    return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }
}
