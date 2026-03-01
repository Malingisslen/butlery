import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/notifications/modules/fcm_token_manager.dart';
import 'package:butlery/models/auth/mfa_types.dart';

/// Firebase authentication service managing login, registration, and session state.
class AuthService extends ChangeNotifier
    with
        StateNotifierMixin,
        AsyncOperationMixin,
        StreamManagementMixin,
        ErrorHandlingMixin {
  final auth_repo.AuthRepository _authRepository;
  final AnalyticsService _analyticsService;
  User? _currentUser;

  User? get currentUser => _currentUser;
  String? get currentUserDisplayName => _currentUser?.displayName;
  String? get currentUserEmail => _currentUser?.email;
  String? get currentUserPhotoUrl => _currentUser?.photoURL;
  String? get errorMessage => error;
  bool get isAuthenticated => _currentUser != null;
  String? get currentUserId => _authRepository.currentUserId;

  AuthService({
    auth_repo.AuthRepository? authRepository,
    required AnalyticsService analyticsService,
  })  : _authRepository = authRepository ?? FirebaseAuthRepository(),
        _analyticsService = analyticsService {
    _authRepository.authStateChanges().listen(
      (User? user) {
        _currentUser = user;
        notifyListeners();
      },
      onError: (error) {
        AppLogger.debug('Auth state stream error (non-blocking): $error');
      },
    );
  }

  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      clearError();
      setLoading(true);

      final UserCredential credential = await _authRepository.createUser(
        email,
        password,
      );

      if (credential.user != null) {
        await _authRepository.updateDisplayName(credential.user!, displayName);
        _currentUser = _authRepository.currentUser;
        setLoading(false);
        await _analyticsService.logSignUp(method: 'email');
        return true;
      }

      setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      _handleAuthError(e);
      await _analyticsService.logEvent(
        name: 'auth_failed',
        parameters: {
          'method': 'email',
          'error_code': e.code,
          'action': 'sign_up',
        },
      );
      return false;
    } catch (e) {
      setLoading(false);
      // Filter out false-positive GMS errors
      if (!e.toString().contains('com.google.android.gms')) {
        setError(AppLocale.current.errorUnexpected);
      }
      _currentUser = _authRepository.currentUser;
      return _currentUser != null;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      clearError();
      setLoading(true);

      AppLogger.debug(
          'Attempting login for email: ${email.substring(0, 3)}...');
      await _authRepository.signIn(email: email, password: password);
      _currentUser = _authRepository.currentUser;
      AppLogger.debug('Login result - User: ${_currentUser?.uid ?? "null"}');

      setLoading(false);

      if (_currentUser == null) {
        AppLogger.error('Login appeared successful but no user returned');
        setError(AppLocale.current.errorLoginFailed);
        return false;
      }

      await _analyticsService.logLogin(method: 'email');
      return true;
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      AppLogger.error('Firebase Auth Error: ${e.code} - ${e.message}');
      _handleAuthError(e);
      await _analyticsService.logEvent(
        name: 'auth_failed',
        parameters: {
          'method': 'email',
          'error_code': e.code,
          'action': 'sign_in',
        },
      );
      return false;
    } catch (e) {
      setLoading(false);
      AppLogger.error('Unexpected login error: $e');
      // Filter out false-positive GMS errors
      if (!e.toString().contains('com.google.android.gms')) {
        setError(AppLocale.current.errorUnexpected);
      }
      _currentUser = _authRepository.currentUser;
      return _currentUser != null;
    }
  }

  Future<void> signOut() async {
    await executeAsync(() async {
      await _cleanupFcmTokens();
      await _authRepository.signOut();
      _currentUser = null;
      AppLogger.info('User signed out successfully');
      await _analyticsService.logLogout();
    }).catchError((e) {
      setError(AppLocale.current.errorCouldNotLogOut);
    });
  }

  /// Logout for session timeout - tracks separately for security monitoring.
  Future<void> logoutDueToInactivity() async {
    await executeAsync(() async {
      await _cleanupFcmTokens();
      await _authRepository.signOut();
      _currentUser = null;
      AppLogger.info('User logged out due to session inactivity');
      await _analyticsService.logEvent(
        name: 'logout_inactivity',
        parameters: {
          'reason': 'session_timeout',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }).catchError((e) {
      AppLogger.error('Session timeout logout failed', e);
      setError(AppLocale.current.errorCouldNotLogOut);
    });
  }

  Future<void> forceSignOut() async {
    try {
      await _authRepository.signOut();
      _currentUser = null;
      clearError();
      AppLogger.info('Force sign out completed');
    } catch (e) {
      AppLogger.error('Force sign out error: $e');
    }
  }

  /// Re-authenticate user with password (required before sensitive operations).
  Future<bool> reauthenticateWithPassword(String password) async {
    try {
      clearError();
      await _authRepository.reauthenticateWithPassword(password);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    return await executeAsync(() async {
      await _authRepository.sendPasswordResetEmail(email);
      return true;
    }).catchError((e) {
      if (e is FirebaseAuthException) {
        _handleAuthError(e);
      } else {
        setError(AppLocale.current.errorUnexpected);
      }
      return false;
    });
  }

  /// Requires recent login - will fail if session is stale.
  Future<bool> deleteAccount() async {
    if (_currentUser == null) {
      setError(AppLocale.current.errorNoUserLoggedIn);
      return false;
    }

    return await executeAsync(() async {
      await _authRepository.deleteCurrentUser();
      _currentUser = null;
      return true;
    }).catchError((e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          setError(AppLocale.current.errorReauthRequired);
        } else {
          _handleAuthError(e);
        }
      } else {
        setError(AppLocale.current.errorCouldNotDeleteAccount);
      }
      return false;
    });
  }

  /// Check if the current user has MFA enabled.
  Future<bool> hasMfaEnabled() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      return factors.isNotEmpty;
    } catch (e) {
      AppLogger.warning('Failed to check MFA status: $e');
      return false;
    }
  }

  /// Get list of enrolled MFA factors as domain types.
  Future<List<MfaFactorInfo>> getEnrolledFactors() async {
    final user = FirebaseAuth.instance.currentUser;
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

  /// Start MFA enrollment with a phone number.
  /// Calls [onCodeSent] when SMS code is sent, or [onError] on failure.
  Future<void> startMfaEnrollment(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(MfaError error) onError,
    void Function()? onAutoVerified,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError(
          const MfaError(code: 'user-not-found', message: 'No user signed in'));
      return;
    }

    try {
      final session = await user.multiFactor.getSession();

      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: session,
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on some Android devices
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

  /// Complete MFA enrollment with the SMS code.
  Future<bool> completeMfaEnrollment(
    String verificationId,
    String smsCode,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
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
      _handleAuthError(e);
      return false;
    } catch (e) {
      AppLogger.error('MFA enrollment error: $e');
      setError(AppLocale.current.errorCouldNotCompleteMfa);
      return false;
    }
  }

  /// Unenroll a specific MFA factor.
  Future<bool> unenrollMfa(MfaFactorInfo factor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final firebaseFactor = factor.unwrap<MultiFactorInfo>();
      await user.multiFactor.unenroll(multiFactorInfo: firebaseFactor);
      AppLogger.info('MFA factor unenrolled: ${firebaseFactor.uid}');
      await _analyticsService.logEvent(name: 'mfa_unenrolled');
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA unenroll failed: ${e.code}');
      _handleAuthError(e);
      return false;
    } catch (e) {
      AppLogger.error('MFA unenroll error: $e');
      setError(AppLocale.current.errorCouldNotRemoveMfa);
      return false;
    }
  }

  /// Create an [MfaResolverInfo] from a [FirebaseAuthMultiFactorException].
  /// Call this where the exception is caught, then pass the result to views.
  MfaResolverInfo createMfaResolver(MultiFactorResolver resolver) {
    final phoneHint =
        resolver.hints.whereType<PhoneMultiFactorInfo>().firstOrNull;
    return MfaResolverInfo(
      resolver: resolver,
      phoneHint: phoneHint?.phoneNumber,
    );
  }

  /// Resolve MFA challenge during sign-in.
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
      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: resolver.session,
        multiFactorInfo: phoneHint,
        verificationCompleted: (credential) async {
          // Auto-verify on some Android devices
          try {
            await resolver.resolveSignIn(
              PhoneMultiFactorGenerator.getAssertion(credential),
            );
            _currentUser = FirebaseAuth.instance.currentUser;
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

  /// Complete MFA sign-in with SMS code.
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

      _currentUser = FirebaseAuth.instance.currentUser;
      AppLogger.info('MFA sign-in completed');
      await _analyticsService.logLogin(method: 'email_mfa');
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA sign-in failed: ${e.code}');
      _handleAuthError(e);
      return false;
    } catch (e) {
      AppLogger.error('MFA sign-in error: $e');
      setError(AppLocale.current.errorMfaVerificationFailed);
      return false;
    }
  }

  /// Change user password. Requires prior reauthentication.
  Future<bool> changePassword(String newPassword) async {
    try {
      clearError();
      await _authRepository.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
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
      await _authRepository.verifyBeforeUpdateEmail(newEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      setError(AppLocale.current.errorUnexpected);
      return false;
    }
  }

  /// Clean up FCM tokens before sign-out to prevent stale delivery.
  Future<void> _cleanupFcmTokens() async {
    try {
      final userId = _authRepository.currentUserId;
      if (userId != null) {
        final tokenManager = FCMTokenManager(userId: userId);
        await tokenManager.cleanup();
      }
    } catch (e) {
      // Don't block logout if FCM cleanup fails
      AppLogger.warning('FCM token cleanup failed during sign-out: $e');
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    final l = AppLocale.current;
    String errorMessage;
    AppLogger.error('Firebase Auth Error Code: ${e.code}');
    switch (e.code) {
      case 'weak-password':
        errorMessage = l.errorWeakPassword;
        break;
      case 'email-already-in-use':
        errorMessage = l.errorEmailAlreadyInUse;
        break;
      case 'invalid-email':
        errorMessage = l.errorInvalidEmailAddress;
        break;
      case 'user-not-found':
        errorMessage = l.errorUserNotFoundByEmail;
        break;
      case 'wrong-password':
        errorMessage = l.errorWrongPassword;
        break;
      case 'invalid-credential':
        errorMessage = l.errorInvalidCredentials;
        break;
      case 'user-disabled':
        errorMessage = l.errorAccountDisabled;
        break;
      case 'too-many-requests':
        errorMessage = l.errorTooManyAttempts;
        break;
      case 'network-request-failed':
        errorMessage = l.errorNetwork;
        break;
      // MFA-specific errors
      case 'invalid-verification-code':
        errorMessage = l.errorInvalidVerificationCode;
        break;
      case 'session-expired':
        errorMessage = l.errorSessionExpired;
        break;
      case 'quota-exceeded':
        errorMessage = l.errorTooManySmsAttempts;
        break;
      case 'invalid-phone-number':
        errorMessage = l.errorInvalidPhoneNumber;
        break;
      case 'missing-phone-number':
        errorMessage = l.errorPhoneNumberMissing;
        break;
      default:
        errorMessage = l.errorAuthentication;
    }
    setError(errorMessage);
  }

  @override
  void clearError() {
    super.clearError();
  }

  @override
  void dispose() {
    disposeStreamResources();
    super.dispose();
  }
}
