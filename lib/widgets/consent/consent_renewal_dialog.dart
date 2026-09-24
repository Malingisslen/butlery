/// Re-consent renewal dialog (BUT-465).
///
/// With a loaded consent it follows Skarmar v12 etapp 6 #samtyckefornya:
/// what changed since the version the user accepted, one line per new or
/// changed purpose, her earlier choices kept, and three answers — Jag
/// godkänner · Låt mig välja själv · Inte nu. "Inte nu" keeps the old
/// consent and switches nothing off (produktregler.md:731); the dialog comes
/// back at the next launch until a new version is saved.
///
/// Without a loaded consent (no consent document, or it could not be read)
/// there is no earlier version to compare with, so it falls back to the
/// general question with "Granska samtycken" and "Senare".
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/widgets/common/profile/handlers/gdpr_consent_handler.dart';

class ConsentRenewalDialog extends StatefulWidget {
  const ConsentRenewalDialog({super.key, this.viewModel});

  /// A view model whose consent is loaded. Null shows the general question.
  final ConsentViewModel? viewModel;

  /// The number of consent purposes the model has (user_consent.dart).
  static const int purposeCount = 7;

  static Future<void> show(
    BuildContext context, {
    ConsentViewModel? viewModel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConsentRenewalDialog(viewModel: viewModel),
    );
  }

  /// The sentence pair for one change. A version bump adds its own lines
  /// here and in the l10n files (Q-P6-A18).
  static (String, String) changeLines(
    AppLocalizations l10n,
    ConsentChange change,
  ) {
    return switch ((change.purpose, change.kind)) {
      (ConsentPurpose.aiProcessing, ConsentChangeKind.added) => (
        l10n.consentChangeAiProcessingAddedTitle,
        l10n.consentChangeAiProcessingAddedBody,
      ),
      _ => (l10n.consentRenewalTitle, l10n.consentRenewalDescription),
    };
  }

  @override
  State<ConsentRenewalDialog> createState() => _ConsentRenewalDialogState();
}

class _ConsentRenewalDialogState extends State<ConsentRenewalDialog> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _accept(ConsentViewModel vm) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final ok = await vm.acceptRenewal();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = widget.viewModel;
    final consent = vm?.currentConsent;
    final changes = vm?.renewalChanges ?? const <ConsentChange>[];

    if (vm == null || consent == null || changes.isEmpty) {
      return _buildGeneral(context);
    }

    final cs = Theme.of(context).colorScheme;
    final acceptedAt = consent.updatedAt ?? consent.grantedAt;
    final date = DateFormat.MMMMd(
      Localizations.localeOf(context).languageCode,
    ).format(acceptedAt);
    final unchanged = ConsentRenewalDialog.purposeCount - changes.length;

    return AlertDialog(
      key: const ValueKey('consentRenewal.changes'),
      scrollable: true,
      title: Text(l10n.consentRenewalChangedTitle(changes.length)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.consentRenewalSinceVersion(consent.consentVersion, date)),
          const SizedBox(height: AppDimensions.spacingMd),
          for (final change in changes) ...[
            Builder(
              builder: (context) {
                final (title, body) = ConsentRenewalDialog.changeLines(
                  l10n,
                  change,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyBold),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      body,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingSm),
          ],
          Text(l10n.consentRenewalUnchanged(unchanged)),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            l10n.consentRenewalNotNowNote,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          if (_failed) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              l10n.consentRenewalSaveFailed,
              style: AppTextStyles.bodySmall.copyWith(color: cs.error),
            ),
          ],
        ],
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          key: const ValueKey('consentRenewal.notNow'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.consentRenewalNotNow),
        ),
        TextButton(
          key: const ValueKey('consentRenewal.chooseMyself'),
          onPressed: _saving
              ? null
              : () => GdprConsentHandler.handleManageConsent(context),
          child: Text(l10n.consentRenewalChooseMyself),
        ),
        FilledButton(
          key: const ValueKey('consentRenewal.accept'),
          onPressed: _saving ? null : () => _accept(vm),
          child: Text(l10n.consentRenewalAccept),
        ),
      ],
    );
  }

  Widget _buildGeneral(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      icon: Icon(
        Icons.privacy_tip_rounded,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(l10n.consentRenewalTitle),
      content: Text(l10n.consentRenewalDescription),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.consentRenewalLater),
        ),
        FilledButton(
          // Handler pops the dialog itself, then pushes ConsentManagementView.
          onPressed: () => GdprConsentHandler.handleManageConsent(context),
          child: Text(l10n.consentRenewalReview),
        ),
      ],
    );
  }
}
