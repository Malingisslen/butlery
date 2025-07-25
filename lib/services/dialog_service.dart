// lib/services/dialog_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../core/base/base_service.dart';

/// Service for handling common dialogs
/// Separates dialog business logic from UI layer
class DialogService extends BaseService {
  
  @override
  String get serviceName => 'DialogService';

  /// Show exit confirmation dialog
  Future<bool> showExitDialog(BuildContext context) async {
    return await executeServiceOperation(
      () async {
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
      },
      operationName: 'Show exit dialog',
      defaultValue: false,
    ) ?? false;
  }

  /// Exit the application
  Future<void> exitApp() async {
    await executeServiceOperation(
      () async {
        await SystemNavigator.pop();
      },
      operationName: 'Exit application',
      requiresAuth: false,
    );
  }

  /// Show exit dialog and exit if confirmed
  Future<void> showExitDialogAndExit(BuildContext context) async {
    await executeServiceOperation(
      () async {
        final shouldExit = await showExitDialog(context);
        if (shouldExit && context.mounted) {
          await exitApp();
        }
      },
      operationName: 'Show exit dialog and exit',
      requiresAuth: false,
    );
  }

  /// Show confirmation dialog
  Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Bekräfta',
    String cancelText = 'Avbryt',
    bool isDestructive = false,
  }) async {
    return await executeServiceOperation(
      () async {
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
      },
      operationName: 'Show confirmation dialog',
      defaultValue: false,
      requiresAuth: false,
    ) ?? false;
  }
}