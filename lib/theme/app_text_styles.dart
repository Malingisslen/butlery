// lib/theme/app_text_styles.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography definitions for the Butlery app
/// Complete semantic text styles with Material 3 compliance
class AppTextStyles {
  AppTextStyles._(); // Private constructor to prevent instantiation

  // ===== BASE FONT CONFIGURATION =====

  static const String _primaryFontFamily = 'Inter';

  // ===== HEADING STYLES =====

  /// Display Large - For hero headlines (matching original AppTheme)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
    letterSpacing: -0.5,
  );

  /// Display Medium - For prominent headlines (matching original AppTheme)
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
    letterSpacing: -0.25,
  );

  /// Display Small - For section headlines (matching original AppTheme)
  static const TextStyle displaySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Headline Large - For "Din meny" style headers (matching original AppTheme)
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryBlue, // Blue like in Figma
    letterSpacing: -0.5,
  );

  /// Headline Medium - For "Middagar", "Lunch" section headers (matching original AppTheme)
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.sectionHeader, // Dark for section headers
    letterSpacing: -0.25,
  );

  /// Headline Small - For subsection titles (matching original AppTheme)
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  // ===== TITLE STYLES =====

  /// Title Large - For recipe names (matching original AppTheme)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.3,
  );

  /// Title Medium - For recipe names (matching original AppTheme)
  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.3,
  );

  /// Title Small - For small component titles (matching original AppTheme)
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
  );

  // ===== BODY STYLES =====

  /// Body Large - For main content text (matching original AppTheme)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
    height: 1.5,
  );

  /// Body Medium - For secondary content (matching original AppTheme)
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textMedium,
    height: 1.4,
  );

  /// Body Small - For metadata like "6 portioner | 30 minuter" (matching original AppTheme)
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.recipeMeta, // Special color for metadata
    height: 1.3,
  );

  // ===== LABEL STYLES =====

  /// Label Large - For prominent buttons (matching original AppTheme)
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Label Medium - For standard buttons (matching original AppTheme)
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
  );

  /// Label Small - For small buttons and tags (matching original AppTheme)
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
  );

  // ===== SEMANTIC STYLES =====

  /// Recipe title style
  static const TextStyle recipeTitle = titleLarge;

  /// Recipe subtitle/description style
  static const TextStyle recipeSubtitle = bodyMedium;

  /// Recipe metadata style (portions, time, etc.)
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

  /// Warning text style
  static TextStyle warningText = bodySmall.copyWith(
    color: AppColors.warning,
    fontWeight: FontWeight.w500,
  );

  // ===== SPECIALIZED STYLES =====

  /// App bar title style
  static const TextStyle appBarTitle = headlineMedium;

  /// Card title style
  static const TextStyle cardTitle = titleMedium;

  /// Card title style (alias)
  static const TextStyle cardTitleStyle = cardTitle;

  /// Card subtitle style
  static const TextStyle cardSubtitle = bodyMedium;

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

  /// Tooltip text style
  static const TextStyle tooltipText = bodySmall;

  /// Hint text style
  static TextStyle hintText = bodyMedium.copyWith(
    color: AppColors.textLight,
  );

  /// Placeholder text style
  static TextStyle placeholderText = bodyMedium.copyWith(
    color: AppColors.textLight,
    fontStyle: FontStyle.italic,
  );

  // ===== SHARED RECIPE STYLES =====

  /// Shared recipe title (dimmed)
  static TextStyle sharedRecipeTitle = recipeTitle.copyWith(
    color: AppColors.sharedRecipeText,
  );

  /// Shared recipe subtitle (dimmed)
  static TextStyle sharedRecipeSubtitle = recipeSubtitle.copyWith(
    color: AppColors.sharedRecipeText,
  );

  // ===== ADDITIONAL STYLES =====

  /// Micro text style (very small)
  static const TextStyle microText = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.2,
    color: AppColors.textMedium,
  );

  /// Small text style
  static const TextStyle smallText = bodySmall;

  /// Form label style
  static TextStyle formLabelStyle = labelMedium.copyWith(
    color: AppColors.textDark,
    fontWeight: FontWeight.w600,
  );

  /// Input hint style
  static TextStyle inputHintStyle = bodyMedium.copyWith(
    color: AppColors.textLight,
  );

  /// Chip label style
  static const TextStyle chipLabelStyle = labelSmall;

  /// Shared chip text style
  static TextStyle sharedChipTextStyle = chipLabelStyle.copyWith(
    color: AppColors.sharedRecipeText,
  );

  /// Error text style (alias)
  static TextStyle errorTextStyle = errorText;

  /// Success text style (alias)
  static TextStyle successTextStyle = successText;

  /// Warning text style (alias)
  static TextStyle warningTextStyle = warningText;

  /// Info text style
  static TextStyle infoTextStyle = bodyMedium;

  /// Section header style (alias)
  static TextStyle sectionHeaderStyle = sectionHeader;


  // ===== TEXT THEME FACTORY =====

  /// Create complete TextTheme for use with Material 3
  static TextTheme createTextTheme() {
    return const TextTheme(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      displaySmall: displaySmall,
      headlineLarge: headlineLarge,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }

  // ===== UTILITY METHODS =====

  /// Apply color to any text style
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Apply bold weight to any text style
  static TextStyle bold(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w700);
  }

  /// Apply italic to any text style
  static TextStyle italic(TextStyle style) {
    return style.copyWith(fontStyle: FontStyle.italic);
  }

  /// Apply underline to any text style
  static TextStyle underline(TextStyle style) {
    return style.copyWith(decoration: TextDecoration.underline);
  }

  /// Scale text style by factor
  static TextStyle scale(TextStyle style, double factor) {
    return style.copyWith(fontSize: (style.fontSize ?? 14) * factor);
  }
}