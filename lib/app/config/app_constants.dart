/// App-wide constants for layouts, spacing, paddings, and defaults.
class AppConstants {
  // Breakpoints
  static const double breakpointDesktopLarge = 1440.0;
  static const double breakpointDesktop = 1280.0;
  static const double breakpointLaptop = 1024.0;
  static const double breakpointTabletLandscape = 900.0;
  static const double breakpointTablet = 768.0;
  static const double breakpointMobileLarge = 650.0;
  static const double breakpointMobile = 480.0;
  static const double breakpointMobileSmall = 425.0;
  static const double breakpointMobileTiny = 375.0;

  // Max widths
  static const double maxContentWidth = 1280.0;
  static const double maxAdminContentWidth = 1440.0;
  static const double maxArticleWidth = 840.0;
  static const double sidebarWidth = 340.0;
  static const double adminSidebarWidth = 260.0;

  // Spacing & Paddings
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  static const double spacingSection = 56.0;

  // Border Radii
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 16.0;
  static const double radiusFull = 999.0;

  // Animation durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // Pagination
  static const int articlesPerPage = 12;
}
