/// Comprehensive theme constants system providing specialized values for opacity, elevation, animation, and visual effects in the Butlery cooking application.
///
/// This constants system implements a sophisticated collection of specialized theme values that complement
/// the core color, typography, and dimension systems. It provides consistent opacity values, elevation
/// shadows, animation timing, and visual effects that enhance the cooking application's user interface
/// with Material 3 design principles and cooking-specific visual requirements for Swedish users.
///
/// **Architecture Integration:**
/// - Complements AppDimensions, AppColors, and AppTextStyles for complete theme system coverage
/// - Provides Material 3 compliant elevation shadows and animation timing values
/// - Supports consistent opacity and overlay effects throughout the application interface
/// - Integrates with component themes for cohesive visual effects and user interaction feedback
/// - Maintains accessibility compliance with appropriate contrast ratios and visual clarity
///
/// **Constants Categories:**
/// - **Opacity Constants**: Standardized transparency values for consistent overlay and visual effects
/// - **Blur and Spread Radius**: Shadow effect parameters for appropriate depth perception
/// - **Color Overlays**: Pre-configured overlay colors for modals, tooltips, and visual feedback
/// - **Animation Curves**: Motion design curves that reflect cooking workflow timing and user expectations
/// - **Duration Constants**: Standardized animation timing for consistent motion throughout the application
/// - **Elevation Shadows**: Material 3 compliant shadow configurations for appropriate depth hierarchy
///
/// **Design Philosophy:**
/// The theme constants reflect the precision and consistency of cooking with standardized values that
/// create visual harmony, appropriate timing for cooking workflow interactions, and professional
/// visual effects that enhance the Swedish cooking application experience without overwhelming users.
///
/// **Key Features:**
/// - Material 3 compliant elevation shadows with appropriate depth perception for cooking interfaces
/// - Standardized opacity values that maintain accessibility while providing visual hierarchy
/// - Animation timing that reflects natural cooking workflow pacing and user expectations
/// - Pre-configured overlay colors for consistent modal and feedback interactions
/// - Performance optimization through compile-time constants and efficient visual effect application
/// - Cultural adaptation with timing and visual effects appropriate for Swedish user preferences
///
/// **Usage Examples:**
/// ```dart
/// // Standardized opacity for overlay effects
/// Container(
///   color: AppColors.darkNavy.withValues(alpha: ThemeConstants.opacity40),
///   child: ModalContent(),
/// );
/// 
/// // Material 3 elevation shadows for recipe cards
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: ThemeConstants.elevationMedium,
///     borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
///   ),
///   child: RecipeCard(),
/// );
/// 
/// // Consistent animation timing for cooking workflows
/// AnimatedContainer(
///   duration: ThemeConstants.durationStandard,
///   curve: ThemeConstants.materialCurve,
///   child: RecipeInstructions(),
/// );
/// 
/// // Pre-configured overlay colors for modal interactions
/// Container(
///   color: ThemeConstants.blackOverlay40,
///   child: DialogOverlay(),
/// );
/// ```

import 'package:flutter/material.dart';

/// Comprehensive theme constants system implementing specialized values for opacity, elevation, animation, and visual effects in cooking-focused user interface design.
///
/// This class serves as the central repository for all specialized theme constants that complement the
/// core color, typography, and dimension systems throughout the Butlery application. It provides
/// standardized values for visual effects, animation timing, and interaction feedback that enhance
/// the cooking application experience with Material 3 compliance and Swedish cultural preferences.
///
/// **Constants Architecture:**
/// - **Systematic Organization**: Clear categorization of constants by usage context and visual purpose
/// - **Material 3 Integration**: Full compliance with Material 3 elevation, timing, and effect specifications
/// - **Consistency Framework**: Standardized values that ensure visual harmony across all application components
/// - **Performance Optimization**: Compile-time constants for efficient rendering and animation performance
/// - **Cultural Adaptation**: Values tuned for Swedish user preferences and cooking workflow expectations
///
/// **Design Principles:**
/// The theme constants reflect the precision and professionalism of cooking with standardized values
/// that create consistent user experiences, appropriate visual feedback, and smooth interactions
/// that support complex cooking workflows without creating visual noise or distraction.
class ThemeConstants {
  /// Private constructor to prevent instantiation of utility class
  ThemeConstants._();

  // ===== OPACITY CONSTANTS =====
  
  /// 10% opacity
  static const double opacity10 = 0.1;
  
  /// 20% opacity
  static const double opacity20 = 0.2;
  
  /// 30% opacity
  static const double opacity30 = 0.3;
  
  /// 40% opacity (0x66 in hex)
  static const double opacity40 = 0.4;
  
  /// 50% opacity
  static const double opacity50 = 0.5;
  
  /// 60% opacity
  static const double opacity60 = 0.6;
  
  /// 66% opacity (common for overlays)
  static const double opacity66 = 0.66;
  
  /// 70% opacity
  static const double opacity70 = 0.7;
  
  /// 80% opacity
  static const double opacity80 = 0.8;
  
  /// 90% opacity
  static const double opacity90 = 0.9;
  
  /// 100% opacity (fully opaque)
  static const double opacity100 = 1.0;

  // ===== BLUR RADIUS CONSTANTS =====
  
  /// Small blur radius
  static const double blurRadiusSmall = 4.0;
  
  /// Medium blur radius
  static const double blurRadiusMedium = 8.0;
  
  /// Large blur radius
  static const double blurRadiusLarge = 12.0;
  
  /// Extra large blur radius
  static const double blurRadiusXLarge = 16.0;

  // ===== SPREAD RADIUS CONSTANTS =====
  
  /// Zero spread radius
  static const double spreadRadiusZero = 0.0;
  
  /// Small spread radius
  static const double spreadRadiusSmall = 1.0;
  
  /// Medium spread radius
  static const double spreadRadiusMedium = 2.0;
  
  /// Large spread radius
  static const double spreadRadiusLarge = 4.0;

  // ===== COMMON COLOR OVERLAYS =====
  
  /// White overlay with 40% opacity
  static const Color whiteOverlay40 = Color(0x66FFFFFF);
  
  /// Black overlay with 10% opacity
  static const Color blackOverlay10 = Color(0x1A000000);
  
  /// Black overlay with 20% opacity
  static const Color blackOverlay20 = Color(0x33000000);
  
  /// Black overlay with 40% opacity
  static const Color blackOverlay40 = Color(0x66000000);
  
  /// Black overlay with 60% opacity
  static const Color blackOverlay60 = Color(0x99000000);

  // ===== ANIMATION CURVES =====
  
  /// Standard ease in out curve
  static const Curve standardCurve = Curves.easeInOut;
  
  /// Fast out slow in curve (Material Design)
  static const Curve materialCurve = Curves.fastOutSlowIn;
  
  /// Deceleration curve
  static const Curve decelerationCurve = Curves.decelerate;
  
  /// Acceleration curve
  static const Curve accelerationCurve = Curves.easeIn;

  // ===== COMMON DURATIONS =====
  
  /// Instant (no animation)
  static const Duration durationInstant = Duration.zero;
  
  /// Extra fast animation (100ms)
  static const Duration durationXFast = Duration(milliseconds: 100);
  
  /// Fast animation (150ms)
  static const Duration durationFast = Duration(milliseconds: 150);
  
  /// Standard animation (200ms)
  static const Duration durationStandard = Duration(milliseconds: 200);
  
  /// Medium animation (300ms)
  static const Duration durationMedium = Duration(milliseconds: 300);
  
  /// Slow animation (400ms)
  static const Duration durationSlow = Duration(milliseconds: 400);
  
  /// Extra slow animation (600ms)
  static const Duration durationXSlow = Duration(milliseconds: 600);
  
  /// Page transition duration (350ms)
  static const Duration durationPageTransition = Duration(milliseconds: 350);

  // ===== ELEVATION SHADOWS =====
  
  /// No elevation shadow
  static const List<BoxShadow> elevationNone = [];
  
  /// Low elevation shadow (2dp)
  static const List<BoxShadow> elevationLow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];
  
  /// Medium elevation shadow (4dp)
  static const List<BoxShadow> elevationMedium = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  /// High elevation shadow (8dp)
  static const List<BoxShadow> elevationHigh = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
  
  /// Extra high elevation shadow (12dp)
  static const List<BoxShadow> elevationXHigh = [
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 24,
      offset: Offset(0, 12),
      spreadRadius: 0,
    ),
  ];
}