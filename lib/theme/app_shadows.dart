/// Predefined shadow patterns for consistent elevation across the app.
///
/// Provides standardized BoxShadow definitions for different elevation levels.
/// All shadows use AppDimensions opacity constants for consistency.
///
/// Usage:
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: AppShadows.card,
///   ),
/// )
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Central repository for shadow definitions.
/// Ensures consistent elevation patterns across the entire app.
abstract class AppShadows {
  AppShadows._();

  /// Subtle shadow for minimal elevation (hover states, badges)
  /// Elevation: ~1dp
  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: Colors.black.withValues(alpha: AppDimensions.opacityVeryLight),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Standard card shadow (most common)
  /// Elevation: ~2dp
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: AppDimensions.opacityVeryLight),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Elevated shadow for dialogs and modals
  /// Elevation: ~4dp
  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: AppDimensions.opacityLight),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Floating shadow for FABs and floating elements
  /// Elevation: ~8dp
  static List<BoxShadow> get floating => [
        BoxShadow(
          color:
              Colors.black.withValues(alpha: AppDimensions.opacityMediumLight),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
