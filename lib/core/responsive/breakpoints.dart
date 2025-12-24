import 'package:flutter/material.dart';

/// Responsive design breakpoints for Butlery app
/// Following Material Design 3 guidelines with 5 breakpoints:
/// - Mobile Small: 0-600px (phones)
/// - Tablet: 600-768px (small tablets, large phones landscape)
/// - Tablet Large: 768-1024px (tablets)
/// - Desktop: 1024-1280px (small desktops, large tablets landscape)
/// - Desktop Large: 1280px+ (standard desktops, 4K displays)
/// Usage:
/// ```dart
/// if (Breakpoints.isMobile(context)) {
///   // Mobile layout
/// } else if (Breakpoints.isTablet(context)) {
///   // Tablet layout
/// } else {
///   // Desktop layout
/// }
/// ```
class Breakpoints {
  // Prevent instantiation
  Breakpoints._();

  /// Mobile small breakpoint (320px)
  /// Phones in portrait mode
  static const double mobileSmall = 320;

  /// Mobile large / Tablet small breakpoint (600px)
  /// Large phones, small tablets portrait
  /// Material Design compact width threshold
  static const double mobileLarge = 600;

  /// Tablet breakpoint (768px)
  /// Tablets portrait, phones landscape
  static const double tablet = 768;

  /// Tablet large / Desktop small breakpoint (1024px)
  /// Tablets landscape, small desktops
  static const double tabletLarge = 1024;

  /// Desktop breakpoint (1280px)
  /// Standard desktop displays
  static const double desktop = 1280;

  /// Desktop large breakpoint (1920px)
  /// Large desktop displays, 4K
  static const double desktopLarge = 1920;

  /// Returns true if screen width is less than 600px (mobile phone)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileLarge;
  }

  /// Returns true if screen width is between 600-1024px (tablet)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileLarge && width < tabletLarge;
  }

  /// Returns true if screen width is 1024px or greater (desktop)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletLarge;
  }

  /// Returns true if screen width is less than 768px (small mobile/phone)
  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tablet;
  }

  /// Returns true if screen width is between 768-1280px (large tablet)
  static bool isLargeTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tablet && width < desktop;
  }

  /// Returns true if screen width is 1280px or greater (large desktop)
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }

  /// Returns true if width is less than 600px (mobile phone)
  static bool isMobileWidth(double width) {
    return width < mobileLarge;
  }

  /// Returns true if width is between 600-1024px (tablet)
  static bool isTabletWidth(double width) {
    return width >= mobileLarge && width < tabletLarge;
  }

  /// Returns true if width is 1024px or greater (desktop)
  static bool isDesktopWidth(double width) {
    return width >= tabletLarge;
  }

  /// Returns true if device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Returns true if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Returns device category as enum
  static DeviceCategory getDeviceCategory(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < mobileLarge) {
      return DeviceCategory.mobile;
    } else if (width < tablet) {
      return DeviceCategory.mobileLarge;
    } else if (width < tabletLarge) {
      return DeviceCategory.tablet;
    } else if (width < desktop) {
      return DeviceCategory.tabletLarge;
    } else if (width < desktopLarge) {
      return DeviceCategory.desktop;
    } else {
      return DeviceCategory.desktopLarge;
    }
  }

  /// Returns device category as enum (width-based)
  static DeviceCategory getDeviceCategoryFromWidth(double width) {
    if (width < mobileLarge) {
      return DeviceCategory.mobile;
    } else if (width < tablet) {
      return DeviceCategory.mobileLarge;
    } else if (width < tabletLarge) {
      return DeviceCategory.tablet;
    } else if (width < desktop) {
      return DeviceCategory.tabletLarge;
    } else if (width < desktopLarge) {
      return DeviceCategory.desktop;
    } else {
      return DeviceCategory.desktopLarge;
    }
  }

  /// Select value based on current breakpoint
  /// Example:
  /// ```dart
  /// final columns = Breakpoints.valueFor(
  ///   context: context,
  ///   mobile: 1,
  ///   tablet: 2,
  ///   desktop: 3,
  /// );
  /// ```
  static T valueFor<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (isTablet(context)) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }

  /// Select value based on device category with full control
  /// Example:
  /// ```dart
  /// final spacing = Breakpoints.valueForCategory(
  ///   context: context,
  ///   mobile: 8.0,
  ///   mobileLarge: 12.0,
  ///   tablet: 16.0,
  ///   tabletLarge: 20.0,
  ///   desktop: 24.0,
  ///   desktopLarge: 32.0,
  /// );
  /// ```
  static T valueForCategory<T>({
    required BuildContext context,
    required T mobile,
    T? mobileLarge,
    T? tablet,
    T? tabletLarge,
    T? desktop,
    T? desktopLarge,
  }) {
    final category = getDeviceCategory(context);

    switch (category) {
      case DeviceCategory.mobile:
        return mobile;
      case DeviceCategory.mobileLarge:
        return mobileLarge ?? mobile;
      case DeviceCategory.tablet:
        return tablet ?? mobileLarge ?? mobile;
      case DeviceCategory.tabletLarge:
        return tabletLarge ?? tablet ?? mobileLarge ?? mobile;
      case DeviceCategory.desktop:
        return desktop ?? tabletLarge ?? tablet ?? mobileLarge ?? mobile;
      case DeviceCategory.desktopLarge:
        return desktopLarge ??
            desktop ??
            tabletLarge ??
            tablet ??
            mobileLarge ??
            mobile;
    }
  }

  /// Get recommended grid column count based on screen width
  /// Returns:
  /// - Mobile: 1 column
  /// - Tablet: 2 columns
  /// - Desktop: 3 columns
  /// - Large Desktop: 4 columns
  static int getGridColumnCount(BuildContext context) {
    return valueForCategory(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
      desktopLarge: 4,
    );
  }

  /// Get recommended grid column count for cards
  /// More conservative than general grid (better readability)
  static int getCardColumnCount(BuildContext context) {
    return valueForCategory(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 2,
      desktopLarge: 3,
    );
  }

  /// Maximum content width for readable text
  /// Prevents text lines from becoming too long on wide screens
  static double getMaxContentWidth(BuildContext context) {
    return valueForCategory(
      context: context,
      mobile: double.infinity,
      tablet: 800,
      desktop: 1200,
      desktopLarge: 1400,
    );
  }

  /// Maximum form width for comfortable input
  static double getMaxFormWidth(BuildContext context) {
    return valueForCategory(
      context: context,
      mobile: double.infinity,
      tablet: 600,
      desktop: 600,
      desktopLarge: 600,
    );
  }

  /// Maximum dialog width
  static double getMaxDialogWidth(BuildContext context) {
    return valueForCategory(
      context: context,
      mobile: double.infinity,
      tablet: 500,
      desktop: 600,
      desktopLarge: 700,
    );
  }
}

/// Device category enum for responsive design
enum DeviceCategory {
  /// Mobile phone (< 600px)
  mobile,

  /// Large mobile / small tablet (600-768px)
  mobileLarge,

  /// Tablet (768-1024px)
  tablet,

  /// Large tablet (1024-1280px)
  tabletLarge,

  /// Desktop (1280-1920px)
  desktop,

  /// Large desktop / 4K (>= 1920px)
  desktopLarge,
}

/// Extension on DeviceCategory for convenience
extension DeviceCategoryExtension on DeviceCategory {
  /// Returns true if this is a mobile category
  bool get isMobile =>
      this == DeviceCategory.mobile || this == DeviceCategory.mobileLarge;

  /// Returns true if this is a tablet category
  bool get isTablet =>
      this == DeviceCategory.tablet || this == DeviceCategory.tabletLarge;

  /// Returns true if this is a desktop category
  bool get isDesktop =>
      this == DeviceCategory.desktop || this == DeviceCategory.desktopLarge;

  /// Returns human-readable name
  String get displayName {
    switch (this) {
      case DeviceCategory.mobile:
        return 'Mobile';
      case DeviceCategory.mobileLarge:
        return 'Large Mobile';
      case DeviceCategory.tablet:
        return 'Tablet';
      case DeviceCategory.tabletLarge:
        return 'Large Tablet';
      case DeviceCategory.desktop:
        return 'Desktop';
      case DeviceCategory.desktopLarge:
        return 'Large Desktop';
    }
  }
}
