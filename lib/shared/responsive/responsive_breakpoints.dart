import 'package:flutter/material.dart';

enum DeviceScreenType {
  desktopLarge, // >= 1440
  desktop,      // 1024 - 1439
  tablet,       // 768 - 1023
  mobileLarge,  // 480 - 767
  mobile,       // < 480
}

class ResponsiveBreakpoints {
  static const double desktopLarge = 1440.0;
  static const double desktop = 1024.0;
  static const double tabletLandscape = 900.0;
  static const double tablet = 768.0;
  static const double mobileLarge = 650.0;
  static const double mobile = 480.0;
  static const double mobileSmall = 425.0;
  static const double mobileTiny = 375.0;

  static DeviceScreenType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopLarge) return DeviceScreenType.desktopLarge;
    if (width >= desktop) return DeviceScreenType.desktop;
    if (width >= tablet) return DeviceScreenType.tablet;
    if (width >= mobile) return DeviceScreenType.mobileLarge;
    return DeviceScreenType.mobile;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= tablet && w < desktop;
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tablet;

  static bool isMobileSmall(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;
}
