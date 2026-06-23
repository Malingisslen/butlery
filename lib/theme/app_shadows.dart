/// Predefined 2-layer shadow patterns for consistent elevation across the app.
///
/// Each level uses an ambient + key shadow pair, matching Material Design 3's
/// dual-layer elevation model:
/// - **Ambient**: softer, larger blur, lower opacity — surrounding glow
/// - **Key**: sharper, smaller blur, higher opacity — directional depth
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

/// Central repository for shadow definitions.
/// Ensures consistent elevation patterns across the entire app.
abstract class AppShadows {
  AppShadows._();

  /// Subtle shadow for minimal elevation (hover states, badges)
  /// Equivalent to Material elevation ~1dp
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// Standard card shadow (most common)
  /// Equivalent to Material elevation ~2dp
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 3,
      offset: const Offset(0, 2),
    ),
  ];

  /// Elevated shadow for dialogs and modals
  /// Equivalent to Material elevation ~4dp
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];

  /// Floating shadow for FABs and floating elements
  /// Equivalent to Material elevation ~8dp
  static List<BoxShadow> get floating => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 10,
      offset: const Offset(0, 8),
    ),
  ];

  /// Lifted card shadow — cards that "float" above the page
  /// Stronger than standard card, used for recipe cards in lists
  static List<BoxShadow> get cardLifted => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Search box shadow — subtle lift for the search input
  static List<BoxShadow> get searchBox => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Active chip glow — green-tinted shadow for selected filter chips
  static List<BoxShadow> activeChip(Color primaryColor) => [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.4),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];
}
