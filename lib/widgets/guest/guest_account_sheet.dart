import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/guest/guest_upgrade_launcher.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

enum GuestAccountReason { share, together, importLimit }

/// "Skapa konto för att …": what a guest meets instead of a feature that
/// needs an account.
Future<void> showGuestAccountSheet(
  BuildContext context,
  GuestAccountReason reason, {
  GuestUpgradeLauncher launcher = const GuestUpgradeLauncher(),
}) {
  return showButlerySheet<void>(
    context: context,
    builder: (sheetContext) => _GuestAccountSheet(
      reason: reason,
      onCreateAccount: () {
        Navigator.of(sheetContext).pop();
        launcher.launch(context);
      },
    ),
  );
}

class _GuestAccountSheet extends StatelessWidget {
  const _GuestAccountSheet({
    required this.reason,
    required this.onCreateAccount,
  });

  final GuestAccountReason reason;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final (title, body) = switch (reason) {
      GuestAccountReason.share => (
        l10n.guestSheetShareTitle,
        l10n.guestSheetShareBody,
      ),
      GuestAccountReason.together => (
        l10n.guestSheetTogetherTitle,
        l10n.guestSheetTogetherBody,
      ),
      GuestAccountReason.importLimit => (
        l10n.guestSheetImportLimitTitle,
        l10n.guestSheetImportLimitBody,
      ),
    };
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppDimensions.layoutMarginOf(context),
        0,
        AppDimensions.layoutMarginOf(context),
        AppDimensions.layoutMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.subpageTitle),
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          ActionButtons.primaryButton(
            context,
            label: l10n.guestCreateAccount,
            onPressed: onCreateAccount,
            isExpanded: true,
          ),
          const SizedBox(height: AppDimensions.space4),
          ButleryTextButton(
            label: l10n.guestNotNow,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
