import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
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

  String? get errorMessage => error;

  AuthMfaService({
    required AnalyticsService analyticsService,
    required AuthRepository authRepository,
  })  : _analyticsService = analyticsService,
        _authRepository = authRepository;

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
          .map((f) => MfaFactorInfo(
                factor: f,
                displayName: f.displayName,
                enrollmentTimestamp: f.enrollmentTimestamp,
              ))
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
          const MfaError(code: 'user-not-found', message: 'No user signed in'));
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
        name: 'mfa_enrolled',
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
          'MFA factor unenrolled: ${firebaseFactor.uid.maskedUserId}');
      await _analyticsService.logEvent(name: 'mfa_unenrolled');
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

  MfaResolverInfo createMfaResolver(MultiFactorResolver resolver) {
    final phoneHint =
        resolver.hints.whereType<PhoneMultiFactorInfo>().firstOrNull;
    return MfaResolverInfo(
      resolver: resolver,
      phoneHint: phoneHint?.phoneNumber,
    );
  }

  Future<void> startMfaSignIn(
    MfaResolverInfo resolverInfo, {
    required void Function(String verificationId) onCodeSent,
    required void Function(MfaError error) onError,
  }) async {
    final resolver = resolverInfo.unwrap<MultiFactorResolver>();
    final phoneHint =
        resolver.hints.whereType<PhoneMultiFactorInfo>().firstOrNull;

    if (phoneHint == null) {
      onError(const MfaError(
          code: 'no-phone-factor', message: 'No phone MFA found'));
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
