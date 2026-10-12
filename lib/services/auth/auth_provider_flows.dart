import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/utils/auth_error_mapper.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth/provider_sign_in_service.dart';

/// AuthService's Google and Apple surface (BUT-916, BUT-549), kept in its
/// own file so AuthService delegates instead of growing. The provider work
/// itself is [ProviderSignInService]; this maps it onto AuthService's state
/// and its signed-in sequence, and returns domain outcomes only.
mixin AuthProviderFlows on ChangeNotifier, StateNotifierMixin {
  /// Null where no provider is wired (tests that do not need one).
  @protected
  ProviderSignInService? get providerSignIn;

  /// The same sequence a password sign-in ends with (C5).
  @protected
  Future<void> completeSignIn({required String method, bool isNewUser});

  /// Waits for the second factor, as a password sign-in does.
  @protected
  void holdMfaChallenge(MfaResolverInfo challenge);

  void clearPendingMfa();

  bool get isAuthenticated;

  bool isProviderOffered(SignInProvider provider) =>
      providerSignIn?.isOffered(provider) ?? false;

  /// The password account a provider sign-in found, while "Koppla ihop"
  /// asks for its password.
  PendingProviderLink? get pendingProviderLink => providerSignIn?.pendingLink;

  /// The name the terms step is prefilled with; the user can change it.
  String? get providerFirstName => providerSignIn?.firstName;

  /// False when the terms step is met again after a restart (C3).
  bool get providerAccountCreatedHere =>
      providerSignIn?.accountCreatedHere ?? false;

  /// The provider a finished sign-in could not link, once; the screen the
  /// sign-in lands on says so.
  SignInProvider? takeFailedProviderLink() => providerSignIn?.takeFailedLink();

  void cancelPendingProviderLink() {
    providerSignIn?.clearPendingLink();
    notifyListeners();
  }

  /// "Fortsätt med Google / Apple". Mirrors `signInWithEmail`: a second
  /// factor is caught first and waits in `pendingMfaChallenge`, closing the
  /// sheet is silent, and a success runs the signed-in sequence.
  Future<ProviderSignInOutcome> signInWithProvider(
    SignInProvider provider,
  ) async {
    final service = providerSignIn;
    if (service == null) return ProviderSignInOutcome.failed;
    clearError();
    clearPendingMfa();
    setLoading(true);
    final attempt = await service.signIn(provider);
    setLoading(false);
    switch (attempt.outcome) {
      case ProviderSignInOutcome.signedIn:
        try {
          await completeSignIn(
            method: provider.analyticsMethod,
            isNewUser: attempt.isNewUser,
          );
        } catch (e) {
          AppLogger.error(
            'Sign-in sequence after ${provider.providerId} failed: '
            '${e.runtimeType}',
          );
          setError(AppLocale.current.errorUnexpected);
          return isAuthenticated
              ? ProviderSignInOutcome.signedIn
              : ProviderSignInOutcome.failed;
        }
      case ProviderSignInOutcome.mfaRequired:
        holdMfaChallenge(attempt.mfa!);
      case ProviderSignInOutcome.linkNeedsPassword:
        notifyListeners();
      case ProviderSignInOutcome.cancelled:
        break;
      case ProviderSignInOutcome.failed:
        reportProviderFailure(attempt, provider);
    }
    return attempt.outcome;
  }

  @protected
  void reportProviderFailure(ProviderAttempt attempt, SignInProvider provider) {
    final error = attempt.error;
    final l10n = AppLocale.current;
    final name = providerName(provider);
    setError(switch (error?.code) {
      null => l10n.authProviderFailed(name),
      'account-exists-with-different-credential' =>
        l10n.authProviderAccountExists,
      'user-mismatch' => l10n.authProviderWrongAccount(name),
      'operation-not-allowed' ||
      'internal-error' ||
      'unknown' => l10n.authProviderFailed(name),
      _ => mapAuthErrorToMessage(error!),
    });
  }

  static String providerName(SignInProvider provider) => switch (provider) {
    SignInProvider.google => 'Google',
    SignInProvider.apple => 'Apple',
  };

  /// Whether a backup code can be proved through [provider] on this device;
  /// where it cannot, the challenge shows the support route instead.
  bool canRecoverThroughProvider(SignInProvider provider) =>
      providerSignIn?.canProveForRecovery(provider) ?? false;

  Future<MfaProviderProof?> providerRecoveryProof(SignInProvider provider) =>
      providerSignIn?.recoveryProof(provider) ?? Future.value();

  /// Whether the account can sign in with a password. Without one there is
  /// no password to change, and re-authentication goes through a provider.
  bool get hasPasswordSignIn => providerSignIn?.hasPasswordSignIn ?? true;

  /// The one re-authentication decision (C7): null means the password
  /// dialog, a provider means that provider's sheet.
  SignInProvider? reauthenticationProvider({bool forDeletion = false}) =>
      providerSignIn?.reauthenticationProvider(forDeletion: forDeletion);

  /// Re-authenticates through [provider]. A second factor on the account
  /// waits in `pendingMfaChallenge` like a sign-in's.
  Future<ProviderSignInOutcome> reauthenticateWithProvider(
    SignInProvider provider,
  ) async {
    final service = providerSignIn;
    if (service == null) return ProviderSignInOutcome.failed;
    clearError();
    final attempt = await service.reauthenticate(provider);
    switch (attempt.outcome) {
      case ProviderSignInOutcome.mfaRequired:
        holdMfaChallenge(attempt.mfa!);
      case ProviderSignInOutcome.failed:
        reportProviderFailure(attempt, provider);
      default:
        break;
    }
    return attempt.outcome;
  }

  /// The sign-in methods page (BUT-916 slice B): what the account signs in
  /// with, and what may be added or removed.
  bool isProviderLinked(SignInProvider provider) =>
      providerSignIn?.isLinked(provider) ?? false;

  String? providerAccountEmail(SignInProvider provider) =>
      providerSignIn?.providerEmail(provider);

  /// False when only one sign-in method is left, which stays.
  bool get canUnlinkSignInMethod => providerSignIn?.canUnlinkAny ?? false;

  bool get revokesAppleOnUnlink => providerSignIn?.revokesApple ?? false;

  /// Adds [provider] to the signed-in account. False with the reason in
  /// `error`, or with none when the user closed the sheet.
  Future<bool> linkProvider(SignInProvider provider) async {
    final service = providerSignIn;
    if (service == null) return false;
    clearError();
    final attempt = await service.linkProvider(provider);
    switch (attempt.outcome) {
      case ProviderSignInOutcome.signedIn:
        notifyListeners();
        return true;
      case ProviderSignInOutcome.cancelled:
        return false;
      default:
        final l10n = AppLocale.current;
        final name = providerName(provider);
        setError(switch (attempt.error?.code) {
          'credential-already-in-use' ||
          'email-already-in-use' => l10n.signInMethodsAlreadyUsed(name),
          'provider-already-linked' => l10n.signInMethodsAlreadyLinked(name),
          _ => l10n.signInMethodsLinkFailed(name),
        });
        return false;
    }
  }

  /// Links [provider] to the signed-in guest. The attempt itself comes back,
  /// so the caller can tell a closed sheet from "already has an account".
  Future<ProviderAttempt> linkProviderToGuest(SignInProvider provider) async {
    final service = providerSignIn;
    if (service == null) return const ProviderAttempt.failed();
    return service.linkProvider(provider);
  }

  /// The first name a freshly linked [provider] gives the account, if it has
  /// one: the same minimisation as the terms step, which also starts from the
  /// first name only, since this name is shown to other people.
  String? linkedProviderName(SignInProvider provider) {
    final held = providerSignIn?.providerDisplayName(provider).orEmptyTrimmed();
    final first = held?.split(RegExp(r'\s+')).first;
    return first == null || first.isEmpty ? providerFirstName : first;
  }

  /// Removes [provider] from the account. Apple's tokens are revoked first
  /// where the sheet gave a code; a failed revocation never keeps the method.
  Future<bool> unlinkProvider(SignInProvider provider) async {
    final service = providerSignIn;
    if (service == null) return false;
    clearError();
    final name = providerName(provider);
    try {
      await service.unlinkProvider(provider);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Unlinking ${provider.providerId} refused: ${e.code}');
    } catch (e) {
      AppLogger.warning(
        'Unlinking ${provider.providerId} failed: ${e.runtimeType}',
      );
    }
    setError(AppLocale.current.signInMethodsUnlinkFailed(name));
    return false;
  }

  /// Adds a password to an account made with Google or Apple. The caller
  /// re-authenticates first.
  Future<bool> addPasswordSignIn(String password) async {
    final service = providerSignIn;
    if (service == null) return false;
    clearError();
    try {
      await service.addPassword(password);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Adding a password refused: ${e.code}');
      setError(mapAuthErrorToMessage(e));
    } catch (e) {
      AppLogger.warning('Adding a password failed: ${e.runtimeType}');
      setError(AppLocale.current.signInMethodsPasswordFailed);
    }
    return false;
  }

  /// Before a deletion is scheduled: revoke the app's Apple tokens where the
  /// re-authentication gave a code. Never throws, never blocks the deletion.
  Future<void> revokeAppleSignIn() async {
    try {
      await providerSignIn?.revokeAppleIfLinked();
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('Apple revocation failed: ${e.code}');
    } catch (e) {
      AppLogger.warning('Apple revocation failed: ${e.runtimeType}');
    }
  }
}
