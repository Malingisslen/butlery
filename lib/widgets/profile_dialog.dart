// lib/widgets/profile_dialog.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../core/injection.dart';
import '../theme/app_theme.dart';

/// Visar en enkel profil-dialog med användarinfo och logout-knapp
Future<void> showProfileDialog(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
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

/// Hanterar utloggning
Future<void> _handleLogout(BuildContext context) async {
  // Visa bekräftelse
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
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
