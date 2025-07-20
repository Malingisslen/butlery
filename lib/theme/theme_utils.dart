// lib/theme/theme_utils.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_dimensions.dart';

/// Common theme utilities and helper methods
/// Provides frequently used decorations, widget builders, and styling helpers
class ThemeUtils {
  ThemeUtils._(); // Private constructor to prevent instantiation

  // ===== COMMON DECORATIONS =====

  /// Standard card decoration with theme-consistent styling
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.cardWhite,
    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
    boxShadow: AppDimensions.cardShadow,
  );

  /// Recipe card decoration (optimized for recipe cards)
  static BoxDecoration get recipeCardDecoration => BoxDecoration(
    color: AppColors.cardWhite,
    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
    boxShadow: AppDimensions.cardShadow,
  );

  /// Input container decoration
  static BoxDecoration get inputDecoration => BoxDecoration(
    color: AppColors.cardWhite,
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    border: Border.all(color: AppColors.divider),
  );

  /// Error container decoration
  static BoxDecoration get errorDecoration => BoxDecoration(
    color: AppColors.error.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    border: Border.all(color: AppColors.error),
  );

  /// Success container decoration
  static BoxDecoration get successDecoration => BoxDecoration(
    color: AppColors.success.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    border: Border.all(color: AppColors.success),
  );

  // ===== COMMON WIDGET BUILDERS =====

  /// Create a themed chip widget
  static Widget chip({
    required String label,
    Color? backgroundColor,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.lightColorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: textColor ?? AppColors.textDark,
        ),
      ),
    );
  }

  /// Create a meal type chip with semantic colors
  static Widget mealTypeChip(String mealType) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.getMealTypeColor(mealType),
        borderRadius: BorderRadius.circular(AppDimensions.chipRadius),
      ),
      child: Text(
        mealType,
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Create a section header widget
  static Widget sectionHeader(String title, {Widget? action}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.sectionHeader),
          if (action != null) action,
        ],
      ),
    );
  }

  /// Create a themed divider
  static Widget divider({double? height, Color? color}) {
    return Container(
      height: height ?? AppDimensions.dividerHeight,
      color: color ?? AppColors.divider,
    );
  }

  // ===== ICON HELPERS =====

  /// Create a themed action icon
  static Widget actionIcon(
    IconData icon, {
    Color? color,
    double? size,
    VoidCallback? onTap,
  }) {
    final iconWidget = Icon(
      icon,
      color: color ?? AppColors.textDark,
      size: size ?? AppDimensions.iconSizeAction,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: iconWidget);
    }
    return iconWidget;
  }

  /// Create status icons with semantic colors
  static Widget successIcon({double? size}) => Icon(
    Icons.check_circle,
    size: size ?? AppDimensions.iconSizeInfo,
    color: AppColors.success,
  );

  static Widget errorIcon({double? size}) => Icon(
    Icons.error_outline,
    size: size ?? AppDimensions.iconSizeInfo,
    color: AppColors.error,
  );

  static Widget warningIcon({double? size}) => Icon(
    Icons.warning_outlined,
    size: size ?? AppDimensions.iconSizeInfo,
    color: AppColors.warning,
  );

  // ===== LOADING INDICATORS =====

  /// Small loading indicator (16x16)
  static Widget smallLoader({Color? color}) => SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: color != null ? AlwaysStoppedAnimation<Color>(color) : null,
    ),
  );

  /// Standard loading indicator
  static Widget loader({Color? color}) => CircularProgressIndicator(
    valueColor: color != null ? AlwaysStoppedAnimation<Color>(color) : null,
  );

  // ===== COMMON CONTAINER PATTERNS =====

  /// Create an error message container
  static Widget errorContainer(String message, {IconData? icon}) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingMd),
      decoration: errorDecoration,
      child: Row(
        children: [
          Icon(
            icon ?? Icons.error_outline,
            color: AppColors.error,
            size: AppDimensions.iconSizeInfo,
          ),
          SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.errorText,
            ),
          ),
        ],
      ),
    );
  }

  /// Create a success message container
  static Widget successContainer(String message) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingMd),
      decoration: successDecoration,
      child: Row(
        children: [
          successIcon(),
          SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.successText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension methods for easier theme access in widgets
extension ThemeContextExtensions on BuildContext {
  /// Quick access to theme's color scheme
  ColorScheme get colors => Theme.of(this).colorScheme;
  
  /// Quick access to theme's text theme  
  TextTheme get textStyles => Theme.of(this).textTheme;
  
  /// Quick access to theme colors (static access)
  Color get primaryColor => AppColors.primaryBlue;
  Color get cardColor => AppColors.cardWhite;
  Color get textPrimary => AppColors.textDark;
  Color get textSecondary => AppColors.textMedium;
}