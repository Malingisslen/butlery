/// Comprehensive Firebase authentication service providing centralized user management and security.
///
/// This service provides sophisticated authentication functionality using Firebase Auth as the backend,
/// managing user registration, login, logout, password reset, and authentication state throughout the
/// application. It implements advanced features like error handling, loading states, and real-time
/// authentication status updates for seamless user experience and robust security management.
///
/// **Architecture Integration:**
/// - Extends [ChangeNotifier] with [StateNotifierMixin] for reactive UI state management
/// - Uses [AsyncOperationMixin] for consistent loading states and error handling patterns
/// - Integrates with [AuthRepository] interface for testable and flexible authentication backends
/// - Coordinates with user profile management for complete user onboarding workflows
/// - Provides real-time authentication state streams for immediate UI responsiveness
///
/// **Authentication Features:**
/// - **User Registration**: Secure account creation with email/password and display name setup
/// - **User Login**: Comprehensive sign-in functionality with credential validation
/// - **Password Management**: Password reset functionality with email-based recovery
/// - **Session Management**: Automatic session handling with persistent authentication state
/// - **Error Handling**: Sophisticated Firebase Auth error handling with localized messages
/// - **State Management**: Real-time authentication state updates with UI synchronization
///
/// **Security and Validation:**
/// - **Input Validation**: Comprehensive validation of email formats and password requirements
/// - **Error Localization**: User-friendly error messages with Swedish localization support
/// - **Session Security**: Secure session management with automatic state synchronization
/// - **Authentication Persistence**: Automatic authentication state persistence across app sessions

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
/// Firebase authentication service with comprehensive state management and error handling.
///
/// This service provides complete authentication functionality using Firebase Auth with sophisticated
/// state management, error handling, and real-time updates. It serves as the central authentication
/// coordinator for the entire application, managing user sessions, authentication state, and
/// providing reactive updates to the UI layer.
///
/// **State Management Architecture:**
/// Uses a combination of ChangeNotifier and specialized mixins for robust state management:
/// - [StateNotifierMixin] provides consistent loading and error state patterns
/// - [AsyncOperationMixin] handles asynchronous operations with proper error management
/// - Real-time authentication state synchronization with automatic UI updates
///
/// **Usage Examples:**
/// ```dart
/// final authService = AuthService();
/// 
/// // Register new user
/// final success = await authService.registerWithEmail(
///   email: 'user@example.com',
///   password: 'securePassword',
///   displayName: 'John Doe',
/// );
/// 
/// // Listen to authentication state
/// authService.addListener(() {
///   if (authService.isAuthenticated) {
///     navigateToHome();
///   } else {
///     navigateToLogin();
///   }
/// });
/// ```
class AuthService extends ChangeNotifier with StateNotifierMixin, AsyncOperationMixin {
  /// Repository handling all Firebase Auth communication and operations.
  final auth_repo.AuthRepository _authRepository;

  /// Currently authenticated user (null if logged out).
  User? _currentUser;

  /// Current authenticated user, null if not logged in.
  User? get currentUser => _currentUser;
  
  /// Current error message from authentication operations.
  String? get errorMessage => error;
  
  /// Whether a user is currently authenticated.
  bool get isAuthenticated => _currentUser != null;
  
  /// Current user ID if authenticated, null otherwise.
  String? get currentUserId => _authRepository.currentUserId;

  /// Creates an AuthService with automatic authentication state monitoring.
  ///
  /// Initializes the service with the provided auth repository (defaults to FirebaseAuthRepository)
  /// and sets up real-time authentication state listening for immediate UI updates.
  ///
  /// [authRepository] Optional auth repository for dependency injection and testing
  AuthService({auth_repo.AuthRepository? authRepository})
      : _authRepository = authRepository ?? FirebaseAuthRepository() {
    // Listen to authentication state changes and update UI accordingly
    _authRepository.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners(); // Notify UI of state changes
    });
  }

  /// Registrera ny användare med email och lösenord
  ///
  /// Returnerar true om registrering lyckas, false annars
  /// Sätter errorMessage om något går fel
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return await executeAsync(() async {
      final UserCredential credential =
          await _authRepository.createUser(email, password);

      if (credential.user != null) {
        await _authRepository.updateDisplayName(credential.user!, displayName);
        _currentUser = _authRepository.currentUser;
      }

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

  /// Logga in med email och lösenord
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await executeAsync(() async {
      await _authRepository.signIn(email: email, password: password);
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

  /// Logga ut användare
  Future<void> signOut() async {
    await executeAsync(() async {
      await _authRepository.signOut();
      _currentUser = null;
    }).catchError((e) {
      setError('Kunde inte logga ut: ${e.toString()}');
    });
  }

  /// Skicka lösenordsåterställning via email
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

  /// Ta bort användarkonto permanent
  ///
  /// OBS: Användaren måste ha loggat in nyligen för att detta ska fungera
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

  /// Privat metod för att hantera Firebase Auth-fel
  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage;
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

  /// Publik metod för att rensa fel från UI
  @override
  void clearError() {
    setError('');
  }
  
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}
