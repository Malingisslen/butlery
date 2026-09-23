// lib/widgets/common/profile/utils/result_displayer.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Utility for displaying operation results via snackbars.
///
/// Every result is the ink snackbar (Komponentark v1:745-750; produktbeslut
/// PQ-09 = A): no green or red status fill (Komponentark v1:300), the
/// message says what happened. A failure gets "Stäng" and stays until the
/// user closes it, like every other error through SnackBarUtils.showError
/// (content-style-guide.md:97; Komponentark v1:750, never "OK").
class ResultDisplayer {
  /// Show an operation result with consistent styling.
  ///
  /// [context] - The build context.
  /// [success] - Whether the operation was successful. The look is the same
  /// either way; the message carries the outcome. A failure gets "Stäng".
  /// [message] - The message to display.
  /// [closeModal] - Whether to close the parent modal first.
  static void showResult(
    BuildContext context, {
    required bool success,
    required String message,
    bool closeModal = false,
  }) {
    // The label is read before any pop: the modal's context is gone after.
    final closeLabel = success ? null : context.l10n.commonClose;
    if (closeModal) {
      // Capture the messenger before the async gap: the modal's context is
      // gone once it has popped.
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      Navigator.of(context).pop();

      Future.delayed(AppDimensions.animationDurationCommon, () {
        _showSnackBarDirect(scaffoldMessenger, message, closeLabel);
      });
    } else {
      _showSnackBar(context, message, closeLabel);
    }
  }

  static void _showSnackBar(
    BuildContext context,
    String message,
    String? closeLabel,
  ) {
    try {
      if (!context.mounted) return;
      _showSnackBarDirect(ScaffoldMessenger.of(context), message, closeLabel);
    } catch (e) {
      AppLogger.error('Failed to show result', e);
    }
  }

  static void _showSnackBarDirect(
    ScaffoldMessengerState messenger,
    String message,
    String? closeLabel,
  ) {
    try {
      final action = closeLabel == null
          ? null
          : InkSnackBarAction(
              label: closeLabel,
              onPressed: () => messenger.hideCurrentSnackBar(
                reason: SnackBarClosedReason.action,
              ),
            );
      messenger.showSnackBar(
        SnackBar(
          content: InkSnackBar(message: message, action: action),
          padding: InkSnackBar.padding,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          // A failure with "Stäng" stays until the user closes it, as the
          // errors through SnackBarUtils.showError do.
          persist: action != null,
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show result', e);
    }
  }
}
