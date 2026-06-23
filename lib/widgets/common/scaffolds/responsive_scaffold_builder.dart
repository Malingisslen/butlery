import 'package:flutter/material.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/core/responsive/responsive_builder.dart';

/// Enhanced responsive scaffold helper using comprehensive breakpoint system.
/// Provides three builder variants:
/// 1. Simple mobile/desktop boolean check (backward compatible)
/// 2. Full mobile/tablet/desktop builder functions
/// 3. Device category enum for fine-grained control
class ResponsiveScaffoldBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isMobile)? builder;
  final ResponsiveWidgetBuilder? mobile;
  final ResponsiveWidgetBuilder? tablet;
  final ResponsiveWidgetBuilder? desktop;
  final Widget Function(BuildContext context, DeviceCategory category)?
  categoryBuilder;

  /// Simple mobile/desktop boolean check (backward compatible).
  /// Uses 600px breakpoint: < 600px = mobile, >= 600px = desktop
  const ResponsiveScaffoldBuilder({
    super.key,
    required this.builder,
  }) : mobile = null,
       tablet = null,
       desktop = null,
       categoryBuilder = null;

  /// Full mobile/tablet/desktop builder functions.
  /// Breakpoints:
  /// - Mobile: < 600px
  /// - Tablet: 600-1024px
  /// - Desktop: >= 1024px
  /// Graceful fallbacks: desktop → tablet → mobile
  const ResponsiveScaffoldBuilder.full({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : builder = null,
       categoryBuilder = null;

  /// Device category for fine-grained control.
  /// Provides all 6 device categories:
  /// - mobile, mobileLarge, tablet, tabletLarge, desktop, desktopLarge
  const ResponsiveScaffoldBuilder.category({
    super.key,
    required this.categoryBuilder,
  }) : builder = null,
       mobile = null,
       tablet = null,
       desktop = null;

  @override
  Widget build(BuildContext context) {
    // Category builder (most flexible)
    if (categoryBuilder != null) {
      final category = Breakpoints.getDeviceCategory(context);
      return categoryBuilder!(context, category);
    }

    // Full builder (mobile/tablet/desktop)
    if (mobile != null) {
      return ResponsiveBuilder(
        mobile: mobile!,
        tablet: tablet,
        desktop: desktop,
      );
    }

    // Simple builder (backward compatible)
    if (builder != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = Breakpoints.isMobileWidth(constraints.maxWidth);
          return builder!(context, isMobile);
        },
      );
    }

    throw StateError(
      'ResponsiveScaffoldBuilder requires one of: builder, mobile, or categoryBuilder',
    );
  }
}
