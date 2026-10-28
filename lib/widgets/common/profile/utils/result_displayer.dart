// lib/widgets/common/profile/utils/result_displayer.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';

/// Utility for displaying operation results via snackbars.
///
/// Every result is the ink snackbar (produktbeslut
/// PQ-09 = A): no green or red status fill, the
/// message says what happened. A failure gets "Stäng" and stays until the
/// user closes it, like every failure through SnackBarUtils.showFailure
/// (content-style-guide.md:97; never "OK").
class ResultDisplayer {
  /// A wait, not motion (produktbeslut R8-9 = A).
  static const Duration afterDialogWait = Duration(milliseconds: 300);

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
    // Captured before any pop: the modal's context is gone after.
    final snackBars = CapturedSnackBars.capture(context);
    void show() => success
        ? snackBars.showConfirmation(message, showCloseButton: false)
        : snackBars.showFailure(what: message);
    if (closeModal) {
      Navigator.of(context).pop();
      Future.delayed(afterDialogWait, show);
    } else {
      show();
    }
  }
}
