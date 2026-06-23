// lib/widgets/common/profile/utils/result_displayer.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/logger.dart';

/// Utility for displaying operation results via snackbars.
class ResultDisplayer {
  /// Show an operation result with consistent styling.
  ///
  /// [context] - The build context.
  /// [success] - Whether the operation was successful.
  /// [message] - The message to display.
  /// [closeModal] - Whether to close the parent modal first.
  static void showResult(
    BuildContext context, {
    required bool success,
    required String message,
    bool closeModal = false,
  }) {
    if (closeModal) {
      // Capture context-dependent values before async gap
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final successColor = context.butleryColors.success;
      final errorColor = Theme.of(context).colorScheme.error;

      Navigator.of(context).pop();

      Future.delayed(AppDimensions.animationDurationCommon, () {
        _showSnackBarDirect(
          scaffoldMessenger,
          success,
          message,
          successColor,
          errorColor,
        );
      });
    } else {
      _showSnackBar(context, success, message);
    }
  }

  static void _showSnackBar(
    BuildContext context,
    bool success,
    String message,
  ) {
    try {
      if (!context.mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      _showSnackBarDirect(
        scaffoldMessenger,
        success,
        message,
        context.butleryColors.success,
        Theme.of(context).colorScheme.error,
      );
    } catch (e) {
      AppLogger.error('Failed to show result', e);
    }
  }

  static void _showSnackBarDirect(
    ScaffoldMessengerState messenger,
    bool success,
    String message,
    Color successColor,
    Color errorColor,
  ) {
    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? successColor : errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show result', e);
    }
  }
}
