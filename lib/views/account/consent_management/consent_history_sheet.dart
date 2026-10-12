import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

/// What the user said yes and no to, and when: one line per saved version.
Future<void> showConsentHistorySheet(
  BuildContext context,
  ConsentViewModel viewModel,
) async {
  final history = await viewModel.getConsentHistory();
  if (!context.mounted) return;
  final l10n = context.l10n;
  return showButleryListSheet<void>(
    context,
    title: l10n.consentHistory,
    rows: (sheetContext) {
      final muted = Theme.of(sheetContext).colorScheme.onSurfaceVariant;
      if (history.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
            child: Text(
              l10n.consentHistoryEmpty,
              style: AppTextStyles.captionBase.copyWith(color: muted),
            ),
          ),
        ];
      }
      return [
        for (final entry in history)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMMd(l10n.localeName).format(
                    (entry.updatedAt ?? entry.grantedAt).toLocal(),
                  ),
                  style: AppTextStyles.bodyBold,
                ),
                Text(
                  _summary(l10n, entry),
                  style: AppTextStyles.captionBase.copyWith(color: muted),
                ),
              ],
            ),
          ),
      ];
    },
  );
}

String _summary(AppLocalizations l10n, UserConsent entry) {
  final p = entry.purposes;
  final on = <String>[
    if (p.analytics) l10n.consentAnalytics,
    if (p.marketing) l10n.consentMarketing,
    if (p.socialFeatures) l10n.consentSocial,
    if (p.pushNotifications) l10n.consentPushNotifications,
    if (p.aiProcessing) l10n.consentAiProcessing,
  ];
  return '${entry.consentVersion} · ${on.isEmpty ? l10n.consentHistoryNoneOn : on.join(', ')}';
}
