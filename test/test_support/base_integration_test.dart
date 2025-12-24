/// Base class for integration tests with full app initialization
///
/// Extends BaseTest with integration test specific functionality including
/// real app bootstrapping, feature flow testing, and end-to-end utilities.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'base_test.dart';

/// Base class for all integration tests
///
/// Provides:
/// - Full app initialization
/// - Feature flow helpers
/// - Navigation utilities
/// - Real service testing
abstract class BaseIntegrationTest extends BaseTest {
  /// Whether integration test binding is initialized
  static bool _bindingInitialized = false;

  /// Initialize integration test environment
  static void initializeBinding() {
    if (!_bindingInitialized) {
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
      _bindingInitialized = true;
    }
  }

  /// Enhanced setup for integration tests
  static Future<void> setupIntegration() async {
    initializeBinding();
    await BaseTest.setup();
  }

  /// Enhanced teardown for integration tests
  static Future<void> teardownIntegration() async {
    await BaseTest.teardown();
  }

  /// Run an integration test with automatic setup
  static void testIntegration(
    String description,
    Future<void> Function(WidgetTester) body, {
    bool skip = false,
    Timeout? timeout,
    dynamic tags,
  }) {
    testWidgets(
      description,
      (WidgetTester tester) async {
        await setupIntegration();

        try {
          await body(tester);
        } finally {
          await teardownIntegration();
        }
      },
      skip: skip,
      timeout: timeout ?? const Timeout(Duration(minutes: 5)),
      tags: tags,
    );
  }

  /// Run an integration test group with automatic setup
  static void groupIntegration(
    String description,
    void Function() body, {
    bool skip = false,
  }) {
    group(description, () {
      setUpAll(() async {
        await setupIntegration();
      });

      tearDownAll(() async {
        await BaseTest.reset();
      });

      body();
    }, skip: skip);
  }

  /// Run a complete user journey test
  static void testUserJourney(
    String journeyName,
    List<JourneyStep> steps, {
    bool skip = false,
    Timeout? timeout,
  }) {
    testIntegration(
      journeyName,
      (tester) async {
        int successfulSteps = 0;

        for (var i = 0; i < steps.length; i++) {
          final step = steps[i];
          debugPrint(
              'Executing step ${i + 1}/${steps.length}: ${step.description}');

          try {
            await step.execute(tester);
            successfulSteps++;
          } catch (e) {
            debugPrint('Step failed: ${step.description} - Error: $e');
            rethrow;
          }
        }

        // Verify journey completion
        expect(successfulSteps, equals(steps.length),
            reason: 'All journey steps should complete successfully');
      },
      skip: skip,
      timeout: timeout,
    );
  }
}

/// Helper utilities for integration tests
///
/// These utilities can be used directly in tests following the AAA pattern:
/// - Arrange: Set up test data and mocks
/// - Act: Execute the test action
/// - Assert: Verify the results
class IntegrationTestHelpers {
  /// Perform login flow
  static Future<void> performLogin(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    // Find and fill email field
    final emailField = find.byKey(const Key('email_field'));
    await tester.enterText(emailField, email);

    // Find and fill password field
    final passwordField = find.byKey(const Key('password_field'));
    await tester.enterText(passwordField, password);

    // Tap login button
    final loginButton = find.byKey(const Key('login_button'));
    await tester.tap(loginButton);

    // Wait for navigation
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// Verify user is logged in
  static Future<bool> isLoggedIn(WidgetTester tester) async {
    // Check for presence of logout button or user avatar
    return find.byKey(const Key('user_avatar')).evaluate().isNotEmpty;
  }

  /// Navigate to a screen
  static Future<void> navigateTo(WidgetTester tester, String routeName) async {
    await tester.pumpAndSettle();
    // This would typically use Navigator.pushNamed in a real app
    debugPrint('Navigating to: $routeName');
  }

  /// Go back
  static Future<void> goBack(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  /// Wait for a condition with timeout
  static Future<void> waitFor(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (!condition()) {
      if (DateTime.now().isAfter(end)) {
        throw TestFailure(timeoutMessage ?? 'Condition not met within timeout');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Take a screenshot (for debugging)
  static Future<void> takeScreenshot(String name) async {
    // In a real implementation, this would save a screenshot
    debugPrint('Screenshot: $name');
  }
}

/// Represents a step in a user journey
class JourneyStep {
  final String description;
  final Future<void> Function(WidgetTester tester) execute;

  const JourneyStep({
    required this.description,
    required this.execute,
  });
}

/// Result of a journey step
class StepResult {
  final String description;
  final bool success;
  final String? error;

  const StepResult(this.description, this.success, this.error);
}

/// Common journey steps for reuse
class CommonJourneySteps {
  /// Login step
  static JourneyStep login({
    String email = 'test@example.com',
    String password = 'password123',
  }) {
    return JourneyStep(
      description: 'User logs in',
      execute: (tester) async {
        // Arrange
        // (test data already provided as parameters)

        // Act
        await IntegrationTestHelpers.performLogin(
          tester,
          email: email,
          password: password,
        );

        // Assert
        expect(await IntegrationTestHelpers.isLoggedIn(tester), isTrue);
      },
    );
  }

  /// Navigate to screen step
  static JourneyStep navigateTo(String screenName, String routeName) {
    return JourneyStep(
      description: 'Navigate to $screenName',
      execute: (tester) async {
        await IntegrationTestHelpers.navigateTo(tester, routeName);
        await tester.pumpAndSettle();
      },
    );
  }

  /// Tap button step
  static JourneyStep tapButton(String buttonText) {
    return JourneyStep(
      description: 'Tap "$buttonText" button',
      execute: (tester) async {
        final button = find.text(buttonText);
        await tester.tap(button);
        await tester.pumpAndSettle();
      },
    );
  }

  /// Enter text step
  static JourneyStep enterText(String fieldKey, String text) {
    return JourneyStep(
      description: 'Enter text in $fieldKey field',
      execute: (tester) async {
        final field = find.byKey(Key(fieldKey));
        await tester.enterText(field, text);
        await tester.pumpAndSettle();
      },
    );
  }

  /// Verify text present step
  static JourneyStep verifyText(String text) {
    return JourneyStep(
      description: 'Verify "$text" is displayed',
      execute: (tester) async {
        expect(find.text(text), findsOneWidget);
      },
    );
  }
}
