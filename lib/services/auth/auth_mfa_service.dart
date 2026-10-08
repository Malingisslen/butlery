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

/// Multi-factor authentication service extracted from AuthService.
class AuthMfaService extends ChangeNotifier
    with StateNotifierMixin, ErrorHandlingMixin {
  final AnalyticsService _analyticsService;
  final AuthRepository _authRepository;
  final FirebaseFunctions? _functions;

  String? get errorMessage => error;

  /// [functions] reaches the backup-code callables
  /// (functions/src/account/mfa-backup-codes.ts). Without it, backup codes
  /// cannot be created or used, and enrollment must not be offered.
  AuthMfaService({
    required AnalyticsService analyticsService,
    required AuthRepository authRepository,
    FirebaseFunctions? functions,
  }) : _analyticsService = analyticsService,
       _authRepository = authRepository,
       _functions = functions;

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

  /// The way in without the phone: the server proves the password, spends
  /// the code, and removes the phone factor. Neither the password nor the
  /// code is logged. The caller signs in again with the password afterwards.
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

  Future<void> startMfaEnrollment(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(MfaError error) onError,
    void Function()? onAutoVerified,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      onError(
        const MfaError(code: 'user-not-found', message: 'No user signed in'),
      );
      return;
    }

    try {
      final session = await user.multiFactor.getSession();

      await _authRepository.verifyPhoneNumber(
        multiFactorSession: session,
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await user.multiFactor.enroll(
              PhoneMultiFactorGenerator.getAssertion(credential),
            );
            AppLogger.info('MFA auto-enrolled successfully');
            onAutoVerified?.call();
          } catch (e) {
            AppLogger.error('MFA auto-enrollment failed: $e');
            if (e is FirebaseAuthException) {
              onError(MfaError(code: e.code, message: e.message));
            }
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          AppLogger.error('MFA verification failed: ${error.code}');
          onError(MfaError(code: error.code, message: error.message));
        },
        codeSent: (String verificationId, int? resendToken) {
          AppLogger.info('MFA SMS code sent');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          AppLogger.debug('MFA code auto-retrieval timeout');
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      AppLogger.error('Failed to start MFA enrollment: $e');
      if (e is FirebaseAuthException) {
        onError(MfaError(code: e.code, message: e.message));
      } else {
        onError(MfaError(code: 'unknown', message: e.toString()));
      }
    }
  }

  Future<bool> completeMfaEnrollment(
    String verificationId,
    String smsCode,
  ) async {
    final user = _authRepository.currentUser;
    if (user == null) return false;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await user.multiFactor.enroll(
        PhoneMultiFactorGenerator.getAssertion(credential),
      );

      AppLogger.info('MFA enrollment completed successfully');
      await _analyticsService.logEvent(
        name: AnalyticsEvents.mfaEnrolled,
        parameters: {'method': 'sms'},
      );
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA enrollment failed: ${e.code}');
      _handleMfaAuthError(e);
      return false;
    } catch (e) {
      AppLogger.error('MFA enrollment error: $e');
      setError(AppLocale.current.errorCouldNotCompleteMfa);
      return false;
    }
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

  MfaResolverInfo createMfaResolver(MultiFactorResolver resolver) {
    final phoneHint = resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .firstOrNull;
    return MfaResolverInfo(
      resolver: resolver,
      phoneHint: phoneHint?.phoneNumber,
    );
  }

  /// Sends the sign-in code. [onAutoVerified] runs when the phone read the
  /// code itself and the sign-in is already complete: the challenge view
  /// must then move on without the user doing anything
  /// (produktregler.md:747; Skarmar v12 etapp 3 #authmfa).
  Future<void> startMfaSignIn(
    MfaResolverInfo resolverInfo, {
    required void Function(String verificationId) onCodeSent,
    required void Function(MfaError error) onError,
    void Function()? onAutoVerified,
  }) async {
    final resolver = resolverInfo.unwrap<MultiFactorResolver>();
    final phoneHint = resolver.hints
        .whereType<PhoneMultiFactorInfo>()
        .firstOrNull;

    if (phoneHint == null) {
      onError(
        const MfaError(code: 'no-phone-factor', message: 'No phone MFA found'),
      );
      return;
    }

    try {
      await _authRepository.verifyPhoneNumber(
        multiFactorSession: resolver.session,
        multiFactorInfo: phoneHint,
        phoneNumber: null,
        verificationCompleted: (credential) async {
          try {
            await resolver.resolveSignIn(
              PhoneMultiFactorGenerator.getAssertion(credential),
            );
            AppLogger.info('MFA sign-in auto-completed');
            onAutoVerified?.call();
          } catch (e) {
            if (e is FirebaseAuthException) {
              onError(MfaError(code: e.code, message: e.message));
            }
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          onError(MfaError(code: error.code, message: error.message));
        },
        codeSent: (verificationId, _) => onCodeSent(verificationId),
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        onError(MfaError(code: e.code, message: e.message));
      } else {
        onError(MfaError(code: 'unknown', message: e.toString()));
      }
    }
  }

  Future<bool> completeMfaSignIn(
    MfaResolverInfo resolverInfo,
    String verificationId,
    String smsCode,
  ) async {
    try {
      final resolver = resolverInfo.unwrap<MultiFactorResolver>();
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await resolver.resolveSignIn(
        PhoneMultiFactorGenerator.getAssertion(credential),
      );

      AppLogger.info('MFA sign-in completed');
      await _analyticsService.logLogin(method: 'email_mfa');
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA sign-in failed: ${e.code}');
      _handleMfaAuthError(e);
      return false;
    } catch (e) {
      AppLogger.error('MFA sign-in error: $e');
      setError(AppLocale.current.errorMfaVerificationFailed);
      return false;
    }
  }

  void _handleMfaAuthError(FirebaseAuthException e) {
    AppLogger.error('MFA Auth Error Code: ${e.code}');
    setError(mapAuthErrorToMessage(e));
  }
}
