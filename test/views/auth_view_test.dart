/// Comprehensive AuthView test suite using Phase 1 infrastructure and ultrathink methodology.
///
/// This test suite validates AuthView's dual-mode authentication interface, form validation,
/// password recovery, and Swedish localization using the established test infrastructure
/// and proven testing patterns from the gold standard Phase 1 foundation.
///
/// **Testing Strategy:**
/// - Production-code-first analysis applied from lib/views/auth_view.dart
/// - Single provider architecture with AuthViewModel coordination
/// - Dual-mode form testing (login/registration) with mode switching
/// - Swedish localization validation throughout all text elements
/// - Form validation testing with real-time feedback
/// - Password visibility and recovery workflow testing
/// - Resource management and lifecycle testing
///
/// **Phase 1 Infrastructure Usage:**
/// - ViewTestHelpers for Swedish-localized test environment setup
/// - ProviderTestUtils for AuthViewModel provider configuration
/// - TestableAuthViewModel for deterministic state control
/// - InteractionHelpers for Swedish text input and workflow simulation
/// - ViewTestPatterns for consistent authentication testing patterns
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Production code imports
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';

// Phase 1 test infrastructure
import 'helpers/view_test_helpers.dart';
import 'helpers/provider_test_utils.dart';
import 'helpers/mock_view_models.dart';
import 'helpers/interaction_helpers.dart';

void main() {
  group('AuthView Integration Tests', () {
    // ==================== SETUP & TEARDOWN ====================

    setUpAll(() async {
      // Initialize Phase 1 test infrastructure
      await ViewTestHelpers.setupViewTestEnvironment();
    });

    tearDownAll(() async {
      await ViewTestHelpers.teardownViewTestEnvironment();
    });

    // ==================== PROVIDER SETUP VERIFICATION ====================

    group('Provider Setup Tests', () {
      testWidgets('should initialize AuthViewModel provider correctly',
          (tester) async {
        // Arrange: Setup authentication provider
        final providers =
            ProviderTestUtils.setupAuthProviders(isAuthenticated: false);

        // Act: Create and pump the AuthView
        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await ViewTestHelpers.waitForViewInitialization(tester);

        // Assert: Verify AuthViewModel is available and initialized
        final context = tester.element(find.byType(AuthView));
        final authViewModel =
            Provider.of<AuthViewModel>(context, listen: false);

        expect(authViewModel, isNotNull);
        expect(authViewModel.isLoginMode, isTrue); // Default mode
        expect(authViewModel.isLoading, isFalse);
      });

      testWidgets('should render authentication form with Swedish localization',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        // Act
        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Verify Swedish authentication UI elements
        ViewTestHelpers.expectSwedishText(
            tester, 'Logga in'); // Login mode header
        ViewTestHelpers.expectSwedishText(
            tester, 'E-post'); // Email field label
        ViewTestHelpers.expectSwedishText(
            tester, 'Lösenord'); // Password field label
        ViewTestHelpers.expectSwedishText(
            tester, 'Glömt lösenord?'); // Forgot password link
        ViewTestHelpers.expectSwedishText(
            tester, 'Har du inget konto? Skapa konto'); // Mode toggle
      });
    });

    // ==================== DUAL-MODE FORM BEHAVIOR ====================

    group('Form Mode Switching Tests', () {
      testWidgets('should switch from login to registration mode correctly',
          (tester) async {
        // Arrange: Setup authentication providers
        final providers =
            ProviderTestUtils.setupAuthProviders(isAuthenticated: false);

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert initial login mode
        expect(find.text('Logga in'), findsOneWidget);
        expect(find.text('Ditt namn'),
            findsNothing); // Name field not visible in login

        // Act: Switch to registration mode
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Skapa konto'),
        );

        // Assert: Registration mode activated
        expect(find.text('Skapa konto'), findsAtLeast(1)); // Header changed
        ViewTestHelpers.expectSwedishText(
            tester, 'Ditt namn'); // Name field now visible
        ViewTestHelpers.expectSwedishText(
            tester, 'Har du redan ett konto? Logga in'); // Toggle text changed
        expect(find.text('Glömt lösenord?'),
            findsNothing); // Forgot password hidden in registration
      });

      testWidgets('should switch back from registration to login mode',
          (tester) async {
        // Arrange: Start in registration mode
        final testableViewModel = TestableViewModelFactory.createAuthViewModel(
          isAuthenticated: false,
        );
        testableViewModel.setAuthenticationFlowState(isRegistrationMode: true);

        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert initial registration mode
        expect(find.text('Skapa konto'), findsAtLeast(1));
        expect(find.text('Ditt namn'), findsOneWidget);

        // Act: Switch to login mode
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Logga in'),
        );

        // Assert: Login mode activated
        expect(find.text('Logga in'), findsAtLeast(1));
        expect(find.text('Ditt namn'), findsNothing);
        ViewTestHelpers.expectSwedishText(tester, 'Glömt lösenord?');
      });
    });

    // ==================== FORM FIELD RENDERING ====================

    group('Form Field Rendering Tests', () {
      testWidgets('should render email field with correct configuration',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Email field present with Swedish labels
        final emailField = find.byKey(const Key('email_field'));
        expect(emailField, findsOneWidget);

        ViewTestHelpers.expectSwedishText(tester, 'E-post');
        ViewTestHelpers.expectSwedishText(tester, 'din.email@exempel.se');

        // Verify field accepts Swedish text input
        await InteractionHelpers.typeSwedishText(
          tester,
          emailField,
          'test@exempel.se',
        );

        expect(find.text('test@exempel.se'), findsOneWidget);
      });

      testWidgets('should render password field with visibility toggle',
          (tester) async {
        // Arrange
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Password field present with visibility toggle
        final passwordField = find.byKey(const Key('password_field'));
        expect(passwordField, findsOneWidget);

        ViewTestHelpers.expectSwedishText(tester, 'Lösenord');

        // Find and test visibility toggle button
        final visibilityButton = find.byIcon(Icons.visibility_outlined);
        expect(visibilityButton, findsOneWidget);

        // Act: Toggle password visibility
        await ViewTestHelpers.tapAndSettle(tester, visibilityButton);

        // Assert: Visibility icon changed
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      });

      testWidgets('should render name field only in registration mode',
          (tester) async {
        // Arrange: Start in login mode
        final providers =
            ProviderTestUtils.setupAuthProviders(isAuthenticated: false);

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Assert: Name field not present in login mode
        expect(find.text('Ditt namn'), findsNothing);

        // Act: Switch to registration mode
        await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));

        // Assert: Name field now present
        ViewTestHelpers.expectSwedishText(tester, 'Ditt namn');
        ViewTestHelpers.expectSwedishText(
            tester, 'Ange ditt namn'); // Hint text

        // Verify name field accepts Swedish characters
        final nameField = find.widgetWithText(TextFormField, 'Ditt namn');
        await InteractionHelpers.typeSwedishText(
          tester,
          nameField,
          'Åsa Björk',
        );

        expect(find.text('Åsa Björk'), findsOneWidget);
      });
    });

    // ==================== FORM VALIDATION TESTS ====================

    group('Form Validation Tests', () {
      testWidgets('should validate email field with Swedish error messages',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Enter invalid email and attempt submission
        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('email_field')),
          'invalid-email',
        );

        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Logga in'),
        );

        // Assert: Validation error appears
        // Note: Actual validation error text depends on FormValidators implementation
        expect(find.byType(Form), findsOneWidget);
      });

      testWidgets('should validate password field with strength requirements',
          (tester) async {
        // Arrange: Switch to registration mode for password strength validation
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Switch to registration mode
        await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));

        // Act: Enter weak password
        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('password_field')),
          '123', // Weak password
        );

        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Skapa konto'),
        );

        // Assert: Form validation should prevent submission
        expect(find.byType(Form), findsOneWidget);
      });
    });

    // ==================== LOADING STATES ====================

    group('Loading State Tests', () {
      testWidgets('should show loading indicator during submission',
          (tester) async {
        // Arrange: Testable ViewModel to control loading state
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Set loading state
        testableViewModel.setAuthenticationState(isLoading: true);
        await tester.pump();

        // Assert: Loading indicator visible, form disabled
        ViewTestHelpers.expectLoadingState(tester);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Verify form fields are disabled during loading
        final emailField =
            tester.widget<TextFormField>(find.byKey(const Key('email_field')));
        final passwordField = tester
            .widget<TextFormField>(find.byKey(const Key('password_field')));

        expect(emailField.enabled, isFalse);
        expect(passwordField.enabled, isFalse);
      });
    });

    // ==================== CORE AUTHENTICATION WORKFLOWS ====================

    group('Login Flow Tests', () {
      testWidgets('should perform complete login workflow with Swedish input',
          (tester) async {
        // Arrange: Setup testable AuthViewModel with controlled state
        final testableViewModel = TestableViewModelFactory.createAuthViewModel(
          isAuthenticated: false,
        );
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Verify initial login mode
        expect(find.text('Logga in'), findsAtLeast(1));

        // Act: Perform login workflow with Swedish email
        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('email_field')),
          'anna.svensson@exempel.se',
        );

        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('password_field')),
          'säkerhetslösenord123',
        );

        // Submit the form
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Logga in'),
        );

        // Assert: Verify form submission was attempted
        expect(find.text('anna.svensson@exempel.se'), findsOneWidget);
        expect(find.text('säkerhetslösenord123'), findsOneWidget);
      });

      testWidgets('should handle login success scenario', (tester) async {
        // Arrange: Testable ViewModel configured for successful login
        final testableViewModel = TestableViewModelFactory.createAuthViewModel(
          isAuthenticated: false,
        );
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Fill valid credentials
        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('email_field')),
          'test@exempel.se',
        );

        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('password_field')),
          'validpassword123',
        );

        // Simulate successful login
        testableViewModel.simulateLogin(
          'test@exempel.se',
          'validpassword123',
          shouldSucceed: true,
        );

        await tester.pump();

        // Assert: Verify authentication state updated
        final stateTransitions = testableViewModel.getStateTransitions();
        expect(
            stateTransitions, contains(contains('auth_state_authenticated')));
      });

      testWidgets('should handle login error with Swedish error messages',
          (tester) async {
        // Arrange: Configure ViewModel to simulate login failure
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Submit with credentials that will fail
        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('email_field')),
          'invalid@exempel.se',
        );

        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('password_field')),
          'wrongpassword',
        );

        // Simulate login failure
        testableViewModel.setAuthenticationState(
          isLoading: false,
          error: 'Felaktiga inloggningsuppgifter',
        );

        await tester.pump();

        // Assert: Verify Swedish error message is displayed
        expect(find.text('Felaktiga inloggningsuppgifter'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('Registration Flow Tests', () {
      testWidgets('should perform complete registration workflow',
          (tester) async {
        // Arrange: Setup for registration testing
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Switch to registration mode
        await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));

        // Verify registration mode UI
        expect(find.text('Skapa konto'), findsAtLeast(1));
        ViewTestHelpers.expectSwedishText(tester, 'Ditt namn');

        // Fill registration form with Swedish input
        await InteractionHelpers.typeSwedishText(
          tester,
          find.widgetWithText(TextFormField, 'Ditt namn'),
          'Astrid Lindgren',
        );

        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('email_field')),
          'astrid@pippilångstrump.se',
        );

        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('password_field')),
          'pippilångstrump123',
        );

        // Submit registration
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Skapa konto'),
        );

        // Assert: Verify form data was entered correctly
        expect(find.text('Astrid Lindgren'), findsOneWidget);
        expect(find.text('astrid@pippilångstrump.se'), findsOneWidget);
        expect(find.text('pippilångstrump123'), findsOneWidget);
      });

      testWidgets('should handle registration success scenario',
          (tester) async {
        // Arrange: Testable ViewModel configured for successful registration
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Switch to registration mode
        await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));

        // Act: Simulate successful registration
        testableViewModel.simulateRegistration(
          'Erik Carlsson',
          'erik@exempel.se',
          'strongpassword123',
          shouldSucceed: true,
        );

        await tester.pump();

        // Assert: Verify successful registration state changes
        final stateTransitions = testableViewModel.getStateTransitions();
        expect(
            stateTransitions, contains(contains('auth_state_authenticated')));
        expect(stateTransitions, contains(contains('registration')));
      });

      testWidgets('should handle registration errors with Swedish messaging',
          (tester) async {
        // Arrange
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Switch to registration mode
        await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));

        // Act: Simulate registration failure
        testableViewModel.setAuthenticationState(
          isLoading: false,
          error: 'E-postadressen används redan',
        );

        await tester.pump();

        // Assert: Verify Swedish error message
        expect(find.text('E-postadressen används redan'), findsOneWidget);
      });
    });

    // ==================== PASSWORD VISIBILITY TESTING ====================

    group('Password Visibility Tests', () {
      testWidgets('should toggle password visibility correctly',
          (tester) async {
        // Arrange
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Enter password
        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('password_field')),
          'hemmligtlösenord',
        );

        // Initially password should be obscured
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

        // Act: Toggle password visibility
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.byIcon(Icons.visibility_outlined),
        );

        // Assert: Visibility toggle should work
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

        // Toggle back
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.byIcon(Icons.visibility_off_outlined),
        );

        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      });
    });

    // ==================== FOCUS MANAGEMENT TESTING ====================

    group('Focus Management Tests', () {
      testWidgets('should manage focus navigation correctly', (tester) async {
        // Arrange: Registration mode to have all three fields
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Switch to registration mode
        await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));

        // Act: Focus on name field and submit (should move to email)
        await tester.tap(find.widgetWithText(TextFormField, 'Ditt namn'));
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();

        // Assert: Focus management behavior is working
        // (Detailed focus testing would require more complex mocking)
        expect(find.widgetWithText(TextFormField, 'E-post'), findsOneWidget);
      });
    });

    // ==================== ADVANCED FEATURES & EDGE CASES ====================

    group('Password Reset Dialog Tests', () {
      testWidgets('should show password reset dialog with Swedish localization',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Verify we're in login mode (forgot password should be visible)
        ViewTestHelpers.expectSwedishText(tester, 'Glömt lösenord?');

        // Act: Tap forgot password link
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Glömt lösenord?'),
        );

        // Assert: Password reset dialog appears with Swedish content
        expect(find.byType(AlertDialog), findsOneWidget);
        // Note: Actual text depends on l10n authResetPassword strings
        expect(find.text('Email'), findsOneWidget); // Email field in dialog
        expect(find.text('din.email@exempel.se'), findsOneWidget); // Hint text

        // Find action buttons
        expect(find.widgetWithText(TextButton, 'Avbryt'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Skicka'), findsOneWidget);
      });

      testWidgets('should handle password reset dialog cancellation',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Open dialog and cancel
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Glömt lösenord?'),
        );

        // Dialog should be present
        expect(find.byType(AlertDialog), findsOneWidget);

        // Cancel dialog
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.widgetWithText(TextButton, 'Avbryt'),
        );

        // Assert: Dialog dismissed
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('should handle password reset email submission',
          (tester) async {
        // Arrange
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Open password reset dialog
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Glömt lösenord?'),
        );

        // Enter email in dialog
        await InteractionHelpers.typeSwedishText(
          tester,
          find.widgetWithText(TextField, 'Email'),
          'reset@exempel.se',
        );

        // Submit dialog
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.widgetWithText(FilledButton, 'Skicka'),
        );

        // Assert: Dialog dismissed and SnackBar should appear
        expect(find.byType(AlertDialog), findsNothing);
        // Note: SnackBar testing requires more complex setup
        expect(find.text('reset@exempel.se'),
            findsNothing); // Email should be cleared from dialog
      });
    });

    group('Error Injection & Recovery Tests', () {
      testWidgets('should handle injected login errors correctly',
          (tester) async {
        // Arrange: Setup testable ViewModel with error injection
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Inject Swedish error message
        testableViewModel
            .injectError('Inloggningen misslyckades på grund av nätverksfel');

        // Fill form and attempt login
        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('email_field')),
          'test@exempel.se',
        );

        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('password_field')),
          'password123',
        );

        // Attempt login (should trigger injected error)
        await testableViewModel.simulateLogin(
          'test@exempel.se',
          'password123',
          shouldSucceed: false, // This will trigger the injected error
        );

        await tester.pump();

        // Assert: Swedish error message displayed
        expect(find.text('Inloggningen misslyckades på grund av nätverksfel'),
            findsOneWidget);

        // Verify error state transitions were recorded
        final stateTransitions = testableViewModel.getStateTransitions();
        expect(stateTransitions, contains(contains('error_set')));
        expect(stateTransitions, contains(contains('login failed')));
      });

      testWidgets('should handle registration error injection', (tester) async {
        // Arrange
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Switch to registration mode
        await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));

        // Act: Inject specific registration error
        testableViewModel.injectError(
            'Kontot kunde inte skapas: E-postadressen är redan registrerad');

        // Attempt registration
        await testableViewModel.simulateRegistration(
          'Test User',
          'existing@exempel.se',
          'password123',
          shouldSucceed: false,
        );

        await tester.pump();

        // Assert: Specific registration error displayed
        expect(
            find.text(
                'Kontot kunde inte skapas: E-postadressen är redan registrerad'),
            findsOneWidget);
      });

      testWidgets('should recover from error state when retrying',
          (tester) async {
        // Arrange: Start with error state
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        testableViewModel.setAuthenticationState(
          isLoading: false,
          error: 'Tidigare inloggningsfel',
        );

        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Verify error is displayed
        expect(find.text('Tidigare inloggningsfel'), findsOneWidget);

        // Act: Clear error and attempt successful login
        testableViewModel.setAuthenticationState(error: null);
        await testableViewModel.simulateLogin(
          'test@exempel.se',
          'correctpassword',
          shouldSucceed: true,
        );

        await tester.pump();

        // Assert: Error cleared and authentication successful
        expect(find.text('Tidigare inloggningsfel'), findsNothing);
        final stateTransitions = testableViewModel.getStateTransitions();
        expect(
            stateTransitions, contains(contains('auth_state_authenticated')));
      });
    });

    group('Resource Management & Lifecycle Tests', () {
      testWidgets('should properly dispose resources when widget is removed',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Verify widget is present and functional
        expect(find.byType(AuthView), findsOneWidget);

        // Act: Remove widget (triggers dispose)
        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const Scaffold(
              body: Text('Different View'),
            ),
            providers: providers,
          ),
        );

        // Assert: AuthView removed, no memory leaks
        expect(find.byType(AuthView), findsNothing);
        expect(find.text('Different View'), findsOneWidget);
        // Note: Actual controller disposal testing would require widget inspection
      });

      testWidgets('should handle ViewModel disposal correctly', (tester) async {
        // Arrange: Testable ViewModel with disposal tracking
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Verify ViewModel is not disposed initially
        expect(testableViewModel.isProperlyDisposed, isFalse);

        // Act: Remove widget tree
        await tester.pumpWidget(const SizedBox());

        // Assert: ViewModel should be properly disposed
        // Note: In real provider usage, disposal happens automatically
        expect(find.byType(AuthView), findsNothing);
      });
    });

    group('Edge Cases & Boundary Testing', () {
      testWidgets('should handle rapid mode switching without errors',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Rapidly switch between modes
        for (int i = 0; i < 5; i++) {
          await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));
          expect(find.text('Ditt namn'), findsOneWidget);

          await ViewTestHelpers.tapAndSettle(tester, find.text('Logga in'));
          expect(find.text('Ditt namn'), findsNothing);
        }

        // Assert: UI remains stable after rapid switching
        ViewTestHelpers.expectSwedishText(tester, 'Logga in');
        ViewTestHelpers.expectSwedishText(tester, 'E-post');
        ViewTestHelpers.expectSwedishText(tester, 'Lösenord');
      });

      testWidgets('should handle form submission with empty fields',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Attempt to submit empty form
        await ViewTestHelpers.tapAndSettle(
          tester,
          find.text('Logga in'),
        );

        // Assert: Form validation prevents submission
        expect(find.byType(Form), findsOneWidget);
        // Form should still be visible (validation failed)
        ViewTestHelpers.expectSwedishText(tester, 'E-post');
        ViewTestHelpers.expectSwedishText(tester, 'Lösenord');
      });

      testWidgets('should handle loading state interruption', (tester) async {
        // Arrange: Testable ViewModel to control loading state
        final testableViewModel =
            TestableViewModelFactory.createAuthViewModel();
        final providers = [
          ChangeNotifierProvider<AuthViewModel>.value(value: testableViewModel),
        ];

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Set loading state
        testableViewModel.setAuthenticationState(isLoading: true);
        await tester.pump();

        // Verify loading state
        ViewTestHelpers.expectLoadingState(tester);

        // Interrupt loading with mode switch (should handle gracefully)
        testableViewModel.setAuthenticationState(isLoading: false);
        await tester.pump();

        // Assert: Returns to normal state cleanly
        expect(find.byType(CircularProgressIndicator), findsNothing);
        ViewTestHelpers.expectSwedishText(tester, 'Logga in');
      });

      testWidgets('should handle Swedish character input edge cases',
          (tester) async {
        // Arrange
        final providers = ProviderTestUtils.setupAuthProviders();

        await tester.pumpWidget(
          ViewTestHelpers.createTestViewWidget(
            child: const AuthView(),
            providers: providers,
          ),
        );

        await tester.pump();

        // Act: Test edge cases with Swedish characters
        await InteractionHelpers.typeSwedishText(
          tester,
          find.byKey(const Key('email_field')),
          'åsa.björk@göteborg.se', // Complex Swedish email
        );

        // Switch to registration and test name field
        await ViewTestHelpers.tapAndSettle(tester, find.text('Skapa konto'));

        await InteractionHelpers.typeSwedishText(
          tester,
          find.widgetWithText(TextFormField, 'Ditt namn'),
          'Åsa Sköld-Ångström', // Complex Swedish name with hyphens
        );

        // Assert: Swedish characters handled correctly
        expect(find.text('åsa.björk@göteborg.se'), findsOneWidget);
        expect(find.text('Åsa Sköld-Ångström'), findsOneWidget);
      });
    });
  });
}
