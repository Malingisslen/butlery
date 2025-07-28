// lib/core/dialogs/confirmation_dialog_factory.dart
// All confirmation-related dialogs

import 'package:flutter/material.dart';
import 'package:butlery/core/dialogs/dialog_factory_base.dart';

/// Factory for confirmation-related dialogs
class ConfirmationDialogFactory {
  // Prevent instantiation
  ConfirmationDialogFactory._();

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
      BaseDialogFactory.showConfirmation(
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
}