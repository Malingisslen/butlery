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
      AppLogger.debug('Login result - User: ${_currentUser?.email ?? "null"}');

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
