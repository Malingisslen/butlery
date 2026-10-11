import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/guest/guest_upgrade_launcher.dart';

enum GuestAccountReason { share, together, importLimit }

/// "Skapa konto för att …": what a guest meets instead of a feature that
/// needs an account.
Future<void> showGuestAccountSheet(
  BuildContext context,
  GuestAccountReason reason, {
  GuestUpgradeLauncher launcher = const GuestUpgradeLauncher(),
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: cs.surface,
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
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          FilledButton(
            onPressed: onCreateAccount,
            child: Text(l10n.guestCreateAccount),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.guestNotNow),
          ),
        ],
      ),
    );
  }
}
