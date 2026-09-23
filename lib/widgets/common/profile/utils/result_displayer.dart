// lib/widgets/common/profile/utils/result_displayer.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Utility for displaying operation results via snackbars.
///
/// Every result is the ink snackbar (Komponentark v1:745-750; produktbeslut
/// PQ-09 = A): no green or red status fill (Komponentark v1:300), the
/// message says what happened.
class ResultDisplayer {
  /// Show an operation result with consistent styling.
  ///
  /// [context] - The build context.
  /// [success] - Whether the operation was successful. The look is the same
  /// either way; the message carries the outcome.
  /// [message] - The message to display.
  /// [closeModal] - Whether to close the parent modal first.
  static void showResult(
    BuildContext context, {
    required bool success,
    required String message,
    bool closeModal = false,
  }) {
    if (closeModal) {
      // Capture the messenger before the async gap: the modal's context is
      // gone once it has popped.
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      Navigator.of(context).pop();

      Future.delayed(AppDimensions.animationDurationCommon, () {
        _showSnackBarDirect(scaffoldMessenger, message);
      });
    } else {
      _showSnackBar(context, message);
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    try {
      if (!context.mounted) return;
      _showSnackBarDirect(ScaffoldMessenger.of(context), message);
    } catch (e) {
      AppLogger.error('Failed to show result', e);
    }
  }

  static void _showSnackBarDirect(
    ScaffoldMessengerState messenger,
    String message,
  ) {
    try {
      messenger.showSnackBar(
        SnackBar(
          content: InkSnackBar(message: message),
          padding: InkSnackBar.padding,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show result', e);
    }
  }
}
