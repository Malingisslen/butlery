// lib/services/dialog_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Service for handling common dialogs
/// Separates dialog business logic from UI layer
class DialogService {
  /// Show exit confirmation dialog
  static Future<bool> showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avsluta Butlery?'),
        content: const Text('Vill du verkligen avsluta appen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Avsluta'),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  /// Exit the application
  static Future<void> exitApp() async {
    await SystemNavigator.pop();
  }

  /// Show exit dialog and exit if confirmed
  static Future<void> showExitDialogAndExit(BuildContext context) async {
    final shouldExit = await showExitDialog(context);
    if (shouldExit && context.mounted) {
      await exitApp();
    }
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Bekräfta',
    String cancelText = 'Avbryt',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}