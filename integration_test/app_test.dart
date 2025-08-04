import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import all test files
import 'features/complete_recipe_journey_test.dart' as recipe_journey;
import 'features/offline_sync_test.dart' as offline_sync;
import 'features/authentication_flow_test.dart' as auth_flow;

/// Main entry point for all integration tests
void main() {
  // Initialize integration test binding
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  // Configure Patrol
  setUpAll(() async {
    // Set up any global test configuration
    await _setupTestEnvironment();
  });
  
  tearDownAll(() async {
    // Clean up after tests
    await _teardownTestEnvironment();
  });
  
  // Configure frame policy for smoother animations during tests
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  
  // Run all test suites
  group('Butlery Integration Tests', () {
    recipe_journey.main();
    offline_sync.main();
    auth_flow.main();
  });
}

/// Set up global test environment
Future<void> _setupTestEnvironment() async {
  // Configure test timeouts and environment
  // Set up test data or mocks if needed
}

/// Clean up test environment
Future<void> _teardownTestEnvironment() async {
  // Clean up any test data or resources
}