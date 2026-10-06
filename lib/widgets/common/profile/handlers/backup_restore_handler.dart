// lib/widgets/common/profile/handlers/backup_restore_handler.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/backup_service.dart';
import 'package:butlery/widgets/common/profile/utils/result_displayer.dart';

/// A wait, not motion (produktbeslut R8-9 = A).
const Duration _afterDialogWait = Duration(milliseconds: 300);

/// Handler for backup and restore operations.
///
/// [closeModal] says whether [BuildContext] sits in a modal (the profile
/// sheet) that closes before the result shows. A plain page such as
/// Inställningar passes false: closing would pop the page itself (BUT-2150).
class BackupRestoreHandler {
  /// Handle backup operation.
  static Future<void> handleBackup(
    BuildContext context, {
    bool closeModal = true,
  }) async {
    try {
      final backupService = ServiceLocator.get<BackupService>();
      final result = await backupService.exportToFile();

      if (context.mounted) {
        if (result.success) {
          ResultDisplayer.showResult(
            context,
            success: true,
            message: result.message,
            closeModal: closeModal,
          );
        } else if (result.unexpected) {
          // The service caught an exception and logged it; the user gets
          // the same three parts as a thrown failure below.
          _showFailure(
            context,
            what: context.l10n.profileBackupNotSaved,
            preserved: context.l10n.profileBackupRecipesKept,
            closeModal: closeModal,
          );
        } else {
          ResultDisplayer.showResult(
            context,
            success: false,
            message: context.l10n.profileBackupFailed(result.message),
            closeModal: closeModal,
          );
        }
      }
    } catch (e, stackTrace) {
      // The cause goes to the log, never to the user
      // (content-style-guide.md:94).
      AppLogger.error('Backup failed', e, 'BackupRestoreHandler', stackTrace);
      if (context.mounted) {
        _showFailure(
          context,
          what: context.l10n.profileBackupNotSaved,
          preserved: context.l10n.profileBackupRecipesKept,
          closeModal: closeModal,
        );
      }
    }
  }

  /// Handle restore operation.
  static Future<void> handleRestore(
    BuildContext context, {
    bool closeModal = true,
  }) async {
    try {
      final backupService = ServiceLocator.get<BackupService>();
      final result = await backupService.importFromFile();

      if (context.mounted) {
        if (result.success) {
          ResultDisplayer.showResult(
            context,
            success: true,
            message: context.l10n.profileRestoreCompleted,
            closeModal: closeModal,
          );
        } else if (result.cancelled) {
          // User cancelled - no message needed
          return;
        } else if (result.unexpected) {
          _showFailure(
            context,
            what: context.l10n.profileRestoreNotRead,
            preserved: context.l10n.profileRestoreNothingRemoved,
            closeModal: closeModal,
          );
        } else {
          ResultDisplayer.showResult(
            context,
            success: false,
            message: context.l10n.profileRestoreFailed(
              result.errorMessage ?? context.l10n.errorUnexpected,
            ),
            closeModal: closeModal,
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Restore failed', e, 'BackupRestoreHandler', stackTrace);
      if (context.mounted) {
        // A restore only adds recipes, so a failed one removed none.
        _showFailure(
          context,
          what: context.l10n.profileRestoreNotRead,
          preserved: context.l10n.profileRestoreNothingRemoved,
          closeModal: closeModal,
        );
      }
    }
  }

  /// A failure in the three parts of content-style-guide.md:87-97: what
  /// happened, what was kept, and "Stäng" (SnackBarUtils.showFailure).
  /// With [closeModal] the modal closes first and the snackbar shows on the
  /// navigator's own context, which outlives the modal.
  static void _showFailure(
    BuildContext context, {
    required String what,
    required String preserved,
    required bool closeModal,
  }) {
    if (!closeModal) {
      SnackBarUtils.showFailure(context, what: what, preserved: preserved);
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    Future.delayed(_afterDialogWait, () {
      if (!navigator.mounted) return;
      SnackBarUtils.showFailure(
        navigator.context,
        what: what,
        preserved: preserved,
      );
    });
  }
}
