// lib/widgets/common/feedback/snackbar_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// SnackbarWidgets - Snackbar utility widgets
/// Provides consistent snackbar implementations for different message types.
class SnackbarWidgets {
  /// Show success snackbar
  static void showSuccessSnackbar(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle,
                color: cs.surfaceContainerHighest,
                size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyLargeLight,
              ),
            ),
          ],
        ),
        backgroundColor: context.butleryColors.success,
        behavior: SnackBarBehavior.floating,
        duration: AppDimensions.snackbarDuration,
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackbar(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error,
                color: cs.surfaceContainerHighest,
                size: AppDimensions.iconSizeM),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyLargeLight,
              ),
            ),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show warning snackbar
  static void showWarningSnackbar(BuildContext context, String message) {
    final warningColor = context.butleryColors.warning;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.warning_outlined,
              size: AppDimensions.iconSizeM,
              color: cs.surfaceContainerHighest,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyLargeLight,
              ),
            ),
          ],
        ),
        backgroundColor: warningColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
