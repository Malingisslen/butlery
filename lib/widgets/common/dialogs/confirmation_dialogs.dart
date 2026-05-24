// lib/widgets/common/dialogs/confirmation_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

/// Confirmation dialogs for user actions
/// Refactored to use BaseDialog classes, eliminating 50+ lines of duplicate dialog code.
class ConfirmationDialogs {
  /// Standard confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'OK',
    String? cancelText,
    Color? confirmColor,
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

  /// ⚠️ Destructive confirmation dialog (red confirm button)
  static Future<bool> showDestructiveConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
  }) async {
    return await DestructiveConfirmationDialog.show(
          context,
          title: title,
          message: message,
          itemName: '', // Can be enhanced if needed
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
            title: Text(title, style: AppTextStyles.headlineSmall),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: AppTextStyles.bodyLarge),
                const SizedBox(height: AppDimensions.spacingXl),
                Row(
                  children: [
                    const SizedBox(
                      width: AppDimensions.iconSizeM,
                      height: AppDimensions.iconSizeM,
                      child: LoadingIndicator(
                        size: AppDimensions.iconSizeS,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Text(
                      context.l10n.dialogMayTakeAWhile,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText ?? context.l10n.commonCancel,
                    style: AppTextStyles.labelLarge),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmText ?? context.l10n.commonContinue,
                    style: AppTextStyles.labelLarge),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 📋 List selection confirmation dialog
  static Future<int?> showListSelectionDialog<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required String Function(T) itemBuilder,
    String? message,
    String? cancelText,
  }) async {
    return await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppTextStyles.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(message, style: AppTextStyles.bodyLarge),
              const SizedBox(height: AppDimensions.spacingXl),
            ],
            Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(
                      itemBuilder(item),
                      style: AppTextStyles.bodyLarge,
                    ),
                    onTap: () => Navigator.of(context).pop(index),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(cancelText ?? context.l10n.commonCancel,
                style: AppTextStyles.labelLarge),
          ),
        ],
      ),
    );
  }

  /// 📝 Text input confirmation dialog
  static Future<String?> showTextInputDialog(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String confirmText = 'OK',
    String? cancelText,
    bool isRequired = false,
    int? maxLength,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');

    return await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppTextStyles.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(message, style: AppTextStyles.bodyLarge),
              const SizedBox(height: AppDimensions.spacingXl),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: maxLength,
              decoration: InputDecoration(
                hintText: hintText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(cancelText ?? context.l10n.commonCancel,
                style: AppTextStyles.labelLarge),
          ),
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
