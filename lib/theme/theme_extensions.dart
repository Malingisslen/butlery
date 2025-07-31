// lib/theme/theme_extensions.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Theme Extensions for Missing Properties
/// 
/// This file provides extensions to map the new component property names
/// to existing theme properties, ensuring compatibility without modifying
/// the core theme classes.
extension AppColorsExtension on AppColors {
  // ===== MISSING COLOR PROPERTIES =====
  
  /// Primary color (maps to primaryBlue)
  static Color get primary => AppColors.primaryBlue;
  
  /// Secondary color (maps to accent)
  static Color get secondary => AppColors.accent;
  
  /// Surface color (maps to backgroundBeige)
  static Color get surface => AppColors.backgroundBeige;
  
  /// Surface variant (maps to cardWhite)
  static Color get surfaceVariant => AppColors.cardWhite;
  
  /// On surface color (maps to textDark)
  static Color get onSurface => AppColors.textDark;
  
  /// Primary container (existing in ColorScheme but need static access)
  static Color get primaryContainer => const Color(0xFFE3F2FD);
  
  /// On primary container (maps to darkNavy)
  static Color get onPrimaryContainer => AppColors.darkNavy;
  
  /// On primary color (maps to cardWhite)
  static Color get onPrimary => AppColors.cardWhite;
  
  /// Outline color (maps to divider)
  static Color get outline => AppColors.divider;
  
  /// Shadow color (maps to shadowColor)
  static Color get shadow => AppColors.shadowColor;
  
  /// On success color (maps to cardWhite for contrast)
  static Color get onSuccess => AppColors.cardWhite;
  
  /// On error color (maps to cardWhite for contrast)
  static Color get onError => AppColors.cardWhite;
  
  /// On warning color (maps to darkNavy for contrast)
  static Color get onWarning => AppColors.darkNavy;
  
  /// On info color (maps to cardWhite for contrast)
  static Color get onInfo => AppColors.cardWhite;
}

extension AppDimensionsExtension on AppDimensions {
  // ===== MISSING DIMENSION PROPERTIES =====
  
  /// Small radius (maps to borderRadiusS) 
  static double get radiusS => AppDimensions.borderRadiusS;
  
  /// Medium radius (maps to borderRadiusM)
  static double get radiusM => AppDimensions.borderRadiusM;
  
  /// Large radius (maps to borderRadiusL)
  static double get radiusL => AppDimensions.borderRadiusL;
  
  // Note: All spacing properties already exist in AppDimensions
  // spacingXs, spacingS, spacingM, spacingL, spacingXl are all defined
}

/// Static access wrapper for theme properties
/// 
/// This class provides static access to theme properties that the new
/// components expect, mapping them to existing theme definitions.
class ThemeProperties {
  ThemeProperties._();
  
  // ===== COLORS =====
  
  static Color get primary => AppColorsExtension.primary;
  static Color get secondary => AppColorsExtension.secondary;
  static Color get surface => AppColorsExtension.surface;
  static Color get surfaceVariant => AppColorsExtension.surfaceVariant;
  static Color get onSurface => AppColorsExtension.onSurface;
  static Color get primaryContainer => AppColorsExtension.primaryContainer;
  static Color get onPrimaryContainer => AppColorsExtension.onPrimaryContainer;
  static Color get onPrimary => AppColorsExtension.onPrimary;
  static Color get outline => AppColorsExtension.outline;
  static Color get shadow => AppColorsExtension.shadow;
  static Color get success => AppColors.success;
  static Color get onSuccess => AppColorsExtension.onSuccess;
  static Color get error => AppColors.error;
  static Color get onError => AppColorsExtension.onError;
  static Color get warning => AppColors.warning;
  static Color get onWarning => AppColorsExtension.onWarning;
  static Color get info => AppColors.info;
  static Color get onInfo => AppColorsExtension.onInfo;
  
  // ===== DIMENSIONS =====
  
  static double get radiusS => AppDimensionsExtension.radiusS;
  static double get radiusM => AppDimensionsExtension.radiusM;
  static double get radiusL => AppDimensionsExtension.radiusL;
  static double get spacingXs => AppDimensions.spacingXs;
  static double get spacingS => AppDimensions.spacingS;
  static double get spacingM => AppDimensions.spacingM;
  static double get spacingL => AppDimensions.spacingL;
  static double get spacingXl => AppDimensions.spacingXl;
  
  // ===== TEXT STYLES =====
  
  static TextStyle get titleLarge => AppTextStyles.titleLarge;
  static TextStyle get titleMedium => AppTextStyles.titleMedium;
  static TextStyle get titleSmall => AppTextStyles.headlineSmall; // Map to existing
  static TextStyle get bodyLarge => AppTextStyles.bodyLarge;
  static TextStyle get bodyMedium => AppTextStyles.bodyMedium;
  static TextStyle get bodySmall => AppTextStyles.bodySmall;
}