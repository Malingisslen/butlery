// lib/core/dialogs/dialog_factory.dart - FACADE PATTERN
// Maintains backward compatibility while delegating to focused components
// Split into focused files: base, confirmation, feedback, interactive

import 'package:flutter/material.dart';
import 'package:butlery/core/dialogs/dialog_factory_base.dart';
import 'package:butlery/core/dialogs/confirmation_dialog_factory.dart';
import 'package:butlery/core/dialogs/feedback_dialog_factory.dart';
import 'package:butlery/core/dialogs/interactive_dialog_factory.dart';

// Export all components for backward compatibility
export 'dialog_factory_base.dart';
export 'confirmation_dialog_factory.dart';
export 'feedback_dialog_factory.dart';
export 'interactive_dialog_factory.dart';

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
  }) =>
      ConfirmationDialogFactory.showConfirmation(
        context,
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        isDangerous: isDangerous,
      );

  /// Show delete confirmation (specialized dangerous confirmation)
  static Future<bool?> showDeleteConfirmation(
    BuildContext context, {
    required String itemName,
    String itemType = 'detta',
  }) =>
      ConfirmationDialogFactory.showDeleteConfirmation(
        context,
        itemName: itemName,
        itemType: itemType,
      );

  /// Show exit/discard changes confirmation
  static Future<bool?> showExitConfirmation(
    BuildContext context, {
    String title = 'Osparade ändringar',
    String message = 'Du har osparade ändringar. Vill du verkligen lämna utan att spara?',
  }) =>
      ConfirmationDialogFactory.showExitConfirmation(
        context,
        title: title,
        message: message,
      );

  // ===== FEEDBACK DIALOGS =====

  /// Show error dialog with optional retry action
  static Future<bool?> showError(
    BuildContext context, {
    String title = 'Ett fel uppstod',
    required String message,
    String? retryText,
    VoidCallback? onRetry,
    String dismissText = 'OK',
  }) =>
      FeedbackDialogFactory.showError(
        context,
        title: title,
        message: message,
        retryText: retryText,
        onRetry: onRetry,
        dismissText: dismissText,
      );

  /// Show network error dialog with retry
  static Future<bool?> showNetworkError(
    BuildContext context, {
    String message = 'Kunde inte ansluta till servern. Kontrollera din internetanslutning.',
    VoidCallback? onRetry,
  }) =>
      FeedbackDialogFactory.showNetworkError(
        context,
        message: message,
        onRetry: onRetry,
      );

  /// Show success dialog with optional action
  static Future<bool?> showSuccess(
    BuildContext context, {
    String title = 'Klart!',
    required String message,
    String? actionText,
    VoidCallback? onAction,
    String dismissText = 'OK',
  }) =>
      FeedbackDialogFactory.showSuccess(
        context,
        title: title,
        message: message,
        actionText: actionText,
        onAction: onAction,
        dismissText: dismissText,
      );

  /// Show informational dialog
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String dismissText = 'OK',
    Widget? customContent,
  }) =>
      FeedbackDialogFactory.showInfo(
        context,
        title: title,
        message: message,
        dismissText: dismissText,
        customContent: customContent,
      );

  /// Show feature info dialog (for tooltips/help)
  static Future<void> showFeatureInfo(
    BuildContext context, {
    required String title,
    required String description,
    List<String>? bulletPoints,
  }) =>
      FeedbackDialogFactory.showFeatureInfo(
        context,
        title: title,
        description: description,
        bulletPoints: bulletPoints,
      );

  // ===== INTERACTIVE DIALOGS =====

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
  }) =>
      InteractiveDialogFactory.showTextInput(
        context,
        title: title,
        message: message,
        initialValue: initialValue,
        hintText: hintText,
        confirmText: confirmText,
        cancelText: cancelText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        required: required,
      );

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
  }) =>
      InteractiveDialogFactory.showMultiLineInput(
        context,
        title: title,
        message: message,
        initialValue: initialValue,
        hintText: hintText,
        confirmText: confirmText,
        cancelText: cancelText,
        maxLines: maxLines,
        maxLength: maxLength,
      );

  /// Show single choice dialog (radio buttons)
  static Future<T?> showSingleChoice<T>(
    BuildContext context, {
    required String title,
    String? message,
    required List<DialogChoice<T>> choices,
    T? initialValue,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
  }) =>
      InteractiveDialogFactory.showSingleChoice<T>(
        context,
        title: title,
        message: message,
        choices: choices,
        initialValue: initialValue,
        confirmText: confirmText,
        cancelText: cancelText,
      );

  /// Show multiple choice dialog (checkboxes)
  static Future<List<T>?> showMultipleChoice<T>(
    BuildContext context, {
    required String title,
    String? message,
    required List<DialogChoice<T>> choices,
    List<T>? initialValues,
    String confirmText = 'OK',
    String cancelText = 'Avbryt',
  }) =>
      InteractiveDialogFactory.showMultipleChoice<T>(
        context,
        title: title,
        message: message,
        choices: choices,
        initialValues: initialValues,
        confirmText: confirmText,
        cancelText: cancelText,
      );

  // ===== LOADING DIALOGS =====

  /// Show loading dialog (non-dismissible)
  static void showLoading(
    BuildContext context, {
    String message = 'Laddar...',
  }) =>
      InteractiveDialogFactory.showLoading(
        context,
        message: message,
      );

  /// Hide loading dialog
  static void hideLoading(BuildContext context) =>
      InteractiveDialogFactory.hideLoading(context);

  /// Show loading dialog, execute async operation, then hide dialog
  static Future<T> withLoading<T>(
    BuildContext context,
    Future<T> operation, {
    String message = 'Laddar...',
  }) =>
      InteractiveDialogFactory.withLoading<T>(
        context,
        operation,
        message: message,
      );
}