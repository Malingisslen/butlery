/// Comprehensive theme extensions system providing compatibility layer and enhanced property access for the Butlery cooking application.
///
/// This extension system implements a sophisticated compatibility and enhancement layer that bridges gaps
/// between existing theme properties and new component requirements throughout the cooking application.
/// It provides seamless property mapping, static access patterns, and enhanced theme integration that
/// maintains backward compatibility while supporting modern component architecture and Swedish design preferences.
///
/// **Architecture Integration:**
/// - Provides compatibility layer between existing theme classes and new component requirements
/// - Implements static access patterns for enhanced theme property retrieval and usage
/// - Maintains backward compatibility while supporting modern Material 3 component architecture
/// - Integrates seamlessly with existing color, dimension, and typography systems
/// - Supports enhanced theme property organization and developer experience improvements
///
/// **Extension Categories:**
/// - **AppColors Extensions**: Enhanced color property access with semantic mapping and static access
/// - **AppDimensions Extensions**: Improved dimension property retrieval with consistent naming patterns
/// - **Theme Properties Wrapper**: Unified static access layer for all theme properties and values
/// - **Compatibility Mapping**: Seamless integration between old and new component property requirements
/// - **Enhanced Access Patterns**: Improved developer experience with consistent property access methods
///
/// **Design Philosophy:**
/// The theme extensions reflect the evolution and refinement of the cooking application's design system
/// with seamless compatibility, enhanced developer experience, and consistent property access that
/// supports complex cooking workflows while maintaining design system integrity and performance.
///
/// **Key Features:**
/// - Seamless compatibility layer that bridges existing and new theme property requirements
/// - Static access patterns that enhance developer experience and code readability
/// - Consistent property mapping that maintains design system integrity and visual consistency
/// - Performance optimization through efficient property access and minimal runtime overhead
/// - Enhanced theme integration that supports modern component architecture patterns
/// - Cultural adaptation with property mappings appropriate for Swedish cooking application requirements
///
/// **Usage Examples:**
/// ```dart
/// // Enhanced static access to theme properties
/// Container(
///   color: ThemeProperties.primary,
///   padding: EdgeInsets.all(ThemeProperties.spacingM),
///   child: RecipeContent(),
/// );
/// 
/// // Extension-based property access
/// Text(
///   'Köttbullar med gräddsås',
///   style: ThemeProperties.titleLarge,
/// );
/// 
/// // Seamless integration with existing theme system
/// Card(
///   color: ThemeProperties.surfaceVariant,
///   child: RecipeCard(),
/// );
/// 
/// // Compatible access patterns for modern components
/// BorderRadius.circular(ThemeProperties.radiusM);
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
/// Enhanced AppColors extension providing additional color property access and semantic mapping for modern component architecture.
///
/// This extension enhances the AppColors class with additional static properties that provide seamless
/// access to color values using modern naming conventions while maintaining compatibility with existing
/// color definitions. It bridges the gap between traditional color naming and Material 3 semantic color roles.
extension AppColorsExtension on AppColors {
  // ===== ENHANCED COLOR PROPERTIES =====
  
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

/// Enhanced AppDimensions extension providing additional dimension property access and consistent naming patterns.
///
/// This extension enhances the AppDimensions class with additional static properties that provide consistent
/// access to dimension values using modern naming conventions while maintaining compatibility with existing
/// dimension definitions. It ensures consistent property access patterns across all theme components.
extension AppDimensionsExtension on AppDimensions {
  // ===== ENHANCED DIMENSION PROPERTIES =====
  
  /// Small radius (maps to borderRadiusS) 
  static double get radiusS => AppDimensions.borderRadiusS;
  
  /// Medium radius (maps to borderRadiusM)
  static double get radiusM => AppDimensions.borderRadiusM;
  
  /// Large radius (maps to borderRadiusL)
  static double get radiusL => AppDimensions.borderRadiusL;
  
  // Note: All spacing properties already exist in AppDimensions
  // spacingXs, spacingS, spacingM, spacingL, spacingXl are all defined
}

/// Comprehensive static access wrapper providing unified interface for all theme properties throughout the cooking application.
///
/// This wrapper class serves as the central access point for all theme properties, providing a unified
/// interface that combines colors, dimensions, and text styles into a single, consistent API. It enhances
/// developer experience by providing static access to all theme values while maintaining performance
/// and compatibility with existing theme architecture patterns.
///
/// **Property Categories:**
/// - **Color Properties**: Complete color palette access with semantic naming and Material 3 compliance
/// - **Dimension Properties**: Comprehensive dimension values with consistent naming and usage patterns
/// - **Text Style Properties**: Typography access with semantic organization and Swedish localization support
/// - **Compatibility Layer**: Seamless integration between old and new component property requirements
///
/// **Design Integration:**
/// The wrapper maintains design system integrity while providing enhanced access patterns that support
/// modern component architecture and cooking-focused user interface development requirements.
class ThemeProperties {
  /// Private constructor to prevent instantiation of utility class
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