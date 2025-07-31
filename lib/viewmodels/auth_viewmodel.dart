// lib/viewmodels/auth_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Manages authentication state and business logic for login/register UI components.
///
/// This ViewModel provides a clean separation between UI and authentication business
/// logic, implementing the MVVM pattern for authentication flows. It coordinates
/// with the AuthService while managing form validation, loading states, and user
/// experience concerns.
///
/// Key responsibilities:
/// - Separating authentication UI from core business logic
/// - Handling comprehensive form validation for email, password, and display name
/// - Coordinating authentication operations with the AuthService
/// - Providing reactive loading states and error message management
/// - Managing authentication mode switching (login/register)
///
/// The ViewModel follows reactive programming principles, automatically notifying
/// listeners of state changes to keep the UI synchronized with authentication state.
///
/// Example usage:
/// ```dart
/// final authViewModel = AuthViewModel();
/// final success = await authViewModel.signIn(
///   email: 'user@example.com',
///   password: 'password123',
/// );
/// ```
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = ServiceLocator.get<AuthService>();

  // Form state
  bool _isLoginMode = true; // true = login mode, false = register mode
  bool _isPasswordVisible = false;

  // Loading state inherited from AuthService
  bool get isLoading => _authService.isLoading;

  // Error message inherited from AuthService
  String? get errorMessage => _authService.errorMessage;

  // Authentication state
  bool get isAuthenticated => _authService.isAuthenticated;

  // UI state getters
  bool get isLoginMode => _isLoginMode;
  bool get isPasswordVisible => _isPasswordVisible;

  /// Constructor - sets up reactive listening to AuthService changes.
  ///
  /// Establishes a listener connection to the AuthService to ensure the ViewModel
  /// automatically reflects changes in authentication state, loading status, and
  /// error conditions.
  AuthViewModel() {
    // Listen for changes from AuthService to maintain reactive state
    _authService.addListener(_onAuthServiceChanged);
  }

  /// Toggles between login and register authentication modes.
  ///
  /// Switches the UI context between login and registration flows while
  /// clearing any existing error messages to provide a clean user experience.
  void toggleAuthMode() {
    _isLoginMode = !_isLoginMode;
    _authService.clearError(); // Clear previous error messages
    notifyListeners();
  }

  /// Toggles password field visibility for better user experience.
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  /// Authenticates user with email and password credentials.
  ///
  /// Performs comprehensive input validation before delegating to the AuthService
  /// for actual authentication. Provides immediate feedback for validation errors.
  ///
  /// @param [email] User's email address
  /// @param [password] User's password
  /// @returns True if authentication succeeds, false otherwise
  Future<bool> signIn({required String email, required String password}) async {
    // Validate input before processing
    if (!_validateEmail(email)) {
      return false;
    }

    if (!_validatePassword(password)) {
      return false;
    }

    // Delegate to AuthService for authentication
    return await _authService.signInWithEmail(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a new user account with email, password, and display name.
  ///
  /// Performs comprehensive validation on all input fields before creating the
  /// account through the AuthService. Ensures data integrity and user experience.
  ///
  /// @param [email] User's email address for the account
  /// @param [password] Secure password meeting minimum requirements
  /// @param [displayName] User's display name for the profile
  /// @returns True if registration succeeds, false otherwise
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // Validate all input fields before processing
    if (!_validateEmail(email)) {
      return false;
    }

    if (!_validatePassword(password)) {
      return false;
    }

    if (!_validateDisplayName(displayName)) {
      return false;
    }

    // Delegate to AuthService for account creation
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
      _setError('Email cannot be empty');
      return false;
    }

    // Email validation with Unicode support for international characters
    final emailRegex = RegExp(r'^[\p{L}\p{N}._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$', unicode: true);
    if (!emailRegex.hasMatch(email)) {
      _setError('Invalid email address');
      return false;
    }

    return true;
  }

  /// Validera lösenord
  bool _validatePassword(String password) {
    if (password.isEmpty) {
      _setError('Password cannot be empty');
      return false;
    }

    if (password.length < 6) {
      _setError('Password must be at least 6 characters');
      return false;
    }

    return true;
  }

  /// Validera display name
  bool _validateDisplayName(String displayName) {
    if (displayName.isEmpty) {
      _setError('Display name cannot be empty');
      return false;
    }

    if (displayName.length < 2) {
      _setError('Display name must be at least 2 characters');
      return false;
    }

    return true;
  }

  /// Handles local error state management.
  ///
  /// Notifies listeners of validation errors while maintaining consistency
  /// with the AuthService error handling patterns.
  void _setError(String message) {
    // Notify listeners of validation errors for immediate UI feedback
    notifyListeners();
  }

  /// Handles reactive updates from AuthService state changes.
  void _onAuthServiceChanged() {
    notifyListeners();
  }

  /// Clears any existing error messages.
  void clearError() {
    _authService.clearError();
  }

  @override
  void dispose() {
    // Remove AuthService listener when ViewModel is disposed
    _authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }
}
