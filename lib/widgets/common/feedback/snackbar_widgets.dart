// lib/widgets/common/feedback/snackbar_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// SnackbarWidgets - Snackbar utility widgets
/// Provides consistent snackbar implementations for different message types.
class SnackbarWidgets {
  /// Visa success snackbar
  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle,
                color: AppColors.neutralLight, size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.neutralLight),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Visa error snackbar
  static void showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error,
                color: AppColors.neutralLight, size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.neutralLight),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Visa warning snackbar
  static void showWarningSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_outlined,
              size: AppDimensions.iconSizeM,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.neutralLight),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
