// lib/widgets/common/profile/handlers/backup_restore_handler.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/backup_service.dart';
import 'package:butlery/widgets/common/profile/utils/result_displayer.dart';

/// Handler for backup and restore operations.
class BackupRestoreHandler {
  /// Handle backup operation.
  static Future<void> handleBackup(BuildContext context) async {
    try {
      final backupService = ServiceLocator.get<BackupService>();
      final result = await backupService.exportToFile();

      if (context.mounted) {
        if (result.success) {
          ResultDisplayer.showResult(
            context,
            success: true,
            message: result.message,
            closeModal: true,
          );
        } else {
          ResultDisplayer.showResult(
            context,
            success: false,
            message: 'Backup misslyckades: ${result.message}',
            closeModal: true,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Backup failed', e);
      if (context.mounted) {
        ResultDisplayer.showResult(
          context,
          success: false,
          message: 'Backup misslyckades: $e',
          closeModal: true,
        );
      }
    }
  }

  /// Handle restore operation.
  static Future<void> handleRestore(BuildContext context) async {
    try {
      final backupService = ServiceLocator.get<BackupService>();
      final result = await backupService.importFromFile();

      if (context.mounted) {
        if (result.success) {
          ResultDisplayer.showResult(
            context,
            success: true,
            message: 'Återställning genomförd!',
            closeModal: true,
          );
        } else if (result.cancelled) {
          // User cancelled - no message needed
          return;
        } else {
          ResultDisplayer.showResult(
            context,
            success: false,
            message:
                'Återställning misslyckades: ${result.errorMessage ?? 'Okänt fel'}',
            closeModal: true,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Restore failed', e);
      if (context.mounted) {
        ResultDisplayer.showResult(
          context,
          success: false,
          message: 'Återställning misslyckades: $e',
          closeModal: true,
        );
      }
    }
  }
}
