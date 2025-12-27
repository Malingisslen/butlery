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
        setError('Ett oväntat fel uppstod: ${e.toString()}');
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
        setError('Inloggning misslyckades. Försök igen.');
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
        setError('Ett oväntat fel uppstod: ${e.toString()}');
      }
      _currentUser = _authRepository.currentUser;
      return _currentUser != null;
    }
  }

  Future<void> signOut() async {
    await executeAsync(() async {
      await _authRepository.signOut();
      _currentUser = null;
      AppLogger.info('User signed out successfully');
      await _analyticsService.logLogout();
    }).catchError((e) {
      setError('Kunde inte logga ut: ${e.toString()}');
    });
  }

  /// Logout for session timeout - tracks separately for security monitoring.
  Future<void> logoutDueToInactivity() async {
    await executeAsync(() async {
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
      setError('Kunde inte logga ut: ${e.toString()}');
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
      setError('Ett oväntat fel uppstod: ${e.toString()}');
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
        setError('Ett oväntat fel uppstod: ${e.toString()}');
      }
      return false;
    });
  }

  /// Requires recent login - will fail if session is stale.
  Future<bool> deleteAccount() async {
    if (_currentUser == null) {
      setError('Ingen användare är inloggad');
      return false;
    }

    return await executeAsync(() async {
      await _authRepository.deleteCurrentUser();
      _currentUser = null;
      return true;
    }).catchError((e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'requires-recent-login') {
          setError('Du måste logga in igen för att ta bort ditt konto');
        } else {
          _handleAuthError(e);
        }
      } else {
        setError('Kunde inte ta bort konto: ${e.toString()}');
      }
      return false;
    });
  }

  // ============== MFA Methods ==============

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

  /// Get list of enrolled MFA factors.
  Future<List<MultiFactorInfo>> getEnrolledFactors() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      return await user.multiFactor.getEnrolledFactors();
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
    required void Function(FirebaseAuthException error) onError,
    void Function()? onAutoVerified,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError(FirebaseAuthException(
          code: 'user-not-found', message: 'No user signed in'));
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
              onError(e);
            }
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          AppLogger.error('MFA verification failed: ${error.code}');
          onError(error);
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
        onError(e);
      } else {
        onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
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
      setError('Kunde inte slutföra MFA-registrering');
      return false;
    }
  }

  /// Unenroll a specific MFA factor.
  Future<bool> unenrollMfa(MultiFactorInfo factor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await user.multiFactor.unenroll(multiFactorInfo: factor);
      AppLogger.info('MFA factor unenrolled: ${factor.uid}');
      await _analyticsService.logEvent(name: 'mfa_unenrolled');
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('MFA unenroll failed: ${e.code}');
      _handleAuthError(e);
      return false;
    } catch (e) {
      AppLogger.error('MFA unenroll error: $e');
      setError('Kunde inte ta bort MFA');
      return false;
    }
  }

  /// Resolve MFA challenge during sign-in.
  /// Called when [signInWithEmail] throws [FirebaseAuthMultiFactorException].
  Future<void> startMfaSignIn(
    MultiFactorResolver resolver, {
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onError,
  }) async {
    // Get the first phone hint (users typically have one phone factor)
    final phoneHint =
        resolver.hints.whereType<PhoneMultiFactorInfo>().firstOrNull;

    if (phoneHint == null) {
      onError(FirebaseAuthException(
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
            if (e is FirebaseAuthException) onError(e);
          }
        },
        verificationFailed: onError,
        codeSent: (verificationId, _) => onCodeSent(verificationId),
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        onError(e);
      } else {
        onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
      }
    }
  }

  /// Complete MFA sign-in with SMS code.
  Future<bool> completeMfaSignIn(
    MultiFactorResolver resolver,
    String verificationId,
    String smsCode,
  ) async {
    try {
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
      setError('MFA-verifiering misslyckades');
      return false;
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage;
    AppLogger.error('Firebase Auth Error Code: ${e.code}');
    switch (e.code) {
      case 'weak-password':
        errorMessage = 'Lösenordet är för svagt. Använd minst 6 tecken.';
        break;
      case 'email-already-in-use':
        errorMessage = 'Email-adressen används redan av ett annat konto.';
        break;
      case 'invalid-email':
        errorMessage = 'Ogiltig email-adress.';
        break;
      case 'user-not-found':
        errorMessage = 'Ingen användare hittades med denna email.';
        break;
      case 'wrong-password':
        errorMessage = 'Fel lösenord.';
        break;
      case 'invalid-credential':
        errorMessage = 'Fel email eller lösenord. Kontrollera dina uppgifter.';
        break;
      case 'user-disabled':
        errorMessage = 'Detta konto har inaktiverats.';
        break;
      case 'too-many-requests':
        errorMessage = 'För många försök. Vänta en stund och försök igen.';
        break;
      case 'network-request-failed':
        errorMessage = 'Nätverksfel. Kontrollera din internetanslutning.';
        break;
      // MFA-specific errors
      case 'invalid-verification-code':
        errorMessage = 'Ogiltig verifieringskod. Försök igen.';
        break;
      case 'session-expired':
        errorMessage = 'Sessionen har gått ut. Försök igen.';
        break;
      case 'quota-exceeded':
        errorMessage = 'För många SMS-försök. Försök igen senare.';
        break;
      case 'invalid-phone-number':
        errorMessage = 'Ogiltigt telefonnummer. Ange med landskod (+46).';
        break;
      case 'missing-phone-number':
        errorMessage = 'Telefonnummer saknas.';
        break;
      default:
        errorMessage = 'Autentiseringsfel: ${e.message}';
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
