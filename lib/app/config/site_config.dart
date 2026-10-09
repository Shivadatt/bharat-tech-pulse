/// Centralized configuration for the website.
/// Designed for reuse across multiple sites in the multi-website parent workspace.
class SiteConfig {
  static const String siteId = 'india_tech';
  static const String siteName = 'Bharat Tech Pulse';
  static const String domain = 'https://bharattechpulse.in';
  static const String tagline =
      'Simple technology guides, AI insights & smartphone reviews for everyday India';
  static const String description =
      'Bharat Tech Pulse delivers actionable AI tools tutorials, unbiased smartphone comparisons, practical how-to guides, and cyber safety awareness curated specifically for Indian tech enthusiasts and families.';

  // Regional Indian Context
  static const String region = 'India';
  static const String countryCode = 'IN';
  static const String currency = '₹';
  static const String contactEmail = 'contact@bharattechpulse.in';
  static const String editorialEmail = 'editorial@bharattechpulse.in';

  // Social Channels
  static const String twitterHandle = '@BharatTechPulse';
  static const String youtubeChannel = 'BharatTechPulse';
  static const String telegramChannel = 'bharattechpulse';
  static const String linkedinPage = 'company/bharat-tech-pulse';

  // Copyright
  static const String copyrightNotice =
      '© 2026 Bharat Tech Pulse. All rights reserved. Made for Digital India.';

  // SEO default share image. Served from the site's own origin as a bundled
  // static asset (web/og-default.jpg) rather than hotlinking a third-party
  // stock photo, so every page without an article hero still points at a real
  // site asset. Keeping it on the site origin also means lib/ stays free of
  // the Supabase project ref, which only ever enters the build via
  // --dart-define (see environment_config.dart).
  static const String defaultOgImage = '$domain/og-default.jpg';
}
