// lib/core/dialogs/interactive_dialog_factory.dart
// User input and choice dialogs + loading utilities

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/dialogs/dialog_factory_base.dart';

/// Factory for interactive dialogs and loading management
class InteractiveDialogFactory {
  // Prevent instantiation
  InteractiveDialogFactory._();

  /// Show text input dialog
  static Future<String?> showTextInput(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool required = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: AppDimensions.spacingXl),
              ],
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: keyboardType,
                maxLength: maxLength,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (required && value.isEmpty) {
                  return; // Don't close dialog if required field is empty
                }
                Navigator.of(context).pop(value);
              },
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show text input dialog: $e');
      return null;
    } finally {
      controller.dispose();
    }
  }

  /// Show multi-line text input dialog
  static Future<String?> showMultiLineInput(
    BuildContext context, {
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
    int maxLines = 4,
    int? maxLength,
  }) async {
    final controller = TextEditingController(text: initialValue);
    
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: AppDimensions.spacingXl),
              ],
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                ),
                maxLines: maxLines,
                maxLength: maxLength,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show multi-line input dialog: $e');
      return null;
    } finally {
      controller.dispose();
    }
  }

  /// Show single choice dialog (radio buttons)
  static Future<T?> showSingleChoice<T>(
    BuildContext context, {
    required String title,
    String? message,
    required List<DialogChoice<T>> choices,
    T? initialValue,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
  }) async {
    T? selectedValue = initialValue;
    
    try {
      return await showDialog<T>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message != null) ...[
                  Text(message),
                  const SizedBox(height: AppDimensions.spacingXl),
                ],
                ...choices.map((choice) => RadioListTile<T>(
                  title: Text(choice.label),
                  subtitle: choice.subtitle != null ? Text(choice.subtitle!) : null,
                  value: choice.value,
                  groupValue: selectedValue,
                  onChanged: (value) => setState(() => selectedValue = value),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(selectedValue),
                child: Text(confirmText),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show single choice dialog: $e');
      return null;
    }
  }

  /// Show multiple choice dialog (checkboxes)
  static Future<List<T>?> showMultipleChoice<T>(
    BuildContext context, {
    required String title,
    String? message,
    required List<DialogChoice<T>> choices,
    List<T>? initialValues,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
  }) async {
    final selectedValues = Set<T>.from(initialValues ?? []);
    
    try {
      return await showDialog<List<T>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message != null) ...[
                  Text(message),
                  const SizedBox(height: AppDimensions.spacingXl),
                ],
                ...choices.map((choice) => CheckboxListTile(
                  title: Text(choice.label),
                  subtitle: choice.subtitle != null ? Text(choice.subtitle!) : null,
                  value: selectedValues.contains(choice.value),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      selectedValues.add(choice.value);
                    } else {
                      selectedValues.remove(choice.value);
                    }
                  }),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(selectedValues.toList()),
                child: Text(confirmText),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show multiple choice dialog: $e');
      return null;
    }
  }

  /// Show loading dialog (non-dismissible)
  static void showLoading(
    BuildContext context, {
    String message = 'Laddar...',
  }) {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show loading dialog: $e');
    }
  }

  /// Hide loading dialog
  static void hideLoading(BuildContext context) {
    try {
      Navigator.of(context).pop();
    } catch (e) {
      AppLogger.error('Failed to hide loading dialog: $e');
    }
  }

  /// Show loading dialog, execute async operation, then hide dialog
  static Future<T> withLoading<T>(
    BuildContext context,
    Future<T> operation, {
    String message = 'Laddar...',
  }) async {
    showLoading(context, message: message);
    try {
      final result = await operation;
      if (context.mounted) {
        hideLoading(context);
      }
      return result;
    } catch (e) {
      if (context.mounted) {
        hideLoading(context);
      }
      rethrow;
    }
  }
}