/// 🔍 AI INFO BLOCK:
/// Component: DialogFactory - Eliminates 12+ duplicated dialog creation patterns
/// File: lib/core/dialogs/dialog_factory.dart
/// Quick Guide: Centralizes common dialog patterns used across the app
/// Dependencies IN: Flutter Material, Logger utilities
/// Dependencies OUT: Used by views and services for consistent dialog creation
/// Data flow: Caller -> DialogFactory -> showDialog -> User interaction -> Result
/// State management: Stateless factory with standard dialog patterns
/// Purpose: Eliminate duplicated dialog creation code and ensure consistency
/// Common issues: Dialog context management, result handling, styling consistency
/// Test coverage: Widget tests for all dialog variants and user interactions
/// Performance: No performance impact, simple factory pattern
/// Analytics: Dialog usage tracking, user interaction patterns
/// Code smells: None - clean abstraction for common UI patterns
/// Connected to: All views and services that show dialogs
/// Used in phases: Phase 6 - Eliminate Code Duplication Patterns

import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// Factory class that eliminates duplicated dialog creation patterns
/// 
/// This factory centralizes the common dialog patterns found throughout the app:
/// - Confirmation dialogs (Are you sure?)
/// - Error dialogs with retry options
/// - Success dialogs with actions
/// - Info dialogs with custom content
/// - Input dialogs for text entry
/// - Loading dialogs for async operations
/// 
/// Pattern eliminated:
/// ```dart
/// // Before (duplicated ~12 times):
/// showDialog<bool>(
///   context: context,
///   builder: (context) => AlertDialog(
///     title: Text('Bekräfta'),
///     content: Text('Är du säker?'),
///     actions: [
///       TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Avbryt')),
///       TextButton(onPressed: () => Navigator.pop(context, true), child: Text('OK')),
///     ],
///   ),
/// );
/// 
/// // After (centralized):
/// DialogFactory.showConfirmation(context, title: 'Bekräfta', message: 'Är du säker?');
/// ```
class DialogFactory {
  // Prevent instantiation
  DialogFactory._();
  
  // ===== CONFIRMATION DIALOGS =====
  
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
    try {
      return await showDialog<bool>(
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
                  ? Colors.red 
                  : confirmColor ?? Theme.of(context).primaryColor,
              ),
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show confirmation dialog: $e');
      return null;
    }
  }
  
  /// Show delete confirmation (specialized dangerous confirmation)
  static Future<bool?> showDeleteConfirmation(
    BuildContext context, {
    required String itemName,
    String itemType = 'detta',
  }) async {
    return showConfirmation(
      context,
      title: 'Ta bort $itemType',
      message: 'Är du säker på att du vill ta bort "$itemName"? Denna åtgärd kan inte ångras.',
      confirmText: 'Ta bort',
      cancelText: 'Avbryt',
      isDangerous: true,
    );
  }
  
  /// Show exit/discard changes confirmation
  static Future<bool?> showExitConfirmation(
    BuildContext context, {
    String title = 'Osparade ändringar',
    String message = 'Du har osparade ändringar. Vill du verkligen lämna utan att spara?',
  }) async {
    return showConfirmation(
      context,
      title: title,
      message: message,
      confirmText: 'Lämna',
      cancelText: 'Fortsätt redigera',
      isDangerous: true,
    );
  }
  
  // ===== ERROR DIALOGS =====
  
  /// Show error dialog with optional retry action
  static Future<bool?> showError(
    BuildContext context, {
    String title = 'Ett fel uppstod',
    required String message,
    String? retryText,
    VoidCallback? onRetry,
    String dismissText = 'OK',
  }) async {
    try {
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(dismissText),
            ),
            if (retryText != null && onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onRetry();
                },
                child: Text(retryText),
              ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show error dialog: $e');
      return null;
    }
  }
  
  /// Show network error dialog with retry
  static Future<bool?> showNetworkError(
    BuildContext context, {
    String message = 'Kunde inte ansluta till servern. Kontrollera din internetanslutning.',
    VoidCallback? onRetry,
  }) async {
    return showError(
      context,
      title: 'Anslutningsfel',
      message: message,
      retryText: onRetry != null ? 'Försök igen' : null,
      onRetry: onRetry,
    );
  }
  
  // ===== SUCCESS DIALOGS =====
  
  /// Show success dialog with optional action
  static Future<bool?> showSuccess(
    BuildContext context, {
    String title = 'Klart!',
    required String message,
    String? actionText,
    VoidCallback? onAction,
    String dismissText = 'OK',
  }) async {
    try {
      return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(dismissText),
            ),
            if (actionText != null && onAction != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onAction();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
                child: Text(actionText),
              ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show success dialog: $e');
      return null;
    }
  }
  
  // ===== INFO DIALOGS =====
  
  /// Show informational dialog
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String dismissText = 'OK',
    Widget? customContent,
  }) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: customContent ?? Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(dismissText),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show info dialog: $e');
    }
  }
  
  /// Show feature info dialog (for tooltips/help)
  static Future<void> showFeatureInfo(
    BuildContext context, {
    required String title,
    required String description,
    List<String>? bulletPoints,
  }) async {
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description),
        if (bulletPoints != null && bulletPoints.isNotEmpty) ...[
          SizedBox(height: 16),
          ...bulletPoints.map((point) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(point)),
              ],
            ),
          )),
        ],
      ],
    );
    
    return showInfo(
      context,
      title: title,
      message: '', // unused when customContent provided
      customContent: content,
      dismissText: 'Förstått',
    );
  }
  
  // ===== INPUT DIALOGS =====
  
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
                SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: OutlineInputBorder(),
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
                SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: OutlineInputBorder(),
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
  
  // ===== CHOICE DIALOGS =====
  
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
                  SizedBox(height: 16),
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
                  SizedBox(height: 16),
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
  
  // ===== LOADING DIALOGS =====
  
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
                CircularProgressIndicator(),
                SizedBox(width: 16),
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
  
  // ===== UTILITY METHODS =====
  
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
    DialogChoice(label: 'Ja', value: true),
    DialogChoice(label: 'Nej', value: false),
  ];
  
  static List<DialogChoice<String>> yesNoCancel() => [
    DialogChoice(label: 'Ja', value: 'yes'),
    DialogChoice(label: 'Nej', value: 'no'),
    DialogChoice(label: 'Avbryt', value: 'cancel'),
  ];
  
  static List<DialogChoice<String>> saveDiscardCancel() => [
    DialogChoice(label: 'Spara', value: 'save'),
    DialogChoice(label: 'Kasta bort', value: 'discard'),
    DialogChoice(label: 'Avbryt', value: 'cancel'),
  ];
}