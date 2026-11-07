import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth/auth_provider_flows.dart';
import 'package:butlery/services/auth/session_revocation_service.dart';
import 'package:butlery/services/auth/sessions_revoked_notice.dart';
import 'package:butlery/utils/shared_preferences_safe.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';

/// "Logga ut från alla enheter" (BUT-2481): confirm, sign in again with the
/// provider, ask the server, then this device keeps its own session.
class SessionRevocationHandler {
  const SessionRevocationHandler._();

  /// The row is for people who sign in with Google or Apple, and not for a
  /// guest. Apple wins when both are linked.
  static SignInProvider? providerFor(AuthService? auth) {
    if (auth == null || auth.currentUser?.isAnonymous == true) return null;
    for (final provider in [SignInProvider.apple, SignInProvider.google]) {
      if (auth.isProviderLinked(provider)) return provider;
    }
    return null;
  }

  static Future<void> handle(BuildContext context) async {
    final auth = ServiceLocator.get<AuthService>();
    final provider = providerFor(auth);
    if (provider == null) return;
    // The page may be gone when the answer comes (a failed swap signs this
    // device out), so the snackbars are captured first.
    final snacks = CapturedSnackBars.capture(context);
    final l10n = context.l10n;
    final providerName = AuthProviderFlows.providerName(provider);

    final confirmed = await _ask(
      context,
      title: l10n.signOutEverywhereDialogTitle,
      body: l10n.signOutEverywhereDialogBody,
      action: l10n.signOutEverywhereConfirm,
    );
    if (!confirmed || !context.mounted) return;

    final proceed = await _ask(
      context,
      title: l10n.signOutEverywhereReauthTitle,
      body: l10n.signOutEverywhereReauthBody(providerName),
      action: l10n.signOutEverywhereReauthAction(providerName),
    );
    if (!proceed || !context.mounted) return;

    // Always through the provider: the server wants a token that itself came
    // from Google or Apple, and the second factor if the account has one.
    final signedIn = await AuthActionHandler.reauthenticate(
      context,
      through: provider,
      onError: (message) {
        if (context.mounted) {
          SnackBarUtils.showFailure(context, what: message);
        }
      },
    );
    if (!signedIn || !context.mounted) return;

    final outcome = await ServiceLocator.get<SessionRevocationService>()
        .revokeOtherSessions();
    if (outcome == SessionRevocationOutcome.revoked) {
      final prefs = await tryGetSharedPreferences(logTag: 'SessionsRevoked');
      if (prefs != null) {
        await SessionsRevokedNotice(prefs: prefs).markPressedHere();
      }
    }
    switch (outcome) {
      case SessionRevocationOutcome.revoked:
        snacks.showConfirmation(l10n.signOutEverywhereDone);
      case SessionRevocationOutcome.reauthRequired:
        snacks.showFailure(what: l10n.signOutEverywhereReauthNeeded);
      case SessionRevocationOutcome.rateLimited:
        snacks.showFailure(what: l10n.signOutEverywhereRateLimited);
      case SessionRevocationOutcome.signedOutAfterFailure:
        snacks.showFailure(what: l10n.signOutEverywhereSignedOut);
      case SessionRevocationOutcome.failed:
        snacks.showFailure(what: l10n.signOutEverywhereFailed);
      case SessionRevocationOutcome.busy:
        break;
    }
  }

  static Future<bool> _ask(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          DialogCancelButton(
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          // Not error red: nothing is deleted, other devices just sign in again.
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
