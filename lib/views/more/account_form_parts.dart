// lib/views/more/account_form_parts.dart
//
// What the E-postadress and Lösenord pages under Konto & säkerhet are built
// from, so both forms draw the same button.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/account_security_viewmodel.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// The form's one primary button, last on the page. While the view model
/// works it keeps its name and gets the plate line along its bottom edge,
/// never a spinner (Komponentark v1:365, :372); busy is not disabled, it
/// ignores presses instead (PlateLineButton.ignore).
class AccountFormButton extends StatelessWidget {
  const AccountFormButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;

  /// Null turns the button off.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingL),
      child: BusyButtonSemantics(
        busy: busy,
        name: label,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? PlateLineButton.ignore : onPressed,
            style: busy
                ? PlateLineButton.busyStyle(
                    null,
                    Theme.of(context).filledButtonTheme.style,
                  )
                : null,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// After a right current password, an account with two-step verification
/// gives its code before the change goes on (BUT-916 C7). True when given.
Future<bool> confirmSecondFactor(
  BuildContext context,
  AccountSecurityViewModel viewModel,
) async {
  final challenge = viewModel.pendingSecondFactor;
  if (challenge == null) return false;
  final result = await Navigator.of(context).push<MfaChallengeResult>(
    MaterialPageRoute(
      builder: (_) =>
          MfaChallengeView(challenge: challenge, forReauthentication: true),
    ),
  );
  return result != null;
}

/// A failed change is the failure snackbar, never OK. A failure without a known cause offers Försök igen, which runs
/// the change again with the fields as they are; a named cause or a form
/// error gets Stäng (AccountSecurityViewModel.canRetry).
void showAccountChangeFailure(
  BuildContext context,
  AccountSecurityViewModel viewModel, {
  required Future<void> Function() onRetry,
}) {
  SnackBarUtils.showFailure(
    context,
    what: viewModel.error!,
    action: viewModel.canRetry ? FailureAction.retry(onRetry) : null,
  );
}
