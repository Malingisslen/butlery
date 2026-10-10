import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/auth_error_mapper.dart';
import 'package:butlery/models/auth/mfa_types.dart';

/// The authenticator-app calls firebase_auth offers only as statics and on
/// a class with a private constructor, behind one seam so tests can stand
/// in for Firebase.
class MfaTotpGateway {
  const MfaTotpGateway();

  Future<TotpSecret> generateSecret(MultiFactorSession session) =>
      TotpMultiFactorGenerator.generateSecret(session);

  Future<String> qrCodeUrl(TotpSecret secret, {required String accountName}) =>
      secret.generateQrCodeUrl(accountName: accountName, issuer: 'Butlery');

  Future<void> openInOtpApp(TotpSecret secret, String url) =>
      secret.openInOtpApp(url);

  Future<MultiFactorAssertion> enrollmentAssertion(
    TotpSecret secret,
    String code,
  ) => TotpMultiFactorGenerator.getAssertionForEnrollment(secret, code);

  Future<MultiFactorAssertion> signInAssertion(
    String enrollmentId,
    String code,
  ) => TotpMultiFactorGenerator.getAssertionForSignIn(enrollmentId, code);
}

/// Multi-factor authentication service extracted from AuthService.
///
/// The second factor is an authenticator app (TOTP); Malin chose it over
/// SMS on 2026-10-10.
class AuthMfaService extends ChangeNotifier
    with StateNotifierMixin, ErrorHandlingMixin {
  final AnalyticsService _analyticsService;
  final AuthRepository _authRepository;
  final FirebaseFunctions? _functions;
  final MfaTotpGateway _totp;

  String? get errorMessage => error;

  /// [functions] reaches the backup-code callables
  /// (functions/src/account/mfa-backup-codes.ts). Without it, backup codes
  /// cannot be created or used, and enrollment must not be offered.
  AuthMfaService({
    required AnalyticsService analyticsService,
    required AuthRepository authRepository,
    FirebaseFunctions? functions,
    MfaTotpGateway totp = const MfaTotpGateway(),
  }) : _analyticsService = analyticsService,
       _authRepository = authRepository,
       _functions = functions,
       _totp = totp;

  /// Creates ten one-time backup codes and returns them, once. The server
  /// keeps only salted hashes. Null when they could not be made; enrollment
  /// must then stop, because the protection may not apply without a way back
  /// (produktregler.md:749). The codes are never logged.
  Future<List<String>?> generateBackupCodes() async {
    final functions = _functions;
    if (functions == null) return null;
    try {
      final result = await functions
          .httpsCallable('generateMfaBackupCodes')
          .call<Map<dynamic, dynamic>>();
      final codes = (result.data['codes'] as List?)?.whereType<String>();
      if (codes == null || codes.length != mfaBackupCodeCount) return null;
      return codes.toList();
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('Backup codes could not be created: ${e.code}');
      final details = e.details;
      if (details is Map && details['code'] == 'requires-recent-login') {
        setError(AppLocale.current.errorReauthRequired);
      } else {
        setError(AppLocale.current.mfaBackupCodesFailed);
      }
      return null;
    } catch (e) {
      AppLogger.error('Backup codes could not be created: ${e.runtimeType}');
      setError(AppLocale.current.mfaBackupCodesFailed);
      return null;
    }
  }

  /// The way in without the authenticator app: the server proves the
  /// password, spends the code, and removes the second factor. Neither the
  /// password nor the code is logged. The caller signs in again with the
  /// password afterwards.
  Future<MfaRecoveryOutcome> recoverWithBackupCode({
    required String email,
    required String password,
    required String code,
  }) async {
    final functions = _functions;
    if (functions == null) return MfaRecoveryOutcome.unavailable;
    try {
      // The server spends the App Check token (consumeAppCheckToken), so ask
      // for a limited-use one: a replayed request is refused.
      await functions
          .httpsCallable(
            'recoverWithMfaBackupCode',
            options: HttpsCallableOptions(limitedUseAppCheckToken: true),
          )
          .call<dynamic>({
            'email': email,
            'password': password,
            'code': code,
          });
      await _analyticsService.logEvent(name: AnalyticsEvents.mfaUnenrolled);
      return MfaRecoveryOutcome.recovered;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.warning('MFA recovery refused: ${e.code}');
      // No "not needed" outcome: the server answers an account without a
      // second factor exactly like a wrong password, so the endpoint cannot
      // confirm a password. Recovery is only offered after Firebase demanded
      // a second factor, so an honest caller never lands there.
      return switch (e.code) {
        'permission-denied' => MfaRecoveryOutcome.rejected,
        'resource-exhausted' => MfaRecoveryOutcome.locked,
        _ => MfaRecoveryOutcome.unavailable,
      };
    } catch (e) {
      AppLogger.warning('MFA recovery failed: ${e.runtimeType}');
      return MfaRecoveryOutcome.unavailable;
    }
  }

  Future<bool> hasMfaEnabled() async {
    final user = _authRepository.currentUser;
    if (user == null) return false;

    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      return factors.isNotEmpty;
    } catch (e) {
      AppLogger.warning('Failed to check MFA status: $e');
      return false;
    }
  }

  Future<List<MfaFactorInfo>> getEnrolledFactors() async {
    final user = _authRepository.currentUser;
    if (user == null) return [];

    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      return factors
          .map(
            (f) => MfaFactorInfo(
              factor: f,
              displayName: f.displayName,
              enrollmentTimestamp: f.enrollmentTimestamp,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.warning('Failed to get MFA factors: $e');
      return [];
    }
  }

  /// Makes the shared key for a new authenticator-app factor. Null when
  /// it could not be made; [errorMessage] then says why. Call only after the
  /// backup codes exist, and discard them when this returns null.
  Future<MfaTotpSetup?> startMfaEnrollment() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      setError(AppLocale.current.mfaSetupFailed);
      return null;
    }
    try {
      final session = await user.multiFactor.getSession();
      final secret = await _totp.generateSecret(session);
      final url = await _totp.qrCodeUrl(
        secret,
        accountName: user.email ?? 'Butlery',
      );
      return MfaTotpSetup(
        secret: secret,
        secretKey: secret.secretKey,
        otpauthUrl: url,
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA setup failed: ${e.code}');
      setError(_enrollmentErrorMessage(e));
      return null;
    } catch (e) {
      AppLogger.error('MFA setup failed: ${e.runtimeType}');
      setError(AppLocale.current.mfaSetupFailed);
      return null;
    }
  }

  /// Hands the key to an authenticator app on the phone. False when no app
  /// took it (and always on the web, which has no such hand-over); the user
  /// can still type the key in by hand.
  Future<bool> openInAuthenticatorApp(MfaTotpSetup setup) async {
    if (kIsWeb) return false;
    try {
      await _totp.openInOtpApp(
        setup.unwrap<TotpSecret>(),
        setup.otpauthUrl,
      );
      return true;
    } catch (e) {
      AppLogger.warning('No authenticator app opened: ${e.runtimeType}');
      return false;
    }
  }

  /// Enrolls the factor with the six-digit [code] the app shows.
  Future<bool> completeMfaEnrollment(MfaTotpSetup setup, String code) async {
    final user = _authRepository.currentUser;
    if (user == null) return false;

    try {
      final assertion = await _totp.enrollmentAssertion(
        setup.unwrap<TotpSecret>(),
        code,
      );
      await user.multiFactor.enroll(assertion);

      AppLogger.info('MFA enrollment completed successfully');
      await _analyticsService.logEvent(
        name: AnalyticsEvents.mfaEnrolled,
        parameters: {'method': 'totp'},
      );
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA enrollment failed: ${e.code}');
      setError(_enrollmentErrorMessage(e));
      return false;
    } catch (e) {
      AppLogger.error('MFA enrollment error: ${e.runtimeType}');
      setError(AppLocale.current.errorCouldNotCompleteMfa);
      return false;
    }
  }

  String _enrollmentErrorMessage(FirebaseAuthException e) {
    final l10n = AppLocale.current;
    return switch (e.code) {
      'invalid-verification-code' => l10n.mfaInvalidCode,
      'unverified-email' => l10n.mfaErrorUnverifiedEmail,
      'requires-recent-login' => l10n.mfaErrorRequiresRecentLogin,
      _ => mapAuthErrorToMessage(e),
    };
  }

  Future<bool> unenrollMfa(MfaFactorInfo factor) async {
    final user = _authRepository.currentUser;
    if (user == null) return false;

    try {
      final firebaseFactor = factor.unwrap<MultiFactorInfo>();
      await user.multiFactor.unenroll(multiFactorInfo: firebaseFactor);
      AppLogger.info(
        'MFA factor unenrolled: ${firebaseFactor.uid.maskedUserId}',
      );
      await _clearBackupCodes();
      await _analyticsService.logEvent(name: AnalyticsEvents.mfaUnenrolled);
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA unenroll failed: ${e.code}');
      _handleMfaAuthError(e);
      return false;
    } catch (e) {
      AppLogger.error('MFA unenroll error: $e');
      setError(AppLocale.current.errorCouldNotRemoveMfa);
      return false;
    }
  }

  /// Asks the server to delete the backup codes now that two-step
  /// verification is off, so an old set cannot become valid again with a
  /// later enrollment. The server checks that no factor is left and refuses
  /// otherwise. Best effort: the unenrollment itself already succeeded, and
  /// a new enrollment replaces the set anyway.
  Future<void> _clearBackupCodes() async {
    final functions = _functions;
    if (functions == null) return;
    try {
      await functions.httpsCallable('clearMfaBackupCodes').call<dynamic>();
    } on FirebaseFunctionsException catch (e) {
      AppLogger.warning('Backup codes were not cleared: ${e.code}');
    } catch (e) {
      AppLogger.warning('Backup codes were not cleared: ${e.runtimeType}');
    }
  }

  /// Deletes codes that were generated for an enrollment that did not
  /// happen. Never throws, so a cleanup cannot hide the error that ended the
  /// enrollment.
  Future<void> discardBackupCodes() => _clearBackupCodes();

  /// Finishes a sign-in that waits for the second factor, with the
  /// six-digit [code] from the authenticator app.
  Future<bool> completeMfaSignIn(
    MfaResolverInfo resolverInfo,
    String code,
  ) async {
    try {
      final resolver = resolverInfo.unwrap<MultiFactorResolver>();
      final hint = resolver.hints.whereType<TotpMultiFactorInfo>().firstOrNull;
      if (hint == null) {
        AppLogger.error('MFA sign-in has no authenticator-app factor');
        setError(AppLocale.current.mfaChallengeFailed);
        return false;
      }

      await resolver.resolveSignIn(
        await _totp.signInAssertion(hint.uid, code),
      );

      AppLogger.info('MFA sign-in completed');
      await _analyticsService.logLogin(method: 'email_mfa');
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA sign-in failed: ${e.code}');
      if (e.code == 'invalid-verification-code') {
        setError(AppLocale.current.mfaChallengeWrongCode);
      } else {
        _handleMfaAuthError(e);
      }
      return false;
    } catch (e) {
      AppLogger.error('MFA sign-in error: ${e.runtimeType}');
      setError(AppLocale.current.errorMfaVerificationFailed);
      return false;
    }
  }

  void _handleMfaAuthError(FirebaseAuthException e) {
    AppLogger.error('MFA Auth Error Code: ${e.code}');
    setError(mapAuthErrorToMessage(e));
  }
}
