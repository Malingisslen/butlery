// lib/core/dialogs/dialog_factory.dart - CONSOLIDATED VERSION
// Merged from confirmation_dialog_factory.dart + feedback_dialog_factory.dart + interactive_dialog_factory.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Consolidated dialog factory with all dialog functionality
class DialogFactory {
  // Prevent instantiation
  DialogFactory._();

  /// A confirmation with a caller-named action; [confirmText] says what the
  /// button does (content-style-guide.md). [isDangerous] draws the shared
  /// destructive dialog (BUT-2366), so [confirmText] then names what
  /// disappears; [dangerIcon] replaces the trash glyph when nothing is
  /// deleted.
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
    bool isDangerous = false,
    IconData dangerIcon = ButleryIcons.trash2,
  }) {
    if (isDangerous) {
      return DestructiveConfirmationDialog.show(
        context,
        title: title,
        message: message,
        primaryActionText: confirmText,
        secondaryActionText: cancelText,
        primaryActionIcon: dangerIcon,
      );
    }
    return ConfirmationDialog.show(
      context,
      title: title,
      message: message,
      primaryActionText: confirmText,
      secondaryActionText: cancelText,
    );
  }

  // Merged from feedback_dialog_factory.dart
  static Future<String?> showFeedback(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    String? confirmText,
    String? cancelText,
  }) {
    final l10n = context.l10n;
    final effectiveConfirmText = confirmText ?? l10n.commonSend;
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: StyledInput.multiline(
          controller: controller,
          hint: hint,
          maxLines: 3,
          minLines: 3,
        ),
        actions: [
          DialogCancelButton(label: cancelText),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(effectiveConfirmText),
          ),
        ],
      ),
    );
  }

  // Merged from interactive_dialog_factory.dart
  static Future<T?> showInteractive<T>(
    BuildContext context, {
    required Widget content,
    String? title,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: title != null ? Text(title) : null,
        content: content,
        actions: actions,
      ),
    );
  }

  /// Error dialog, one Material dialog on both platforms
  /// (plattformsmatris.md:73-75).
  ///
  /// [buttonText] stays optional; without it the only button closes the
  /// dialog and says "Stäng" (commonClose), never "OK"
  /// (content-style-guide.md).
  static Future<void> showError(
    BuildContext context, {
    String? title,
    required String message,
    String? buttonText,
  }) {
    final l10n = context.l10n;
    final effectiveTitle = title ?? l10n.dialogErrorTitle;
    final effectiveButtonText = buttonText ?? l10n.commonClose;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(effectiveTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(effectiveButtonText),
          ),
        ],
      ),
    );
  }

  // Loading dialog
  static Future<void> showLoading(
    BuildContext context, {
    String? message,
  }) {
    final l10n = context.l10n;
    final effectiveMessage = message ?? l10n.dialogLoading;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      // Plate line plus text, never a spinner (produktregler.md:163, B-18).
      builder: (dialogContext) => AlertDialog(
        content: PlateLineMessage(
          message: effectiveMessage,
          textAlign: TextAlign.start,
        ),
      ),
    );
  }

  // Text input dialog. [confirmText] is required and says what the button
  // does (content-style-guide.md).
  static Future<String?> showTextInput(
    BuildContext context, {
    required String title,
    String? hintText,
    String? initialValue,
    required String confirmText,
    String? cancelText,
    bool required = false,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: StyledInput(
          controller: controller,
          hint: hintText,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          autofocus: true,
          keyboardType: maxLines > 1
              ? TextInputType.multiline
              : TextInputType.text,
        ),
        actions: [
          DialogCancelButton(label: cancelText),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) return;
              Navigator.pop(dialogContext, text.isEmpty ? null : text);
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}
