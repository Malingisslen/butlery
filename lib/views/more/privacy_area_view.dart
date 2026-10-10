// lib/views/more/privacy_area_view.dart
//
// Integritet & data under Mer: what the user has agreed to, what they can
// take with them, and the policy (Mer, omtänkt, 2026-10-10). The backup
// download and restore share one row and open as a sheet.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/common/profile/handlers/backup_restore_handler.dart';
import 'package:butlery/widgets/common/profile/handlers/gdpr_consent_handler.dart';

class PrivacyAreaView extends StatelessWidget {
  const PrivacyAreaView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A plain page, not a modal: nothing must close before the handler runs.
    return MoreAreaScaffold(
      title: l10n.settingsPrivacyAreaTitle,
      sections: [
        ButleryListSection(
          title: l10n.settingsYourChoicesSection,
          rows: [
            ButleryListRow(
              label: l10n.settingsConsents,
              onTap: () => GdprConsentHandler.handleManageConsent(
                context,
                closeModal: false,
              ),
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.settingsYourDataSection,
          rows: [
            ButleryListRow(
              label: l10n.profileExportData,
              subtitle: l10n.profileExportDataSubtitle,
              onTap: () => GdprConsentHandler.handleExportData(
                context,
                closeModal: false,
              ),
            ),
            ButleryListRow(
              label: l10n.settingsBackupTitle,
              subtitle: l10n.settingsBackupSubtitle,
              onTap: () => _openBackupSheet(context),
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.settingsDocumentsSection,
          rows: [
            ButleryListRow(
              label: l10n.profilePrivacyPolicy,
              onTap: () => GdprConsentHandler.handlePrivacyPolicy(
                context,
                closeModal: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The sheet closes first, then the handler runs on this page's context,
  /// so its progress and result show on the page.
  Future<void> _openBackupSheet(BuildContext context) async {
    final l10n = context.l10n;
    final choice = await showButleryListSheet<_BackupChoice>(
      context,
      title: l10n.settingsBackupTitle,
      rows: (sheetContext) => [
        ButleryListRow(
          label: l10n.profileDownloadBackup,
          leading: ButleryIcons.download,
          onTap: () => Navigator.of(sheetContext).pop(_BackupChoice.download),
        ),
        ButleryListRow(
          label: l10n.profileRestoreFromBackup,
          leading: ButleryIcons.upload,
          onTap: () => Navigator.of(sheetContext).pop(_BackupChoice.restore),
        ),
      ],
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _BackupChoice.download:
        await BackupRestoreHandler.handleBackup(context, closeModal: false);
      case _BackupChoice.restore:
        await BackupRestoreHandler.handleRestore(context, closeModal: false);
    }
  }
}

enum _BackupChoice { download, restore }
