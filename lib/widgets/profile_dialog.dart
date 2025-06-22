// lib/widgets/profile_dialog.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../core/injection.dart';
import '../theme/app_theme.dart';

/// Visar en enkel profil-dialog med användarinfo och backup-funktioner
Future<void> showProfileDialog(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.account_circle,
            color: AppTheme.primaryColor,
            size: AppTheme.iconSizeAction,
          ),
          SizedBox(width: AppTheme.spacingSm),
          const Text('Min profil'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Användarnamn
          _buildInfoRow(
            context: context,
            icon: Icons.person_outline,
            label: 'Namn',
            value: user.displayName ?? 'Ingen namn angiven',
          ),
          AppTheme.smallGap,

          // Email
          _buildInfoRow(
            context: context,
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email ?? 'Ingen email',
          ),
          AppTheme.smallGap,

          // Medlem sedan
          _buildInfoRow(
            context: context,
            icon: Icons.calendar_today,
            label: 'Medlem sedan',
            value: _formatDate(user.metadata.creationTime),
          ),
          AppTheme.largeGap,

          // Divider innan data-sektionen
          const Divider(),
          AppTheme.mediumGap,

          // Data & Backup sektion
          Text(
            'Data & Backup',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppTheme.smallGap,

          // Export-knapp
          _buildDataButton(
            context: context,
            icon: Icons.download,
            label: 'Ladda ner backup',
            subtitle: 'Spara alla recept som JSON',
            onPressed: () => _handleBackup(context),
            color: AppTheme.primaryColor,
          ),
          AppTheme.smallGap,

          // Import-knapp
          _buildDataButton(
            context: context,
            icon: Icons.upload,
            label: 'Återställ från backup',
            subtitle: 'Importera recept från JSON',
            onPressed: () => _handleRestore(context),
            color: AppTheme.accentColor,
          ),
        ],
      ),
      actions: [
        // Stäng-knapp
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Stäng'),
        ),

        // Logga ut-knapp
        FilledButton.tonalIcon(
          onPressed: () => _handleLogout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Logga ut'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
            foregroundColor: AppTheme.errorColor,
          ),
        ),
      ],
    ),
  );
}

/// Bygger en info-rad med ikon och text
Widget _buildInfoRow({
  required BuildContext context,
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: AppTheme.iconSizeInfo, color: AppTheme.textSecondary),
      SizedBox(width: AppTheme.spacingSm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.captionStyle),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ],
  );
}

/// Bygger en data-knapp med ikon och text
Widget _buildDataButton({
  required BuildContext context,
  required IconData icon,
  required String label,
  required String subtitle,
  required VoidCallback onPressed,
  required Color color,
}) {
  return Material(
    color: color.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            Icon(icon, color: color, size: AppTheme.iconSizeDisplay),
            SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
              size: AppTheme.iconSizeNavigation,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Formaterar datum till svensk format
String _formatDate(DateTime? date) {
  if (date == null) return 'Okänt datum';

  final months = [
    'januari',
    'februari',
    'mars',
    'april',
    'maj',
    'juni',
    'juli',
    'augusti',
    'september',
    'oktober',
    'november',
    'december',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Hanterar backup av recept
Future<void> _handleBackup(BuildContext context) async {
  try {
    // Visa loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Skapar backup...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Använd BackupService istället för ShareService
    final backupService = BackupService();
    final result = await backupService.exportToFile();

    // Stäng loading
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Visa resultat
    if (context.mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.recipeCount} recept sparade!\n${result.message}',
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  } catch (e) {
    // Stäng loading om den fortfarande visas
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup misslyckades: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

/// Hanterar återställning från backup
Future<void> _handleRestore(BuildContext context) async {
  try {
    // Använd BackupService för import
    final backupService = BackupService();
    final result = await backupService.importFromFile();

    if (result.cancelled) {
      return; // Användaren avbröt
    }

    if (result.errorMessage != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    // Visa loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Bearbetar import...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Vänta lite för att visa loading (import är redan klar)
    await Future.delayed(const Duration(milliseconds: 500));

    // Stäng loading
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Visa resultat
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import slutförd'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Totalt antal recept: ${result.totalRecipes}'),
                Text(
                  '✅ Importerade: ${result.successCount}',
                  style: TextStyle(color: AppTheme.successColor),
                ),
                if (result.skipCount > 0) ...[
                  Text(
                    '⏭️ Överhoppade: ${result.skipCount}',
                    style: TextStyle(color: AppTheme.warningColor),
                  ),
                  if (result.skippedTitles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Redan existerande recept:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    ...result.skippedTitles.take(5).map(
                          (title) => Text(
                            '• $title',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    if (result.skippedTitles.length > 5)
                      Text(
                        '... och ${result.skippedTitles.length - 5} till',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 8),
                if (result.exportEmail != null)
                  Text(
                    'Backup från: ${result.exportEmail}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (result.exportDate != null)
                  Text(
                    'Skapad: ${_formatDate(result.exportDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Fel vid import:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
                    ),
                  ),
                  ...result.errors.take(3).map(
                        (error) => Text(
                          '• $error',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                  if (result.errors.length > 3)
                    Text(
                      '... och ${result.errors.length - 3} till',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import misslyckades: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

/// Hanterar utloggning
Future<void> _handleLogout(BuildContext context) async {
  // Visa bekräftelse
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logga ut?'),
      content: const Text('Är du säker på att du vill logga ut?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
          ),
          child: const Text('Logga ut'),
        ),
      ],
    ),
  );

  if (shouldLogout == true && context.mounted) {
    try {
      // Stäng alla dialoger
      Navigator.of(context).pop();

      // Logga ut via AuthService
      final authService = sl<AuthService>();
      await authService.signOut();

      // Navigation hanteras automatiskt av AuthWrapper i main.dart
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte logga ut: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
