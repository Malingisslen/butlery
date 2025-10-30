/// Feedback and interactive component themes.

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Feedback component themes (snackbar, divider, switches, checkboxes, etc.).
class FeedbackThemes {
  /// Private constructor
  FeedbackThemes._();

  /// Snackbar theme
  static SnackBarThemeData get snackBarTheme {
    return SnackBarThemeData(
      backgroundColor: AppColors.darkNavy,
      contentTextStyle: AppTextStyles.snackbarText.copyWith(
        color: AppColors.cardWhite,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: AppDimensions.elevationHigh,
    );
  }

  /// Divider theme
  static DividerThemeData get dividerTheme {
    return const DividerThemeData(
      color: AppColors.divider,
      thickness: AppDimensions.borderWidthThin,
      space: AppDimensions.spacingL,
    );
  }

  /// Switch theme
  static SwitchThemeData get switchTheme {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return AppColors.textLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue.withValues(alpha: 0.5);
        }
        return AppColors.divider;
      }),
    );
  }

  /// Checkbox theme
  static CheckboxThemeData get checkboxTheme {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return AppColors.cardWhite;
      }),
      checkColor: WidgetStateProperty.all(AppColors.cardWhite),
      side: const BorderSide(
        color: AppColors.textLight,
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius4),
      ),
    );
  }

  /// Radio theme
  static RadioThemeData get radioTheme {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return AppColors.textMedium;
      }),
    );
  }

  /// Slider theme
  static SliderThemeData get sliderTheme {
    return SliderThemeData(
      activeTrackColor: AppColors.primaryBlue,
      inactiveTrackColor: AppColors.divider,
      thumbColor: AppColors.primaryBlue,
      overlayColor: AppColors.primaryBlue.withValues(alpha: 0.2),
      valueIndicatorColor: AppColors.primaryBlue,
      valueIndicatorTextStyle: AppTextStyles.labelSmall.copyWith(
        color: AppColors.cardWhite,
      ),
    );
  }

  /// Progress indicator theme
  static ProgressIndicatorThemeData get progressIndicatorTheme {
    return const ProgressIndicatorThemeData(
      color: AppColors.primaryBlue,
      linearTrackColor: AppColors.divider,
      circularTrackColor: AppColors.divider,
    );
  }
}
