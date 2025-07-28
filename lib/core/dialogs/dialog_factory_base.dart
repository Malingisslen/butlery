// lib/core/dialogs/dialog_factory_base.dart
// Core infrastructure and common dialog patterns

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';

/// Base factory class that provides core dialog infrastructure
/// and common patterns for all dialog types
class BaseDialogFactory with ErrorHandlingMixin {
  // Prevent instantiation
  BaseDialogFactory._();
  
  /// Consolidated dialog execution with error handling
  static Future<T?> safeShowDialog<T>(
    String operationName,
    Future<T?> Function() dialogOperation,
  ) async {
    try {
      AppLogger.info('Showing dialog: $operationName');
      return await dialogOperation();
    } catch (e) {
      AppLogger.error('Failed to show dialog ($operationName): $e');
      return null;
    }
  }
  
  /// Show standard confirmation dialog (Yes/No, OK/Cancel)
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
    Color? confirmColor,
    bool isDangerous = false,
  }) async {
    // Validate inputs
    if (ValidationUtils.isNullOrEmpty(title) || ValidationUtils.isNullOrEmpty(message)) {
      return null;
    }

    return await safeShowDialog<bool>(
      'Show Confirmation Dialog',
      () => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: isDangerous 
                    ? AppColors.error 
                    : (confirmColor ?? AppColors.primaryBlue),
              ),
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class for dialog choices
class DialogChoice<T> {
  final String label;
  final String? subtitle;
  final T value;
  
  const DialogChoice({
    required this.label,
    this.subtitle,
    required this.value,
  });
}

/// Pre-defined dialog choices for common scenarios
class CommonDialogChoices {
  static List<DialogChoice<bool>> yesNo() => [
    const DialogChoice(label: 'Ja', value: true),
    const DialogChoice(label: 'Nej', value: false),
  ];
  
  static List<DialogChoice<String>> yesNoCancel() => [
    const DialogChoice(label: 'Ja', value: 'yes'),
    const DialogChoice(label: 'Nej', value: 'no'),
    const DialogChoice(label: 'Avbryt', value: 'cancel'),
  ];
  
  static List<DialogChoice<String>> saveDiscardCancel() => [
    const DialogChoice(label: 'Spara', value: 'save'),
    const DialogChoice(label: 'Kasta bort', value: 'discard'),
    const DialogChoice(label: 'Avbryt', value: 'cancel'),
  ];
}