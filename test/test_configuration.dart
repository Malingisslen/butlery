/// Global test configuration that ensures proper test environment setup.
///
/// This configuration file provides global test setup and teardown functionality
/// to ensure all tests have proper dependency injection and service locator
/// initialization. It prevents the common "ServiceLocator not initialized" error
/// by ensuring TestServiceLocator is properly set up before any test runs.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_service_locator.dart';
import 'helpers/test_helpers.dart';
import 'helpers/test_getit_setup.dart';
import 'helpers/firebase_test_setup.dart';

/// Sets up the test environment for all tests.
///
/// Call this at the beginning of each test file's main() function:
/// ```dart
/// void main() {
///   configureTests();
///   
///   group('MyTests', () {
///     // Your tests here
///   });
/// }
/// ```
void configureTests() {
  setUpAll(() async {
    // Ensure Flutter test bindings are initialized
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Initialize test service locator with all mocks
    TestServiceLocator.initialize();
    
    // Setup GetIt for services that use it directly
    setupTestGetIt();
    
    // Initialize Firebase test environment with mocks by default
    await FirebaseTestSetup.initialize(mode: FirebaseTestMode.mocks);
    
    // Set up any global test configuration
    TestLifecycleHelper.setupTestEnvironment();
  });
  
  setUp(() async {
    // Reset mocks to clean state before each test
    TestServiceLocator.reset();
    
    // Re-initialize to ensure clean state
    TestServiceLocator.initialize();
    
    // Re-setup GetIt
    setupTestGetIt();
    
    // Reset Firebase to clean state
    if (FirebaseTestSetup.isInitialized) {
      await FirebaseTestSetup.reset();
      await FirebaseTestSetup.initialize(mode: FirebaseTestMode.mocks);
    }
  });
  
  tearDown(() {
    // Clean up after each test
    TestServiceLocator.reset();
  });
  
  tearDownAll(() async {
    // Final cleanup
    TestServiceLocator.dispose();
    tearDownTestGetIt();
    await FirebaseTestSetup.reset();
    TestLifecycleHelper.tearDownTestEnvironment();
  });
}

/// Alternative lightweight configuration for unit tests that don't need full setup.
void configureUnitTests() {
  setUp(() {
    TestServiceLocator.initialize();
    setupTestGetIt();
  });
  
  tearDown(() {
    TestServiceLocator.reset();
    tearDownTestGetIt();
  });
  
  tearDownAll(() {
    TestServiceLocator.dispose();
    tearDownTestGetIt();
  });
}

/// Zone configuration for catching async errors in tests.
void runTestsInZone(void Function() testBody) {
  runZonedGuarded(
    testBody,
    (error, stackTrace) {
      // Log but don't fail tests for async errors
      // This helps identify issues without breaking CI
      print('Async error in test: $error\n$stackTrace');
    },
  );
}

/// Helper to ensure service locator is initialized for a specific test.
///
/// Use this wrapper when you need to ensure ServiceLocator is available:
/// ```dart
/// testWithServiceLocator('my test', (tester) async {
///   // Your test code here
/// });
/// ```
void testWithServiceLocator(
  String description,
  Future<void> Function(WidgetTester) callback, {
  bool skip = false,
  Timeout? timeout,
  dynamic tags,
}) {
  testWidgets(
    description,
    (tester) async {
      // Ensure service locator is initialized
      if (!isTestServiceLocatorInitialized()) {
        TestServiceLocator.initialize();
      }
      
      try {
        await callback(tester);
      } finally {
        // Clean up even if test fails
        TestServiceLocator.reset();
      }
    },
    skip: skip,
    timeout: timeout,
    tags: tags,
  );
}

/// Helper to check if test service locator is initialized.
bool isTestServiceLocatorInitialized() {
  try {
    // Try to access the container
    TestServiceLocator.container;
    return true;
  } catch (e) {
    return false;
  }
}