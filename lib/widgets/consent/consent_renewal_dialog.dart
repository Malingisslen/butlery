/// Re-consent renewal dialog (BUT-465).
///
/// With a loaded consent it follows Skarmar v12 etapp 6 #samtyckefornya:
/// what changed since the version the user accepted, one line per new or
/// changed purpose, her earlier choices kept, and three answers — Jag
/// godkänner · Låt mig välja själv · Inte nu. "Inte nu" keeps the old
/// consent and switches nothing off; the dialog comes
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
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/profile/handlers/gdpr_consent_handler.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

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
    return showButleryDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConsentRenewalDialog(viewModel: viewModel),
    );
  }

  /// The change's own sentence pair, or null when none is written yet.
  /// A version bump adds its own lines here and in the l10n files
  /// (Q-P6-A18). "Gränssnittet får inte påstå att något viktigt hänt utan
  /// att säga vad", so a test requires a pair for
  /// every entry in ConsentService.changelog.
  static (String, String)? ownChangeLines(
    AppLocalizations l10n,
    ConsentChange change,
  ) {
    return switch ((change.purpose, change.kind)) {
      (ConsentPurpose.aiProcessing, ConsentChangeKind.added) => (
        l10n.consentChangeAiProcessingAddedTitle,
        l10n.consentChangeAiProcessingAddedBody,
      ),
      _ => null,
    };
  }

  /// The sentence pair for one change. The general pair is only a last
  /// resort for a release that skipped the test above.
  static (String, String) changeLines(
    AppLocalizations l10n,
    ConsentChange change,
  ) {
    return ownChangeLines(l10n, change) ??
        (l10n.consentRenewalTitle, l10n.consentRenewalDescription);
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

    return ButleryDialog(
      key: const ValueKey('consentRenewal.changes'),
      title: l10n.consentRenewalChangedTitle(changes.length),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.consentRenewalSinceVersion(consent.consentVersion, date)),
          const SizedBox(height: AppDimensions.space16),
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
                    const SizedBox(height: AppDimensions.space4),
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
            const SizedBox(height: AppDimensions.space8),
          ],
          Text(l10n.consentRenewalUnchanged(unchanged)),
          const SizedBox(height: AppDimensions.space16),
          Text(
            l10n.consentRenewalNotNowNote,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          if (_failed) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              l10n.consentRenewalSaveFailed,
              style: AppTextStyles.bodySmall.copyWith(color: cs.error),
            ),
          ],
        ],
      ),
      actions: [
        ButleryTextButton(
          key: const ValueKey('consentRenewal.notNow'),
          label: l10n.consentRenewalNotNow,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        ButleryTextButton(
          key: const ValueKey('consentRenewal.chooseMyself'),
          label: l10n.consentRenewalChooseMyself,
          onPressed: _saving
              ? null
              : () => GdprConsentHandler.handleManageConsent(context),
        ),
        // A dialog's primary is ink: saffron is the one hero of a view, and
        // the dialog sits above it. Busy keeps the name and draws the plate
        // line.
        KeyedSubtree(
          key: const ValueKey('consentRenewal.accept'),
          child: ButleryDialogPrimary(
            label: l10n.consentRenewalAccept,
            busy: _saving,
            onPressed: () => _accept(vm),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneral(BuildContext context) {
    final l10n = context.l10n;
    return ButleryDialog(
      titleIcon: ButleryIcons.shield,
      title: l10n.consentRenewalTitle,
      message: l10n.consentRenewalDescription,
      actions: [
        ButleryTextButton(
          label: l10n.consentRenewalLater,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ButleryDialogPrimary(
          label: l10n.consentRenewalReview,
          // Handler pops the dialog itself, then pushes ConsentManagementView.
          onPressed: () => GdprConsentHandler.handleManageConsent(context),
        ),
      ],
    );
  }
}
