import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/utils/auth_error_mapper.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

mixin AuthAccountChanges on ChangeNotifier, StateNotifierMixin {
  @protected
  AuthRepository get accountRepository;

  /// Implemented by AuthService: the second factor waits in
  /// `pendingMfaChallenge`.
  @protected
  void holdMfaChallenge(MfaResolverInfo challenge);

  @protected
  void handleAccountAuthError(FirebaseAuthException e) {
    AppLogger.error('Firebase Auth Error Code: ${e.code}');
    setError(mapAuthErrorToMessage(e));
  }

  /// Re-authenticate user with password (required before sensitive operations).
  Future<bool> reauthenticateWithPassword(String password) async {
    try {
      clearError();
      await accountRepository.reauthenticateWithPassword(password);
      return true;
    } on FirebaseAuthMultiFactorException catch (e) {
      // The password was right; the account's second factor is asked for
      // next, as at sign-in (BUT-916 C7).
      holdMfaChallenge(MfaResolverInfo(resolver: e.resolver));
      return false;
    } on FirebaseAuthException catch (e) {
      handleAccountAuthError(e);
      return false;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      return false;
    }
  }

  /// Change user password. Requires prior reauthentication.
  Future<bool> changePassword(String newPassword) async {
    try {
      clearError();
      await accountRepository.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      handleAccountAuthError(e);
      return false;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      return false;
    }
  }

  /// Send verification to new email address. Requires prior reauthentication.
  Future<bool> changeEmail(String newEmail) async {
    try {
      clearError();
      await accountRepository.verifyBeforeUpdateEmail(newEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      handleAccountAuthError(e);
      return false;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      return false;
    }
  }

  /// Send email verification to the current user.
  Future<void> sendEmailVerification() async {
    try {
      await accountRepository.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      handleAccountAuthError(e);
      rethrow;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      rethrow;
    }
  }
}
