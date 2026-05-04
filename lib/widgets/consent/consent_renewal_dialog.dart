/// Re-consent renewal dialog (BUT-465).
///
/// "Senare" (Later) only dismisses the current invocation — the dialog
/// re-fires next launch until the user actually saves consent inside
/// [ConsentManagementView] (which re-stamps `consentVersion`).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/profile/handlers/gdpr_consent_handler.dart';

class ConsentRenewalDialog extends StatelessWidget {
  const ConsentRenewalDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentRenewalDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      icon: Icon(
        Icons.privacy_tip_rounded,
        color: Theme.of(context).colorScheme.primary,
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
