import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/auth/auth_provider_flows.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/session_timeout_service.dart';

/// Where a finished sign-in goes, for e-mail and for Google/Apple alike (C5):
/// [destination] replaces the sign-in screen, so the account meets the
/// verification, terms and onboarding gates on the way in.
void navigateAfterSignIn(
  BuildContext context, {
  required WidgetBuilder destination,
  bool signedInWithBackupCode = false,
}) {
  final navigator = Navigator.of(context);
  navigator.pushReplacement(MaterialPageRoute(builder: destination));
  SessionEndNotice.clear();
  PasswordResetHandoff.clear();
  // After a timeout, the same account lands where it was
  // (TR::FLOW::06::session::utgang; Q-P6-E07).
  final auth = ServiceLocator.get<AuthService>();
  final userId = auth.currentUserId;
  final returnTo = userId == null ? null : SessionReturnPath.takeFor(userId);
  if (returnTo != null) {
    navigator.pushNamed(returnTo.routeName, arguments: returnTo.arguments);
  }
  // A backup code switched the second factor off; say so, and where to
  // switch it on again (P6-U09, TR::FLOW::06::mfa::aterstallning-engangskoder).
  if (signedInWithBackupCode) {
    SnackBarUtils.showInfo(
      context,
      context.l10n.mfaBackupCodeRecovered,
      duration: const Duration(seconds: 10),
      showCloseButton: true,
    );
  }
  // The password sign-in went through but the provider waiting to join the
  // account did not (C4); without a word the user would think it had.
  final unlinked = auth.takeFailedProviderLink();
  if (unlinked != null) {
    SnackBarUtils.showWarning(
      context,
      context.l10n.providerLinkFailed(AuthProviderFlows.providerName(unlinked)),
      duration: const Duration(seconds: 10),
      showCloseButton: true,
    );
  }
}
