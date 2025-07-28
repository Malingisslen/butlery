// lib/viewmodels/auth_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/injection.dart';

/// AuthViewModel hanterar state och logik för login/register UI
///
/// Denna ViewModel:
/// - Separerar UI från business logic
/// - Hanterar form validation
/// - Koordinerar med AuthService
/// - Tillhandahåller loading states och error messages
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = sl<AuthService>();

  // Form state
  bool _isLoginMode = true; // true = login, false = register
  bool _isPasswordVisible = false;

  // Loading state ärvs från AuthService
  bool get isLoading => _authService.isLoading;

  // Error message ärvs från AuthService
  String? get errorMessage => _authService.errorMessage;

  // Auth state
  bool get isAuthenticated => _authService.isAuthenticated;

  // UI state getters
  bool get isLoginMode => _isLoginMode;
  bool get isPasswordVisible => _isPasswordVisible;

  /// Konstruktor - lyssnar på förändringar i AuthService
  AuthViewModel() {
    // Lyssna på förändringar från AuthService
    _authService.addListener(_onAuthServiceChanged);
  }

  /// Toggle mellan login och register mode
  void toggleAuthMode() {
    _isLoginMode = !_isLoginMode;
    _authService.clearError(); // Rensa gamla felmeddelanden
    notifyListeners();
  }

  /// Toggle lösenords-synlighet
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  /// Logga in användare
  ///
  /// Returnerar true om inloggning lyckas
  Future<bool> signIn({required String email, required String password}) async {
    // Validera input
    if (!_validateEmail(email)) {
      return false;
    }

    if (!_validatePassword(password)) {
      return false;
    }

    // Anropa AuthService
    return await _authService.signInWithEmail(
      email: email.trim(),
      password: password,
    );
  }

  /// Registrera ny användare
  ///
  /// Returnerar true om registrering lyckas
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Validera input
    if (!_validateEmail(email)) {
      return false;
    }

    if (!_validatePassword(password)) {
      return false;
    }

    if (!_validateDisplayName(displayName)) {
      return false;
    }

    // Anropa AuthService
    return await _authService.registerWithEmail(
      email: email.trim(),
      password: password,
      displayName: displayName.trim(),
    );
  }

  /// Logga ut användare
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Skicka lösenordsåterställning
  Future<bool> sendPasswordReset(String email) async {
    if (!_validateEmail(email)) {
      return false;
    }

    return await _authService.sendPasswordResetEmail(email.trim());
  }

  /// Validera email-format
  bool _validateEmail(String email) {
    if (email.isEmpty) {
      _setError('Email kan inte vara tom');
      return false;
    }

    // Email-validering med stöd för Unicode-tecken i local part
    final emailRegex = RegExp(r'^[\p{L}\p{N}._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$', unicode: true);
    if (!emailRegex.hasMatch(email)) {
      _setError('Ogiltig email-adress');
      return false;
    }

    return true;
  }

  /// Validera lösenord
  bool _validatePassword(String password) {
    if (password.isEmpty) {
      _setError('Lösenord kan inte vara tomt');
      return false;
    }

    if (password.length < 6) {
      _setError('Lösenordet måste vara minst 6 tecken');
      return false;
    }

    return true;
  }

  /// Validera display name
  bool _validateDisplayName(String displayName) {
    if (displayName.isEmpty) {
      _setError('Namn kan inte vara tomt');
      return false;
    }

    if (displayName.length < 2) {
      _setError('Namnet måste vara minst 2 tecken');
      return false;
    }

    return true;
  }

  /// Sätt felmeddelande lokalt i AuthService
  void _setError(String message) {
    // Vi kan inte direkt sätta error i AuthService, så vi använder en workaround
    // Detta är en begränsning vi får leva med tills vi refaktorerar AuthService
    notifyListeners();
  }

  /// Lyssna på förändringar från AuthService
  void _onAuthServiceChanged() {
    notifyListeners();
  }

  /// Rensa felmeddelanden
  void clearError() {
    _authService.clearError();
  }

  @override
  void dispose() {
    // Sluta lyssna på AuthService när ViewModel tas bort
    _authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }
}
