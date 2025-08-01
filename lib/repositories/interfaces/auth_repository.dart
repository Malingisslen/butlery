import 'package:firebase_auth/firebase_auth.dart';

/// Repository interface for user authentication and account management operations.
///
/// This interface defines the contract for authentication-related data operations
/// including user login, registration, password management, and session handling.
/// It abstracts Firebase Authentication operations and provides a consistent API
/// for authentication functionality throughout the application.
///
/// **Key Authentication Areas:**
/// - **User Registration**: Create new user accounts with email/password
/// - **User Authentication**: Sign in existing users with credentials  
/// - **Session Management**: Handle user sessions and authentication state
/// - **Password Operations**: Reset passwords and manage account security
/// - **Profile Management**: Update user display names and profile information
/// - **Account Operations**: Delete accounts and manage user lifecycle
///
/// **Authentication Flow Integration:**
/// This repository integrates with Firebase Authentication to provide secure
/// user authentication while maintaining a clean separation between authentication
/// logic and UI components. It supports reactive authentication state monitoring
/// through streams for real-time UI updates.
///
/// **Security Considerations:**
/// All authentication operations are handled securely through Firebase Auth,
/// ensuring proper credential validation, secure token management, and protection
/// against common authentication vulnerabilities.
///
/// **Usage Examples:**
/// ```dart
/// final authRepo = ServiceLocator.get<AuthRepository>();
/// 
/// // User registration
/// try {
///   final credential = await authRepo.createUser(email, password);
///   await authRepo.updateDisplayName(credential.user!, displayName);
/// } catch (e) {
///   handleRegistrationError(e);
/// }
/// 
/// // User login
/// final loginResult = await authRepo.login(email, password);
/// if (loginResult.user != null) {
///   navigateToMainApp();
/// }
/// 
/// // Monitor auth state
/// authRepo.authStateChanges().listen((user) {
///   if (user == null) {
///     navigateToLogin();
///   } else {
///     navigateToMainApp();
///   }
/// });
/// ```
abstract class AuthRepository {
  /// Authenticates a user with email and password credentials.
  ///
  /// Attempts to sign in an existing user using their email address and password.
  /// Returns a [UserCredential] containing the authenticated user information
  /// and authentication tokens. This method validates credentials against
  /// Firebase Authentication and establishes a user session.
  ///
  /// [email] The user's email address for authentication
  /// [password] The user's password for authentication
  ///
  /// Returns [UserCredential] with authenticated user data and tokens
  ///
  /// Throws [FirebaseAuthException] with specific error codes:
  /// - `user-not-found`: No user exists with the provided email
  /// - `wrong-password`: The password is incorrect
  /// - `invalid-email`: The email address is malformed
  /// - `user-disabled`: The user account has been disabled
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final credential = await authRepo.login(email, password);
  ///   print('Welcome back, ${credential.user?.displayName}!');
  /// } on FirebaseAuthException catch (e) {
  ///   handleAuthError(e.code);
  /// }
  /// ```
  Future<UserCredential> login(String email, String password);

  /// Creates a new user account with email and password.
  ///
  /// Registers a new user in Firebase Authentication with the provided credentials.
  /// This method creates a new user account, generates authentication tokens, and
  /// establishes an initial user session. The user will be automatically signed
  /// in after successful registration.
  ///
  /// [email] The email address for the new user account
  /// [password] The password for the new user account (must meet security requirements)
  ///
  /// Returns [UserCredential] with the newly created user data and tokens
  ///
  /// Throws [FirebaseAuthException] with specific error codes:
  /// - `email-already-in-use`: An account already exists with this email
  /// - `invalid-email`: The email address is malformed
  /// - `weak-password`: The password is too weak
  /// - `operation-not-allowed`: Email/password accounts are not enabled
  ///
  /// **Security Note:**
  /// Password should be validated on the client side before calling this method
  /// to ensure it meets minimum security requirements.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final credential = await authRepo.createUser(email, password);
  ///   await authRepo.updateDisplayName(credential.user!, displayName);
  /// } on FirebaseAuthException catch (e) {
  ///   showRegistrationError(e.code);
  /// }
  /// ```
  Future<UserCredential> createUser(String email, String password);

  /// Updates the display name for the specified user.
  ///
  /// Modifies the display name of the provided Firebase [user]. This operation
  /// updates the user's profile information in Firebase Authentication and may
  /// also trigger profile synchronization with other parts of the application.
  ///
  /// [user] The Firebase User instance to update (typically the current user)
  /// [displayName] The new display name to set for the user
  ///
  /// Throws [FirebaseAuthException] if the update operation fails
  /// Throws [ArgumentError] if the user is null or displayName is empty
  ///
  /// **Profile Synchronization:**
  /// This method only updates the Firebase Auth profile. Additional user profile
  /// data should be updated through the UserRepository for complete synchronization.
  ///
  /// Example:
  /// ```dart
  /// final currentUser = authRepo.currentUser;
  /// if (currentUser != null) {
  ///   await authRepo.updateDisplayName(currentUser, 'New Display Name');
  ///   print('Display name updated successfully');
  /// }
  /// ```
  Future<void> updateDisplayName(User user, String displayName);

  /// Signs in a user with email and password credentials (alternative method).
  ///
  /// Alternative sign-in method that provides a different signature for authentication.
  /// This method performs the same authentication as [login] but with named parameters
  /// and no return value, focusing on the side effect of establishing authentication.
  ///
  /// [email] The user's email address for authentication
  /// [password] The user's password for authentication
  ///
  /// Throws [FirebaseAuthException] with authentication error details
  ///
  /// **Note:**
  /// This method duplicates functionality with [login]. Consider using [login]
  /// instead as it provides the UserCredential return value for additional context.
  ///
  /// Example:
  /// ```dart
  /// await authRepo.signIn(email: userEmail, password: userPassword);
  /// final user = authRepo.currentUser; // Check result via currentUser
  /// ```
  Future<void> signIn({
    required String email,
    required String password,
  });

  /// Signs out the currently authenticated user.
  ///
  /// Terminates the current user session and clears authentication tokens.
  /// After this operation completes, [currentUser] will return null and
  /// [authStateChanges] will emit a null user state. This method should be
  /// called when users explicitly log out or when session cleanup is required.
  ///
  /// Throws [FirebaseAuthException] if the sign-out operation fails
  ///
  /// **Side Effects:**
  /// - Clears authentication tokens
  /// - Triggers auth state change listeners
  /// - May clear cached user data depending on implementation
  ///
  /// Example:
  /// ```dart
  /// await authRepo.signOut();
  /// // User is now signed out, redirect to login screen
  /// navigateToLogin();
  /// ```
  Future<void> signOut();

  /// Sends a password reset email to the specified email address.
  ///
  /// Initiates the password reset process by sending an email with reset
  /// instructions to the provided email address. The user will receive an
  /// email containing a secure link to reset their password through Firebase
  /// Authentication's web interface.
  ///
  /// [email] The email address to send the password reset email to
  ///
  /// Throws [FirebaseAuthException] with specific error codes:
  /// - `user-not-found`: No user exists with the provided email
  /// - `invalid-email`: The email address is malformed
  ///
  /// **User Experience Note:**
  /// This method completes successfully even if the email doesn't exist in the
  /// system (for security reasons). Always inform users to check their email
  /// including spam folders.
  ///
  /// Example:
  /// ```dart
  /// await authRepo.sendPasswordResetEmail(userEmail);
  /// showMessage('Password reset email sent. Please check your inbox.');
  /// ```
  Future<void> sendPasswordResetEmail(String email);

  /// Permanently deletes the currently authenticated user account.
  ///
  /// Irreversibly removes the current user's account from Firebase Authentication
  /// and potentially triggers cleanup of associated user data throughout the
  /// application. This is a destructive operation that cannot be undone.
  ///
  /// Throws [FirebaseAuthException] with specific error codes:
  /// - `requires-recent-login`: The user must re-authenticate before deletion
  /// - `no-current-user`: No user is currently signed in
  ///
  /// **Critical Warning:**
  /// This operation permanently deletes the user account and cannot be reversed.
  /// Ensure proper user confirmation and consider data backup before deletion.
  ///
  /// **Data Cleanup:**
  /// Account deletion should trigger cleanup of associated user data in Firestore
  /// and other services. Consider implementing cascade deletion patterns.
  ///
  /// Example:
  /// ```dart
  /// final confirmed = await showDeleteConfirmation();
  /// if (confirmed) {
  ///   try {
  ///     await authRepo.deleteCurrentUser();
  ///     navigateToWelcomeScreen();
  ///   } on FirebaseAuthException catch (e) {
  ///     if (e.code == 'requires-recent-login') {
  ///       promptReauthentication();
  ///     }
  ///   }
  /// }
  /// ```
  Future<void> deleteCurrentUser();

  /// Gets the currently authenticated user, if any.
  ///
  /// Returns the Firebase [User] instance for the currently signed-in user,
  /// or null if no user is authenticated. This is a synchronous operation that
  /// provides immediate access to the current authentication state.
  ///
  /// Returns the current [User] or null if not authenticated
  ///
  /// **Usage Note:**
  /// This getter provides the current state but doesn't listen for changes.
  /// Use [authStateChanges] for reactive authentication state monitoring.
  ///
  /// Example:
  /// ```dart
  /// final user = authRepo.currentUser;
  /// if (user != null) {
  ///   print('Current user: ${user.email}');
  ///   showAuthenticatedUI();
  /// } else {
  ///   showLoginPrompt();
  /// }
  /// ```
  User? get currentUser;

  /// Signs out the currently authenticated user (alias for signOut).
  ///
  /// Alternative method name for [signOut] that provides more intuitive naming
  /// for logout operations. Performs identical functionality to [signOut] by
  /// terminating the current user session and clearing authentication tokens.
  ///
  /// **Note:**
  /// This method duplicates [signOut] functionality. Consider standardizing
  /// on one method name to avoid confusion in the codebase.
  ///
  /// Example:
  /// ```dart
  /// await authRepo.logout();
  /// navigateToLoginScreen();
  /// ```
  Future<void> logout();

  /// Retrieves the currently signed-in user (method variant).
  ///
  /// Method variant of [currentUser] getter that returns the same Firebase
  /// [User] instance for the currently authenticated user, or null if no
  /// user is signed in. This provides an alternative method-based API.
  ///
  /// Returns the current [User] or null if not authenticated
  ///
  /// **Note:**
  /// This method duplicates [currentUser] getter functionality. Consider
  /// using the getter form for consistency and brevity.
  ///
  /// Example:
  /// ```dart
  /// final user = authRepo.getCurrentUser();
  /// if (user != null) {
  ///   handleAuthenticatedUser(user);
  /// }
  /// ```
  User? getCurrentUser();

  /// Gets the unique identifier of the currently authenticated user.
  ///
  /// Returns the UID (unique identifier) of the current Firebase user, or null
  /// if no user is authenticated. This is a common operation for accessing the
  /// current user's identifier without needing the full User object.
  ///
  /// Returns the current user's UID or null if not authenticated
  ///
  /// **Performance Note:**
  /// This is a lightweight operation that extracts the UID from the current
  /// user context without additional network requests.
  ///
  /// Example:
  /// ```dart
  /// final userId = authRepo.currentUserId;
  /// if (userId != null) {
  ///   final userProfile = await userRepo.fetchProfile(userId);
  ///   displayUserProfile(userProfile);
  /// }
  /// ```
  String? get currentUserId;

  /// Provides a stream of authentication state changes.
  ///
  /// Returns a [Stream] that emits the current [User] whenever the authentication
  /// state changes. This includes sign-in, sign-out, and token refresh events.
  /// The stream emits null when no user is authenticated and a [User] instance
  /// when a user is signed in.
  ///
  /// Returns [Stream<User?>] that emits authentication state changes
  ///
  /// **Reactive Authentication:**
  /// This stream is essential for implementing reactive authentication UI that
  /// automatically updates when users sign in or out. It's commonly used in
  /// app initialization and route guards.
  ///
  /// **Stream Characteristics:**
  /// - Emits immediately with current state when subscribed
  /// - Continues emitting throughout the app lifecycle
  /// - Automatically handles token refresh events
  /// - Emits null for unauthenticated state
  ///
  /// Example:
  /// ```dart
  /// authRepo.authStateChanges().listen((user) {
  ///   if (user == null) {
  ///     // User signed out
  ///     navigateToLogin();
  ///     clearUserData();
  ///   } else {
  ///     // User signed in
  ///     initializeUserSession(user);
  ///     navigateToMainApp();
  ///   }
  /// });
  /// ```
  Stream<User?> authStateChanges();
}
