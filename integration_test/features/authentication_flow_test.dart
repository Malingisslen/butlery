import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';
import 'package:butlery/main.dart' as app;
import '../helpers/integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Authentication Flow E2E Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.initializeTestFirebase();
    });
    
    tearDownAll(() async {
      await IntegrationTestHelpers.cleanup();
    });
    
    patrolTest(
      'Complete authentication flow - signup, login, logout',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        // Start at login screen
        expect(find.text('Välkommen till Butlery'), findsOneWidget);
        
        // Navigate to signup
        await $.tap(find.text('Skapa konto'));
        await $.pumpAndSettle();
        
        // Fill signup form
        final testEmail = 'newuser_${DateTime.now().millisecondsSinceEpoch}@test.com';
        await $.enterText(find.byKey(const Key('signup_email_field')), testEmail);
        await $.enterText(find.byKey(const Key('signup_password_field')), 'Test123!');
        await $.enterText(find.byKey(const Key('signup_password_confirm_field')), 'Test123!');
        await $.enterText(find.byKey(const Key('signup_name_field')), 'Test User');
        
        // Accept terms
        await $.tap(find.byKey(const Key('terms_checkbox')));
        await $.pumpAndSettle();
        
        // Submit signup
        await $.tap(find.text('Registrera'));
        await $.pumpAndSettle();
        
        // Wait for email verification screen
        await $.waitUntilVisible(find.text('Verifiera din e-post'));
        expect(find.textContaining(testEmail), findsOneWidget);
        
        // Simulate email verification (in test mode)
        await $.tap(find.text('Jag har verifierat min e-post'));
        await $.pumpAndSettle();
        
        // Should be logged in now
        expect(find.text('Mina recept'), findsOneWidget);
        expect(find.text('Test User'), findsOneWidget);
        
        // Logout
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Logga ut'));
        await $.pumpAndSettle();
        
        // Confirm logout
        await $.tap(find.text('Bekräfta'));
        await $.pumpAndSettle();
        
        // Back at login screen
        expect(find.text('Välkommen till Butlery'), findsOneWidget);
        
        // Login with created account
        await $.enterText(find.byKey(const Key('email_field')), testEmail);
        await $.enterText(find.byKey(const Key('password_field')), 'Test123!');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        // Verify logged in
        expect(find.text('Mina recept'), findsOneWidget);
        expect(find.text('Test User'), findsOneWidget);
      },
    );
    
    patrolTest(
      'Password reset flow',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        // Navigate to password reset
        await $.tap(find.text('Glömt lösenord?'));
        await $.pumpAndSettle();
        
        // Enter email
        await $.enterText(
          find.byKey(const Key('reset_email_field')),
          'test@example.com',
        );
        
        // Send reset email
        await $.tap(find.text('Skicka återställningslänk'));
        await $.pumpAndSettle();
        
        // Verify success message
        expect(find.text('E-post skickad'), findsOneWidget);
        expect(
          find.textContaining('återställningslänk har skickats'),
          findsOneWidget,
        );
        
        // Go back to login
        await $.tap(find.text('Tillbaka till inloggning'));
        await $.pumpAndSettle();
        
        expect(find.text('Logga in'), findsOneWidget);
      },
    );
    
    patrolTest(
      'Social login flows',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        // Test Google login
        await $.tap(find.byKey(const Key('google_login_button')));
        await $.pumpAndSettle();
        
        // In test mode, this should show a mock Google account picker
        await $.waitUntilVisible(find.text('Välj Google-konto'));
        await $.tap(find.text('test@gmail.com'));
        await $.pumpAndSettle();
        
        // Should be logged in
        expect(find.text('Mina recept'), findsOneWidget);
        
        // Logout
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Logga ut'));
        await $.pumpAndSettle();
        await $.tap(find.text('Bekräfta'));
        await $.pumpAndSettle();
        
        // Test Apple login (iOS only)
        if ($.tester.binding.platformDispatcher.platformBrightness == Brightness.dark) {
          await $.tap(find.byKey(const Key('apple_login_button')));
          await $.pumpAndSettle();
          
          // Mock Apple ID flow
          await $.waitUntilVisible(find.text('Sign in with Apple ID'));
          await $.tap(find.text('Continue'));
          await $.pumpAndSettle();
          
          expect(find.text('Mina recept'), findsOneWidget);
        }
      },
    );
    
    patrolTest(
      'Login error handling',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        // Test empty fields
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        expect(find.text('E-post krävs'), findsOneWidget);
        expect(find.text('Lösenord krävs'), findsOneWidget);
        
        // Test invalid email format
        await $.enterText(find.byKey(const Key('email_field')), 'invalid-email');
        await $.enterText(find.byKey(const Key('password_field')), 'password');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        expect(find.text('Ogiltig e-postadress'), findsOneWidget);
        
        // Test wrong credentials
        await $.enterText(find.byKey(const Key('email_field')), 'wrong@example.com');
        await $.enterText(find.byKey(const Key('password_field')), 'wrongpassword');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        await $.waitUntilVisible(find.text('Felaktiga inloggningsuppgifter'));
        
        // Test account locked (after multiple failed attempts)
        for (int i = 0; i < 5; i++) {
          await $.tap(find.text('Logga in'));
          await $.pumpAndSettle();
        }
        
        expect(
          find.textContaining('För många misslyckade försök'),
          findsOneWidget,
        );
      },
    );
    
    patrolTest(
      'Biometric authentication',
      ($) async {
        // First login normally
        await app.main();
        await $.pumpAndSettle();
        
        await $.enterText(find.byKey(const Key('email_field')), 'test@example.com');
        await $.enterText(find.byKey(const Key('password_field')), 'password123');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        // Enable biometric auth
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Inställningar'));
        await $.pumpAndSettle();
        await $.tap(find.text('Säkerhet'));
        await $.pumpAndSettle();
        
        await $.tap(find.byKey(const Key('biometric_switch')));
        await $.pumpAndSettle();
        
        // Mock biometric prompt
        await $.waitUntilVisible(find.text('Använd fingeravtryck för att aktivera'));
        await $.tap(find.text('Bekräfta')); // Mock successful auth
        await $.pumpAndSettle();
        
        expect(find.text('Biometrisk inloggning aktiverad'), findsOneWidget);
        
        // Logout and test biometric login
        await $.tap(find.byType(BackButton));
        await $.pumpAndSettle();
        await $.tap(find.byType(BackButton));
        await $.pumpAndSettle();
        await $.tap(find.byIcon(Icons.menu));
        await $.pumpAndSettle();
        await $.tap(find.text('Logga ut'));
        await $.pumpAndSettle();
        await $.tap(find.text('Bekräfta'));
        await $.pumpAndSettle();
        
        // Should show biometric option
        expect(find.byIcon(Icons.fingerprint), findsOneWidget);
        
        await $.tap(find.byIcon(Icons.fingerprint));
        await $.pumpAndSettle();
        
        // Mock biometric auth
        await $.waitUntilVisible(find.text('Skanna fingeravtryck'));
        await $.tap(find.text('Autentisera')); // Mock successful auth
        await $.pumpAndSettle();
        
        // Should be logged in
        expect(find.text('Mina recept'), findsOneWidget);
      },
    );
    
    patrolTest(
      'Session management and auto-logout',
      ($) async {
        await app.main();
        await $.pumpAndSettle();
        
        // Login
        await $.enterText(find.byKey(const Key('email_field')), 'test@example.com');
        await $.enterText(find.byKey(const Key('password_field')), 'password123');
        await $.tap(find.text('Logga in'));
        await $.pumpAndSettle();
        
        // Simulate app going to background
        await $.native.pressHome();
        
        // Wait for session timeout (in test mode, shortened to 10 seconds)
        await Future.delayed(const Duration(seconds: 11));
        
        // Return to app
        await $.native.pressDoubleRecentApps();
        await $.pumpAndSettle();
        
        // Should be logged out due to inactivity
        expect(find.text('Din session har löpt ut'), findsOneWidget);
        expect(find.text('Logga in'), findsOneWidget);
      },
    );
  });
}