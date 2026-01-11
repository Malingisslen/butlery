// lib/core/responsive/responsive_builder.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/responsive/breakpoints.dart';

/// Builder function type for responsive layouts
typedef ResponsiveWidgetBuilder = Widget Function(BuildContext context);

/// Responsive layout builder that switches between mobile, tablet, and desktop layouts
/// Usage:
/// ```dart
/// ResponsiveBuilder(
///   mobile: (context) => MobileLayout(),
///   tablet: (context) => TabletLayout(),
///   desktop: (context) => DesktopLayout(),
/// )
/// ```
/// Falls back gracefully:
/// - Desktop not provided → uses tablet → uses mobile
/// - Tablet not provided → uses mobile for tablet sizes
class ResponsiveBuilder extends StatelessWidget {
  /// Builder for mobile layout (< 600px)
  final ResponsiveWidgetBuilder mobile;

  /// Builder for tablet layout (600-1024px)
  /// Falls back to mobile if not provided
  final ResponsiveWidgetBuilder? tablet;

  /// Builder for desktop layout (>= 1024px)
  /// Falls back to tablet → mobile if not provided
  final ResponsiveWidgetBuilder? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Desktop layout
        if (Breakpoints.isDesktopWidth(width)) {
          if (desktop != null) return desktop!(context);
          if (tablet != null) return tablet!(context);
          return mobile(context);
        }

        // Tablet layout
        if (Breakpoints.isTabletWidth(width)) {
          if (tablet != null) return tablet!(context);
          return mobile(context);
        }

        // Mobile layout
        return mobile(context);
      },
    );
  }
}

/// Responsive layout builder with full breakpoint control
/// Provides builders for all 6 device categories with graceful fallbacks.
/// Usage:
/// ```dart
/// ResponsiveBuilderFull(
///   mobile: (context) => MobileLayout(),
///   tablet: (context) => TabletLayout(),
///   desktop: (context) => DesktopLayout(),
///   // Optional: mobileLarge, tabletLarge, desktopLarge
/// )
/// ```
class ResponsiveBuilderFull extends StatelessWidget {
  final ResponsiveWidgetBuilder mobile;
  final ResponsiveWidgetBuilder? mobileLarge;
  final ResponsiveWidgetBuilder? tablet;
  final ResponsiveWidgetBuilder? tabletLarge;
  final ResponsiveWidgetBuilder? desktop;
  final ResponsiveWidgetBuilder? desktopLarge;

  const ResponsiveBuilderFull({
    super.key,
    required this.mobile,
    this.mobileLarge,
    this.tablet,
    this.tabletLarge,
    this.desktop,
    this.desktopLarge,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final category = Breakpoints.getDeviceCategoryFromWidth(
          constraints.maxWidth,
        );

        switch (category) {
          case DeviceCategory.mobile:
            return mobile(context);

          case DeviceCategory.mobileLarge:
            return (mobileLarge ?? mobile)(context);

          case DeviceCategory.tablet:
            return (tablet ?? mobileLarge ?? mobile)(context);

          case DeviceCategory.tabletLarge:
            return (tabletLarge ?? tablet ?? mobileLarge ?? mobile)(context);

          case DeviceCategory.desktop:
            return (desktop ??
                tabletLarge ??
                tablet ??
                mobileLarge ??
                mobile)(context);

          case DeviceCategory.desktopLarge:
            return (desktopLarge ??
                desktop ??
                tabletLarge ??
                tablet ??
                mobileLarge ??
                mobile)(context);
        }
      },
    );
  }
}

/// Orientation-aware responsive builder
/// Switches layouts based on both screen size AND orientation.
/// Usage:
/// ```dart
/// OrientationResponsiveBuilder(
///   mobilePortrait: (context) => MobilePortraitLayout(),
///   mobileLandscape: (context) => MobileLandscapeLayout(),
///   tabletPortrait: (context) => TabletPortraitLayout(),
///   tabletLandscape: (context) => TabletLandscapeLayout(),
/// )
/// ```
class OrientationResponsiveBuilder extends StatelessWidget {
  final ResponsiveWidgetBuilder mobilePortrait;
  final ResponsiveWidgetBuilder? mobileLandscape;
  final ResponsiveWidgetBuilder? tabletPortrait;
  final ResponsiveWidgetBuilder? tabletLandscape;
  final ResponsiveWidgetBuilder? desktopLayout;

  const OrientationResponsiveBuilder({
    super.key,
    required this.mobilePortrait,
    this.mobileLandscape,
    this.tabletPortrait,
    this.tabletLandscape,
    this.desktopLayout,
  });

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;

        return ResponsiveBuilder(
          mobile: (context) {
            if (isPortrait) {
              return mobilePortrait(context);
            } else {
              return (mobileLandscape ?? mobilePortrait)(context);
            }
          },
          tablet: (context) {
            if (isPortrait) {
              return (tabletPortrait ?? mobilePortrait)(context);
            } else {
              return (tabletLandscape ?? mobileLandscape ?? mobilePortrait)(
                context,
              );
            }
          },
          desktop: desktopLayout,
        );
      },
    );
  }
}

/// Simple conditional widget based on device type
/// Usage:
/// ```dart
/// ResponsiveWidget(
///   onMobile: Text('Mobile'),
///   onTablet: Text('Tablet'),
///   onDesktop: Text('Desktop'),
/// )
/// ```
class ResponsiveWidget extends StatelessWidget {
  final Widget onMobile;
  final Widget? onTablet;
  final Widget? onDesktop;

  const ResponsiveWidget({
    super.key,
    required this.onMobile,
    this.onTablet,
    this.onDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobile: (_) => onMobile,
      tablet: onTablet != null ? (_) => onTablet! : null,
      desktop: onDesktop != null ? (_) => onDesktop! : null,
    );
  }
}

/// Visibility widget that shows/hides based on device type
/// Usage:
/// ```dart
/// ResponsiveVisibility(
///   visible: true,
///   visibleWhen: [DeviceCategory.tablet, DeviceCategory.desktop],
///   child: SidebarWidget(),
/// )
/// ```
class ResponsiveVisibility extends StatelessWidget {
  /// Child widget to show/hide
  final Widget child;

  /// Whether to show on current device (overrides visibleWhen)
  final bool? visible;

  /// List of device categories where this widget should be visible
  /// If null, widget is always visible (unless visible = false)
  final List<DeviceCategory>? visibleWhen;

  /// Replacement widget when not visible
  /// Defaults to SizedBox.shrink()
  final Widget? replacement;

  const ResponsiveVisibility({
    super.key,
    required this.child,
    this.visible,
    this.visibleWhen,
    this.replacement,
  });

  @override
  Widget build(BuildContext context) {
    // Explicit visibility override
    if (visible != null) {
      return visible! ? child : (replacement ?? const SizedBox.shrink());
    }

    // Check device category
    if (visibleWhen != null) {
      final category = Breakpoints.getDeviceCategory(context);
      final shouldShow = visibleWhen!.contains(category);
      return shouldShow ? child : (replacement ?? const SizedBox.shrink());
    }

    // Default: always visible
    return child;
  }
}

/// Constrain content width for better readability on large screens
/// Automatically centers and constrains content based on screen size.
/// Usage:
/// ```dart
/// ResponsiveConstrainedBox(
///   child: ArticleContent(),
/// )
/// ```
class ResponsiveConstrainedBox extends StatelessWidget {
  final Widget child;

  /// Custom max width (overrides breakpoint-based calculation)
  final double? maxWidth;

  /// Padding around constrained content
  final EdgeInsetsGeometry? padding;

  const ResponsiveConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final constrainedWidth =
        maxWidth ?? Breakpoints.getMaxContentWidth(context);

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: constrainedWidth),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Responsive spacing helper
/// Automatically adjusts spacing based on screen size:
/// - Mobile: base spacing
/// - Tablet: base * 1.25
/// - Desktop: base * 1.5
/// Usage:
/// ```dart
/// ResponsiveSpacing(
///   mobile: 16.0,
///   child: ListView(...),
/// )
/// ```
class ResponsiveSpacing extends StatelessWidget {
  final Widget child;

  /// Base spacing for mobile
  final double mobile;

  /// Tablet spacing (defaults to mobile * 1.25)
  final double? tablet;

  /// Desktop spacing (defaults to tablet * 1.2 or mobile * 1.5)
  final double? desktop;

  const ResponsiveSpacing({
    super.key,
    required this.child,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  double getSpacing(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.25,
      desktop: desktop ?? tablet ?? mobile * 1.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Responsive padding widget
/// Automatically scales padding based on screen size.
/// Usage:
/// ```dart
/// ResponsivePadding(
///   mobile: EdgeInsets.all(AppDimensions.spacingMd),
///   tablet: EdgeInsets.all(AppDimensions.spacingLg),
///   desktop: EdgeInsets.all(32),
///   child: Content(),
/// )
/// ```
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry mobile;
  final EdgeInsetsGeometry? tablet;
  final EdgeInsetsGeometry? desktop;

  const ResponsivePadding({
    super.key,
    required this.child,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final padding = Breakpoints.valueFor(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );

    return Padding(
      padding: padding,
      child: child,
    );
  }
}

/// Utility functions for responsive design
class ResponsiveUtils {
  ResponsiveUtils._();

  /// Get responsive font size multiplier
  /// Returns:
  /// - Mobile: 1.0
  /// - Tablet: 1.1
  /// - Desktop: 1.15
  static double getFontSizeMultiplier(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: 1.0,
      tablet: 1.1,
      desktop: 1.15,
    );
  }

  /// Get responsive spacing multiplier
  /// Returns:
  /// - Mobile: 1.0
  /// - Tablet: 1.25
  /// - Desktop: 1.5
  static double getSpacingMultiplier(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: 1.0,
      tablet: 1.25,
      desktop: 1.5,
    );
  }

  /// Get responsive icon size multiplier
  /// Returns:
  /// - Mobile: 1.0
  /// - Tablet: 1.15
  /// - Desktop: 1.25
  static double getIconSizeMultiplier(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: 1.0,
      tablet: 1.15,
      desktop: 1.25,
    );
  }

  /// Calculate responsive value with custom multipliers
  static double responsive({
    required BuildContext context,
    required double base,
    double? mobileMultiplier,
    double? tabletMultiplier,
    double? desktopMultiplier,
  }) {
    final multiplier = Breakpoints.valueFor(
      context: context,
      mobile: mobileMultiplier ?? 1.0,
      tablet: tabletMultiplier ?? 1.25,
      desktop: desktopMultiplier ?? 1.5,
    );

    return base * multiplier;
  }

  /// Get sidebar width for navigation
  /// Returns:
  /// - Mobile: 0 (no sidebar)
  /// - Tablet: 72 (NavigationRail compact)
  /// - Desktop: 256 (Drawer expanded)
  static double getSidebarWidth(BuildContext context) {
    return Breakpoints.valueFor(
      context: context,
      mobile: 0,
      tablet: 72,
      desktop: 256,
    );
  }

  /// Whether to use master-detail pattern
  /// Returns true on tablet and desktop
  static bool useMasterDetail(BuildContext context) {
    return !Breakpoints.isMobile(context);
  }

  /// Get appropriate cross-axis count for grid
  static int getGridCrossAxisCount(
    BuildContext context, {
    int mobile = 1,
    int? tablet,
    int? desktop,
  }) {
    return Breakpoints.valueFor(
      context: context,
      mobile: mobile,
      tablet: tablet ?? 2,
      desktop: desktop ?? 3,
    );
  }

  /// Get responsive dialog constraints
  static BoxConstraints getDialogConstraints(BuildContext context) {
    final maxWidth = Breakpoints.getMaxDialogWidth(context);

    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    );
  }

  /// Get responsive form constraints
  static BoxConstraints getFormConstraints(BuildContext context) {
    final maxWidth = Breakpoints.getMaxFormWidth(context);

    return BoxConstraints(maxWidth: maxWidth);
  }
}
