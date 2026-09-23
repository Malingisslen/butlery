// lib/widgets/common/feedback/snackbar_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

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
            Icon(
              Icons.check_circle,
              color: cs.surfaceContainerHighest,
              size: AppDimensions.iconSizeM,
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
        backgroundColor: context.butleryColors.success,
        behavior: SnackBarBehavior.floating,
        duration: AppDimensions.snackbarDuration,
      ),
    );
  }

  /// Show error snackbar: the ink failure snackbar with "Stäng"
  /// ([SnackBarUtils.showFailure]; content-style-guide.md:96, Komponentark
  /// v1:750). The legacy channel: new code calls
  /// SnackBarUtils.showFailure, and test/architecture/error_contract_test.dart
  /// freezes the calls that are left.
  static void showErrorSnackbar(BuildContext context, String message) {
    SnackBarUtils.showFailure(context, what: message);
  }

  /// Show error snackbar with a "Försök igen" retry action.
  ///
  /// After in-helper retries (`withRetry`) have already been exhausted, surface
  /// the failure with a tap-to-retry affordance so the user can manually try
  /// again without re-navigating.
  static void showErrorSnackbarWithRetry(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
  }) {
    SnackBarUtils.showFailure(
      context,
      what: message,
      action: FailureAction.retry(onRetry),
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
