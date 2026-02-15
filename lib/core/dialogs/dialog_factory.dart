// lib/core/dialogs/dialog_factory.dart - CONSOLIDATED VERSION
// Merged from confirmation_dialog_factory.dart + feedback_dialog_factory.dart + interactive_dialog_factory.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// Consolidated dialog factory with all dialog functionality
class DialogFactory {
  // Prevent instantiation
  DialogFactory._();

  /// Check if running on iOS platform (web-safe)
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  // Merged from confirmation_dialog_factory.dart
  /// Shows a platform-adaptive confirmation dialog.
  /// Uses CupertinoAlertDialog on iOS, AlertDialog on Android.
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
    bool isDangerous = false,
  }) {
    final l10n = context.l10n;
    final effectiveConfirmText = confirmText ?? l10n.commonOk;
    final effectiveCancelText = cancelText ?? l10n.commonCancel;
    final dangerColor =
        isDangerous ? Theme.of(context).colorScheme.error : confirmColor;

    if (_isIOS) {
      return showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(effectiveCancelText),
            ),
            CupertinoDialogAction(
              isDestructiveAction: isDangerous,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(effectiveConfirmText),
            ),
          ],
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(effectiveCancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: dangerColor,
            ),
            child: Text(effectiveConfirmText),
          ),
        ],
      ),
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
    final effectiveCancelText = cancelText ?? l10n.commonCancel;
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(effectiveCancelText),
          ),
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

  /// Platform-adaptive error dialog.
  /// Uses CupertinoAlertDialog on iOS, AlertDialog on Android.
  static Future<void> showError(
    BuildContext context, {
    String? title,
    required String message,
    String? buttonText,
  }) {
    final l10n = context.l10n;
    final effectiveTitle = title ?? l10n.dialogErrorTitle;
    final effectiveButtonText = buttonText ?? l10n.commonOk;

    if (_isIOS) {
      return showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(effectiveTitle),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(effectiveButtonText),
            ),
          ],
        ),
      );
    }

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
      builder: (dialogContext) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppDimensions.spacingM),
            Text(effectiveMessage),
          ],
        ),
      ),
    );
  }

  // Delete confirmation dialog
  static Future<bool?> showDeleteConfirmation(
    BuildContext context, {
    required String itemName,
    required String itemType,
    String? title,
    String? confirmText,
    String? cancelText,
  }) {
    final l10n = context.l10n;
    final effectiveTitle = title ?? l10n.dialogConfirmDeleteTitle;
    final effectiveConfirmText = confirmText ?? l10n.commonDelete;
    final effectiveCancelText = cancelText ?? l10n.commonCancel;

    return showConfirmation(
      context,
      title: effectiveTitle,
      message: l10n.dialogConfirmDeleteMessage(itemName, itemType),
      confirmText: effectiveConfirmText,
      cancelText: effectiveCancelText,
      isDangerous: true,
    );
  }

  // Text input dialog
  static Future<String?> showTextInput(
    BuildContext context, {
    required String title,
    String? hintText,
    String? initialValue,
    String? confirmText,
    String? cancelText,
    bool required = false,
    int maxLines = 1,
  }) {
    final l10n = context.l10n;
    final effectiveConfirmText = confirmText ?? l10n.commonOk;
    final effectiveCancelText = cancelText ?? l10n.commonCancel;
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
          keyboardType:
              maxLines > 1 ? TextInputType.multiline : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(effectiveCancelText),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) return;
              Navigator.pop(dialogContext, text.isEmpty ? null : text);
            },
            child: Text(effectiveConfirmText),
          ),
        ],
      ),
    );
  }
}
