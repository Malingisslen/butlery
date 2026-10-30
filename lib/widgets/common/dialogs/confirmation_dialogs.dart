// lib/widgets/common/dialogs/confirmation_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/input/labeled_field.dart';

/// Confirmation dialogs for user actions
/// Refactored to use BaseDialog classes, eliminating 50+ lines of duplicate dialog code.
class ConfirmationDialogs {
  /// Standard confirmation dialog. [confirmText] says what happens
  /// (content-style-guide.md:77), so there is no "OK" default.
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
  }) async {
    return await ConfirmationDialog.show(
          context,
          title: title,
          message: message,
          primaryActionText: confirmText,
          secondaryActionText: cancelText,
        ) ??
        false;
  }

  /// The shared destructive confirmation (BUT-2366); [confirmText] names
  /// what disappears.
  static Future<bool> showDestructiveConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
  }) async {
    return await DestructiveConfirmationDialog.show(
          context,
          title: title,
          message: message,
          primaryActionText: confirmText,
          secondaryActionText: cancelText,
        ) ??
        false;
  }

  /// 🔄 Loading confirmation dialog
  static Future<bool> showLoadingConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(title, style: AppTextStyles.headlineSmall),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppDimensions.space32),
                // Plate line plus text, never a spinner (
                // B-18). The line carries the text as its semantic label.
                ExcludeSemantics(
                  child: Text(
                    context.l10n.dialogMayTakeAWhile,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space8),
                PlateLine(semanticLabel: context.l10n.dialogMayTakeAWhile),
              ],
            ),
            actions: [
              // A dismissed dialog answers null, which the ?? false below
              // turns into the same no.
              DialogCancelButton(label: cancelText),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  confirmText ?? context.l10n.commonContinue,
                  style: AppTextStyles.labelLarge,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 📝 Text input confirmation dialog
  static Future<String?> showTextInputDialog(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    required String confirmText,
    String? cancelText,
    bool isRequired = false,
    int? maxLength,
  }) async {
    final controller = TextEditingController(text: initialValue.orEmpty());

    return await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title, style: AppTextStyles.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(message, style: AppTextStyles.bodyLarge),
              const SizedBox(height: AppDimensions.space32),
            ],
            LabeledField(
              child: TextField(
                controller: controller,
                autofocus: true,
                maxLength: maxLength,
                decoration: InputDecoration(
                  hintText: hintText,
                ),
              ),
            ),
          ],
        ),
        actions: [
          DialogCancelButton(label: cancelText),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (isRequired && text.isEmpty) {
                return;
              }
              Navigator.of(context).pop(text);
            },
            child: Text(confirmText, style: AppTextStyles.labelLarge),
          ),
        ],
      ),
    );
  }
}
