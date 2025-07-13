import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/firebase/firebase_auth_repository.dart';

/// AuthService hanterar all autentisering med Firebase
///
/// Denna service är en singleton som:
/// - Hanterar inloggning och registrering
/// - Sparar användarens inloggningsstatus
/// - Tillhandahåller streams för auth state changes
/// - Hanterar utloggning och lösenordsåterställning
class AuthService extends ChangeNotifier {
  // Wrapper around FirebaseAuth for easier testing and access
  final FirebaseAuthRepository _authRepository;

  // Aktuell inloggad användare (null om utloggad)
  User? _currentUser;

  // Loading state för UI feedback
  bool _isLoading = false;

  // Error message för att visa felmeddelanden i UI
  String? _errorMessage;

  // Getters för att UI kan läsa state
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// Konstruktor - lyssnar på auth state changes
  AuthService({FirebaseAuthRepository? authRepository})
      : _authRepository = authRepository ?? FirebaseAuthRepository() {
    // Lyssna på förändringar i autentiseringsstatus
    // Detta triggas när användare loggar in/ut
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
    try {
      _setLoading(true);
      _clearError();

      // Skapa användare i Firebase Auth
      final UserCredential credential = await _authRepository.register(
        email: email,
        password: password,
      );

      // Uppdatera användarens display name
      if (credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload(); // Ladda om för att få uppdaterad info
        _currentUser = _authRepository.currentUser; // Hämta uppdaterad användare
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      // Hantera Firebase-specifika fel
      _handleAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      // Hantera övriga fel
      _errorMessage = 'Ett oväntat fel uppstod: ${e.toString()}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Logga in med email och lösenord
  ///
  /// Returnerar true om inloggning lyckas, false annars
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Logga in användare
      await _authRepository.signIn(email: email, password: password);

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Ett oväntat fel uppstod: ${e.toString()}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Logga ut användare
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _authRepository.signOut();
      _currentUser = null;
      _setLoading(false);
    } catch (e) {
      _errorMessage = 'Kunde inte logga ut: ${e.toString()}';
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Skicka lösenordsåterställning via email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await _authRepository.sendPasswordResetEmail(email);

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Ett oväntat fel uppstod: ${e.toString()}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Ta bort användarkonto permanent
  ///
  /// OBS: Användaren måste ha loggat in nyligen för att detta ska fungera
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _clearError();

      // Kontrollera att vi har en inloggad användare
      if (_currentUser == null) {
        _errorMessage = 'Ingen användare är inloggad';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // Ta bort användaren
      await _currentUser!.delete();
      _currentUser = null;

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _errorMessage = 'Du måste logga in igen för att ta bort ditt konto';
      } else {
        _handleAuthError(e);
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Kunde inte ta bort konto: ${e.toString()}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Privat metod för att hantera Firebase Auth-fel
  ///
  /// Översätter Firebase felkoder till svenska användarmeddelanden
  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        _errorMessage = 'Lösenordet är för svagt. Använd minst 6 tecken.';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Email-adressen används redan av ett annat konto.';
        break;
      case 'invalid-email':
        _errorMessage = 'Ogiltig email-adress.';
        break;
      case 'user-not-found':
        _errorMessage = 'Ingen användare hittades med denna email.';
        break;
      case 'wrong-password':
        _errorMessage = 'Fel lösenord.';
        break;
      case 'user-disabled':
        _errorMessage = 'Detta konto har inaktiverats.';
        break;
      case 'too-many-requests':
        _errorMessage = 'För många försök. Vänta en stund och försök igen.';
        break;
      case 'network-request-failed':
        _errorMessage = 'Nätverksfel. Kontrollera din internetanslutning.';
        break;
      default:
        _errorMessage = 'Autentiseringsfel: ${e.message}';
    }
    notifyListeners();
  }

  /// Sätt loading state och meddela lyssnare
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Rensa felmeddelande
  void _clearError() {
    _errorMessage = null;
  }

  /// Publik metod för att rensa fel från UI
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
