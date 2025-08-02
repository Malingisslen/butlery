/// Typography system for unified text styling in the Butlery application.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

/// Central repository for all text styles in the Butlery application.
class AppTextStyles {
  /// Private constructor
  AppTextStyles._();

  /// Primary font family
  static const String _primaryFontFamily = 'Inter';

  /// Display Small - For prominent section headlines
  static const TextStyle displaySmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );


  /// Headline Medium - For section headers and content categories
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24, // Increased from 20
    fontWeight: FontWeight.w700,
    color: AppColors.sectionHeader, // Dark for section headers
    letterSpacing: -0.25,
  );

  /// Headline Small - For subsection titles and secondary headers
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 22, // Increased from 18
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Title Large - For recipe names and primary content
  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.3,
  );

  /// Title Medium - For secondary titles and content headers
  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.3,
  );

  /// Title Small - Alias for headlineSmall
  static const TextStyle titleSmall = headlineSmall;


  /// Body Large - For main content text and instructions
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
    height: 1.5,
  );

  /// Body Medium - For secondary content and descriptions
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textMedium,
    height: 1.4,
  );

  /// Body Small - For metadata and supplementary information
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.recipeMeta, // Special color for metadata
    height: 1.3,
  );

  /// Label Large - For prominent buttons
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Label Medium - For standard buttons
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
  );

  /// Label Small - For small buttons and tags
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
  );

  /// Recipe metadata style
  static TextStyle recipeMeta = bodySmall.copyWith(
    color: AppColors.recipeMeta,
    fontWeight: FontWeight.w500,
  );

  /// Section header style
  static TextStyle sectionHeader = headlineSmall.copyWith(
    color: AppColors.sectionHeader,
    fontWeight: FontWeight.w700,
  );

  /// Section title style (alias for section header)
  static TextStyle sectionTitleStyle = sectionHeader;

  /// Button text style
  static const TextStyle buttonText = labelLarge;
  
  /// Label text style for form fields
  static const TextStyle labelText = labelMedium;
  
  /// Caption text style for helper text
  static const TextStyle captionText = labelSmall;

  /// Primary button text style
  static const TextStyle buttonPrimary = labelLarge;

  /// Button text style (alias)
  static const TextStyle buttonTextStyle = buttonText;

  /// Tab text style
  static const TextStyle tabText = labelMedium;

  /// Navigation text style
  static const TextStyle navigationText = labelSmall;

  /// Error text style
  static TextStyle errorText = bodySmall.copyWith(
    color: AppColors.error,
    fontWeight: FontWeight.w500,
  );

  /// Success text style
  static TextStyle successText = bodySmall.copyWith(
    color: AppColors.success,
    fontWeight: FontWeight.w500,
  );


  // ===== SPECIALIZED STYLES =====

  /// App bar title style
  static const TextStyle appBarTitle = headlineMedium;

  /// Card title style
  static const TextStyle cardTitle = titleMedium;

  /// Card title style (alias)
  static const TextStyle cardTitleStyle = cardTitle;


  /// List tile title style
  static const TextStyle listTileTitle = titleMedium;

  /// List tile subtitle style
  static const TextStyle listTileSubtitle = bodyMedium;

  /// Dialog title style
  static const TextStyle dialogTitle = titleLarge;

  /// Dialog content style
  static const TextStyle dialogContent = bodyLarge;

  /// Snackbar text style
  static const TextStyle snackbarText = bodyMedium;


  /// Hint text style
  static TextStyle hintText = bodyMedium.copyWith(
    color: AppColors.textLight,
  );



  /// Creates a complete Material 3 TextTheme
  static TextTheme createTextTheme() {
    return const TextTheme(
      displaySmall: displaySmall,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }

}