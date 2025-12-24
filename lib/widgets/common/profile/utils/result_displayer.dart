// lib/widgets/common/profile/utils/result_displayer.dart

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
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
      // Close the modal first
      Navigator.of(context).pop();

      // Use a delay to show the snackbar after the modal closes
      Future.delayed(const Duration(milliseconds: 300), () {
        _showSnackBar(context, success, message);
      });
    } else {
      _showSnackBar(context, success, message);
    }
  }

  static void _showSnackBar(BuildContext context, bool success, String message) {
    try {
      if (!context.mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show result', e);
    }
  }
}
