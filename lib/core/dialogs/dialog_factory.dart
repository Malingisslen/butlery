// lib/core/dialogs/dialog_factory.dart - CONSOLIDATED VERSION
// Merged from confirmation_dialog_factory.dart + feedback_dialog_factory.dart + interactive_dialog_factory.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// Consolidated dialog factory with all dialog functionality
class DialogFactory {
  // Prevent instantiation
  DialogFactory._();

  // Merged from confirmation_dialog_factory.dart
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'OK',
    String cancelText = AppStrings.cancel,
    Color? confirmColor,
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isDangerous ? AppColors.error : confirmColor,
            ),
            child: Text(confirmText),
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
    String confirmText = AppStrings.send,
    String cancelText = AppStrings.cancel,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: StyledInput.multiline(
          controller: controller,
          hint: hint,
          maxLines: 3,
          minLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirmText),
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
      builder: (context) => AlertDialog(
        title: title != null ? Text(title) : null,
        content: content,
        actions: actions,
      ),
    );
  }

  // Common error dialog
  static Future<void> showError(
    BuildContext context, {
    String title = 'Ett fel uppstod',
    required String message,
    String buttonText = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  // Loading dialog
  static Future<void> showLoading(
    BuildContext context, {
    String message = 'Laddar...',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppDimensions.spacingM),
            Text(message),
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
    String title = 'Bekräfta borttagning',
    String confirmText = AppStrings.delete,
    String cancelText = AppStrings.cancel,
  }) {
    return showConfirmation(
      context,
      title: title,
      message: 'Är du säker på att du vill ta bort $itemName från $itemType?',
      confirmText: confirmText,
      cancelText: cancelText,
      isDangerous: true,
    );
  }

  // Text input dialog
  static Future<String?> showTextInput(
    BuildContext context, {
    required String title,
    String? hintText,
    String? initialValue,
    String confirmText = 'OK',
    String cancelText = AppStrings.cancel,
    bool required = false,
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: StyledInput(
          controller: controller,
          hint: hintText,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          autofocus: true,
          keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) return;
              Navigator.pop(context, text.isEmpty ? null : text);
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}