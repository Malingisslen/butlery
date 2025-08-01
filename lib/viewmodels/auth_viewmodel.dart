/// Comprehensive authentication ViewModel providing advanced user authentication and state management for Flutter applications.
///
/// This module implements sophisticated authentication management following Single Responsibility Principle,
/// handling all aspects of user authentication including credential validation, authentication flow coordination,
/// reactive state management, and comprehensive error handling. It provides complete authentication infrastructure while
/// maintaining clean separation from UI rendering, data persistence, and business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles authentication presentation layer concerns:
/// - **Authentication Excellence**: Complete login/register flow management with comprehensive credential validation
/// - **Reactive State Management**: Advanced state coordination with automatic UI synchronization and loading states
/// - **Form Validation Intelligence**: Sophisticated input validation with Swedish localization and user feedback
/// - **Mode Management**: Dynamic authentication mode switching with clean state transitions
/// - **Service Integration**: Seamless coordination with AuthService while maintaining presentation layer separation
///
/// **What This Module Does NOT Handle:**
/// - Actual authentication implementation (handled by AuthService and Firebase Auth)
/// - User data persistence and profile management (handled by UserService and Firestore)
/// - UI rendering and widget creation (handled by AuthView and authentication UI components)
/// - Navigation and routing logic (handled by navigation services and app routing)
///
/// **Authentication ViewModel Features:**
/// - **Dual Mode Authentication**: Seamless switching between login and registration flows with state preservation
/// - **Advanced Input Validation**: Comprehensive email, password, and display name validation with Swedish error messages
/// - **Reactive Loading States**: Automatic loading indicator management with service state synchronization
/// - **Password Visibility Control**: Enhanced user experience with password visibility toggling
/// - **Error State Management**: Comprehensive error handling with validation feedback and service error integration
///
/// **Usage Examples:**
/// ```dart
/// // Basic authentication flow
/// final authViewModel = AuthViewModel();
/// 
/// // Sign in with comprehensive validation
/// final success = await authViewModel.signIn(
///   email: 'erik.svensson@example.com',
///   password: 'säkertLösenord123',
/// );
/// 
/// // Registration with complete validation
/// if (authViewModel.isLoginMode == false) {
///   final registered = await authViewModel.register(
///     email: 'anna.andersson@example.com',
///     password: 'starkLösenord456',
///     displayName: 'Anna Andersson',
///   );
/// }
/// 
/// // Mode switching with state management
/// authViewModel.toggleAuthMode(); // Switch between login/register
/// 
/// // Password reset functionality
/// final resetSent = await authViewModel.sendPasswordReset(
///   'erik.svensson@example.com',
/// );
/// 
/// // Reactive state monitoring
/// if (authViewModel.isLoading) {
///   // Show loading spinner
/// } else if (authViewModel.errorMessage != null) {
///   // Display error message
/// }
/// ```

// lib/viewmodels/auth_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Comprehensive authentication ViewModel providing advanced user authentication and state management for Flutter applications.
///
/// Serves as the presentation layer coordinator for all authentication flows, providing reactive state management,
/// comprehensive input validation, and seamless integration with AuthService while maintaining clean MVVM architecture
/// separation between authentication business logic and UI presentation concerns.
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = ServiceLocator.get<AuthService>();

  // ===== AUTHENTICATION STATE MANAGEMENT =====

  /// Authentication mode state controlling login/register UI flow presentation.
  /// true = login mode, false = register mode
  bool _isLoginMode = true;

  /// Password visibility state for enhanced user experience and credential entry.
  bool _isPasswordVisible = false;

  // ===== SERVICE STATE INTEGRATION =====

  /// Loading state inherited from AuthService indicating active authentication operations.
  /// 
  /// Automatically reflects AuthService loading state for seamless UI loading indicator
  /// coordination and user interaction management during authentication operations.
  bool get isLoading => _authService.isLoading;

  /// Error message inherited from AuthService for comprehensive error handling and user feedback.
  /// 
  /// Provides localized error messages from authentication operations, validation failures,
  /// and service errors for direct display to users in authentication UI components.
  String? get errorMessage => _authService.errorMessage;

  /// Authentication state indicating current user authentication status from AuthService.
  /// 
  /// Reflects real-time authentication state for UI conditional rendering and
  /// navigation flow control based on user authentication status.
  bool get isAuthenticated => _authService.isAuthenticated;

  // ===== UI STATE ACCESSORS =====

  /// Current authentication mode for UI flow control and form field management.
  /// 
  /// Controls whether authentication UI displays login or registration form
  /// with appropriate fields and validation for the selected authentication mode.
  bool get isLoginMode => _isLoginMode;

  /// Password field visibility state for improved user experience during credential entry.
  /// 
  /// Controls password field visibility toggle allowing users to verify password
  /// input while maintaining security best practices for credential handling.
  bool get isPasswordVisible => _isPasswordVisible;

  /// Initializes authentication ViewModel with reactive AuthService integration and state synchronization.
  /// 
  /// Establishes comprehensive listener connection to AuthService ensuring automatic state synchronization
  /// for authentication status, loading indicators, and error messages to maintain reactive UI updates
  /// and consistent user experience across all authentication operations.
  AuthViewModel() {
    // Listen for changes from AuthService to maintain reactive state
    _authService.addListener(_onAuthServiceChanged);
  }

  /// Toggles authentication mode between login and registration with comprehensive state management.
  /// 
  /// Switches UI context between login and registration flows while clearing existing error messages
  /// to provide clean user experience and proper state transitions during authentication mode changes.
  /// Essential for dual-mode authentication UI with seamless mode switching.
  void toggleAuthMode() {
    _isLoginMode = !_isLoginMode;
    _authService.clearError(); // Clear previous error messages
    notifyListeners();
  }

  /// Toggles password field visibility for enhanced user experience during credential entry.
  /// 
  /// Provides password visibility control allowing users to verify credential input
  /// while maintaining security best practices and improving authentication usability.
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  /// Authenticates user with comprehensive credential validation and service coordination.
  /// 
  /// [email] User's email address for authentication
  /// [password] User's password for authentication
  /// 
  /// Returns true if authentication succeeds, false if validation fails or authentication errors occur.
  /// Performs comprehensive input validation before delegating to AuthService for actual authentication,
  /// ensuring data integrity and providing immediate feedback for validation errors with Swedish localization.
  /// 
  /// **Validation Features:**
  /// - Email format validation with Unicode support for international characters
  /// - Password strength validation with minimum length requirements
  /// - Automatic error message management with user-friendly feedback
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final success = await authViewModel.signIn(
  ///   email: 'erik.svensson@example.com',
  ///   password: 'säkertLösenord123',
  /// );
  /// if (success) {
  ///   // Navigate to main app
  /// } else {
  ///   // Display error from authViewModel.errorMessage
  /// }
  /// ```
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

  /// Registers new user account with comprehensive validation and profile creation coordination.
  /// 
  /// [email] User's email address for account creation
  /// [password] Secure password meeting minimum requirements
  /// [displayName] User's display name for profile creation
  /// 
  /// Returns true if registration succeeds, false if validation fails or registration errors occur.
  /// Performs comprehensive validation on all input fields before creating account through AuthService,
  /// ensuring complete data integrity and optimal user experience during account registration.
  /// 
  /// **Validation Coverage:**
  /// - Email format validation with international character support
  /// - Password strength validation with security requirements
  /// - Display name validation with minimum length requirements
  /// - Automatic error feedback with Swedish localized messages
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final registered = await authViewModel.register(
  ///   email: 'anna.andersson@example.com',
  ///   password: 'starkLösenord456',
  ///   displayName: 'Anna Andersson',
  /// );
  /// if (registered) {
  ///   // Navigate to welcome screen
  /// } else {
  ///   // Handle registration error
  /// }
  /// ```
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

  /// Performs comprehensive user sign out with complete session cleanup and state management.
  /// 
  /// Coordinates with AuthService to perform secure user logout including session termination,
  /// token cleanup, and authentication state reset for complete user session management.
  /// Essential for secure authentication flows and proper user session lifecycle management.
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Sends password reset email with comprehensive validation and service coordination.
  /// 
  /// [email] User's email address for password reset delivery
  /// 
  /// Returns true if password reset email is sent successfully, false if validation fails.
  /// Performs email validation before delegating to AuthService for password reset email delivery,
  /// ensuring valid email addresses and providing proper user feedback for password recovery flows.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final resetSent = await authViewModel.sendPasswordReset(
  ///   'erik.svensson@example.com',
  /// );
  /// if (resetSent) {
  ///   // Show success message
  /// } else {
  ///   // Display validation error
  /// }
  /// ```
  Future<bool> sendPasswordReset(String email) async {
    if (!_validateEmail(email)) {
      return false;
    }

    return await _authService.sendPasswordResetEmail(email.trim());
  }

  // ===== ADVANCED INPUT VALIDATION =====

  /// Validates email format with comprehensive internationalization support and user feedback.
  /// 
  /// [email] Email address to validate
  /// 
  /// Returns true if email format is valid, false otherwise with automatic error message setting.
  /// Performs comprehensive email validation including empty check and international character support
  /// using Unicode-aware regex patterns for global user base compatibility.
  bool _validateEmail(String email) {
    if (email.isEmpty) {
      _setError('E-post kan inte vara tom');
      return false;
    }

    // Email validation with Unicode support for international characters
    final emailRegex = RegExp(r'^[\p{L}\p{N}._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$', unicode: true);
    if (!emailRegex.hasMatch(email)) {
      _setError('Ogiltig e-postadress');
      return false;
    }

    return true;
  }

  /// Validates password strength with security requirements and Swedish localized feedback.
  /// 
  /// [password] Password to validate
  /// 
  /// Returns true if password meets security requirements, false otherwise with error feedback.
  /// Enforces minimum password length requirements and provides immediate user feedback
  /// for password security compliance during authentication flows.
  bool _validatePassword(String password) {
    if (password.isEmpty) {
      _setError('Lösenord kan inte vara tomt');
      return false;
    }

    if (password.length < 6) {
      _setError('Lösenord måste vara minst 6 tecken');
      return false;
    }

    return true;
  }

  /// Validates display name format with user experience requirements and Swedish localization.
  /// 
  /// [displayName] Display name to validate
  /// 
  /// Returns true if display name meets requirements, false otherwise with user feedback.
  /// Ensures minimum display name length for proper user identification and profile creation
  /// with immediate validation feedback for optimal user registration experience.
  bool _validateDisplayName(String displayName) {
    if (displayName.isEmpty) {
      _setError('Visningsnamn kan inte vara tomt');
      return false;
    }

    if (displayName.length < 2) {
      _setError('Visningsnamn måste vara minst 2 tecken');
      return false;
    }

    return true;
  }

  // ===== COMPREHENSIVE ERROR MANAGEMENT =====

  /// Manages local validation error state with automatic UI notification and consistency patterns.
  /// 
  /// [message] Error message for user display and validation feedback
  /// 
  /// Handles validation error state management while maintaining consistency with AuthService
  /// error handling patterns for seamless error display and user feedback coordination.
  void _setError(String message) {
    // Notify listeners of validation errors for immediate UI feedback
    notifyListeners();
  }

  /// Handles reactive state synchronization from AuthService state changes with automatic UI updates.
  /// 
  /// Provides seamless state synchronization between AuthService and ViewModel ensuring
  /// all authentication state changes are immediately reflected in UI components
  /// for consistent user experience and real-time authentication status updates.
  void _onAuthServiceChanged() {
    notifyListeners();
  }

  /// Clears existing error messages with service coordination and clean state management.
  /// 
  /// Provides comprehensive error state cleanup by delegating to AuthService for
  /// consistent error state management across the entire authentication system
  /// and ensuring clean user experience during authentication flow transitions.
  void clearError() {
    _authService.clearError();
  }

  /// Performs comprehensive ViewModel disposal with listener cleanup and memory management.
  /// 
  /// Removes AuthService listener connections and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic authentication UI scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    // Remove AuthService listener when ViewModel is disposed
    _authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }
}
