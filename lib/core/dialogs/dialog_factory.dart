// lib/core/dialogs/dialog_factory.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
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

    return showButleryDialog<void>(
      context: context,
      builder: (dialogContext) => ButleryDialog.notice(
        title: effectiveTitle,
        message: message,
        closeLabel: effectiveButtonText,
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

    return showButleryDialog<String>(
      context: context,
      builder: (dialogContext) => ButleryDialog(
        title: title,
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
          ButleryDialogPrimary(
            label: confirmText,
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) return;
              Navigator.pop(dialogContext, text.isEmpty ? null : text);
            },
          ),
        ],
      ),
    );
  }
}
