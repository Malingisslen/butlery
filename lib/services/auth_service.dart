import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/interfaces/auth_repository.dart';
import '../repositories/firebase/firebase_auth_repository.dart';
import '../core/mixins/state_notifier_mixin.dart';
import '../core/mixins/async_operation_mixin.dart';

/// AuthService hanterar all autentisering med Firebase
///
/// Denna service är en singleton som:
/// - Hanterar inloggning och registrering
/// - Sparar användarens inloggningsstatus
/// - Tillhandahåller streams för auth state changes
/// - Hanterar utloggning och lösenordsåterställning
class AuthService extends ChangeNotifier with StateNotifierMixin, AsyncOperationMixin {
  // Repository som hanterar all Firebase Auth-kommunikation
  final AuthRepository _authRepository;

  // Aktuell inloggad användare (null om utloggad)
  User? _currentUser;


  // Getters för att UI kan läsa state
  User? get currentUser => _currentUser;
  String? get errorMessage => error; // Use mixin error property
  bool get isAuthenticated => _currentUser != null;
  String? get currentUserId => _authRepository.currentUserId;

  /// Konstruktor - lyssnar på auth state changes
  AuthService({AuthRepository? authRepository})
      : _authRepository = authRepository ?? FirebaseAuthRepository() {
    // Lyssna på förändringar i autentiseringsstatus
    _authRepository.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners(); // Meddela UI om förändringen
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
}
