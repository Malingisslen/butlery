// lib/widgets/common/profile/dialogs/profile_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

/// Dialog builders for profile actions.
/// Provides static methods for showing various confirmation and input dialogs.
class ProfileDialogs {
  /// Show logout confirmation dialog.
  static Future<bool?> showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logga ut'),
        content: const Text('Är du säker på att du vill logga ut?'),
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
            child: const Text('Logga ut'),
          ),
        ],
      ),
    );
  }

  /// Show delete account confirmation dialog.
  static Future<bool?> showDeleteAccountDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radera konto permanent'),
        content: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VARNING: Detta kommer att:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text('• Ta bort alla dina recept'),
              const Text('• Ta bort alla dina menyer'),
              const Text('• Ta bort alla dina shoppinglistor'),
              const Text('• Ta bort alla vänner och meddelanden'),
              const Text('• Ta bort all delad innehåll'),
              const SizedBox(height: 16),
              Text(
                'Denna åtgärd kan INTE ångras!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
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
            child: const Text('Jag förstår, radera mitt konto'),
          ),
        ],
      ),
    );
  }

  /// Show password re-authentication dialog.
  static Future<String?> showPasswordDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bekräfta med lösenord'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ange ditt lösenord för att bekräfta raderingen:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Lösenord',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Bekräfta'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog.
  static void showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fel'),
        content: Text('Kunde inte radera konto: $error'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
