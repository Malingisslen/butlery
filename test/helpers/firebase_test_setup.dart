/// Firebase test setup configuration for comprehensive test environment.
///
/// This module provides complete Firebase test setup including emulator configuration,
/// mock initialization, and test data seeding for reliable Firebase testing.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:butlery/firebase_options_test.dart';
import 'firebase_emulator_helper.dart';
import 'test_service_locator.dart';

/// Firebase test environment configuration
enum FirebaseTestMode {
  /// Use mocks for unit tests (no real Firebase connection)
  mocks,
  /// Use Firebase emulators for integration tests
  emulators,
  /// Use real test Firebase project (requires internet)
  testProject,
}

/// Setup Firebase for testing based on test mode
class FirebaseTestSetup {
  static bool _isInitialized = false;
  static FirebaseTestMode _currentMode = FirebaseTestMode.mocks;
  
  /// Get current test mode
  static FirebaseTestMode get currentMode => _currentMode;
  
  /// Check if Firebase is initialized for testing
  static bool get isInitialized => _isInitialized;
  
  /// Initialize Firebase for testing
  static Future<void> initialize({
    FirebaseTestMode mode = FirebaseTestMode.mocks,
    MockUser? initialUser,
    Map<String, dynamic>? initialData,
  }) async {
    if (_isInitialized) {
      return;
    }
    
    _currentMode = mode;
    
    switch (mode) {
      case FirebaseTestMode.mocks:
        await _initializeWithMocks(initialUser, initialData);
        break;
      case FirebaseTestMode.emulators:
        await _initializeWithEmulators();
        break;
      case FirebaseTestMode.testProject:
        await _initializeWithTestProject();
        break;
    }
    
    _isInitialized = true;
  }
  
  /// Initialize with mocks for unit testing
  static Future<void> _initializeWithMocks(
    MockUser? initialUser,
    Map<String, dynamic>? initialData,
  ) async {
    // Use the Firebase emulator helper's mock initialization
    await FirebaseEmulatorHelper.initializeWithMocks(
      initialUser: initialUser ?? TestServiceLocator.mockFirebaseUser,
      initialFirestoreData: _convertToFirestoreData(initialData),
    );
  }
  
  /// Initialize with emulators for integration testing
  static Future<void> _initializeWithEmulators() async {
    // Check if emulators are running
    final emulatorStatus = await FirebaseEmulatorHelper.areEmulatorsRunning();
    if (!emulatorStatus) {
      throw StateError(
        'Firebase emulators are not running. Please start them with:\n'
        'firebase emulators:start --project butlery-test',
      );
    }
    
    // Initialize with emulators
    await FirebaseEmulatorHelper.initializeWithEmulators(
      projectId: TestFirebaseOptions.testProjectId,
    );
    
    // Clear any existing data
    await FirebaseEmulatorHelper.clearEmulatorData();
  }
  
  /// Initialize with real test Firebase project
  static Future<void> _initializeWithTestProject() async {
    // Initialize Firebase with test options
    await Firebase.initializeApp(
      options: TestFirebaseOptions.currentPlatform,
    );
  }
  
  /// Reset Firebase test environment
  static Future<void> reset() async {
    if (!_isInitialized) {
      return;
    }
    
    await FirebaseEmulatorHelper.reset();
    _isInitialized = false;
  }
  
  /// Seed test data
  static Future<void> seedTestData({
    List<Map<String, dynamic>>? recipes,
    List<Map<String, dynamic>>? users,
    Map<String, dynamic>? customData,
  }) async {
    if (!_isInitialized) {
      throw StateError('Firebase test environment not initialized');
    }
    
    final testData = <String, dynamic>{};
    
    // Add recipes
    if (recipes != null) {
      final recipesData = <String, dynamic>{};
      for (final recipe in recipes) {
        final id = recipe['id'] ?? 'recipe_${DateTime.now().millisecondsSinceEpoch}';
        recipesData[id] = recipe;
      }
      testData['recipes'] = recipesData;
    }
    
    // Add users
    if (users != null) {
      final usersData = <String, dynamic>{};
      for (final user in users) {
        final id = user['uid'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
        usersData[id] = user;
      }
      testData['users'] = usersData;
    }
    
    // Add custom data
    if (customData != null) {
      testData.addAll(customData);
    }
    
    // Seed the data
    await FirebaseEmulatorHelper.seedFirestoreData(testData);
  }
  
  /// Create test user
  static Future<MockUser> createTestUser({
    String? uid,
    String? email,
    String? displayName,
    bool verified = true,
  }) async {
    final testUid = uid ?? 'test_user_${DateTime.now().millisecondsSinceEpoch}';
    final testEmail = email ?? 'test_$testUid@example.com';
    
    if (_currentMode == FirebaseTestMode.mocks) {
      return MockUser(
        uid: testUid,
        email: testEmail,
        displayName: displayName ?? 'Test User',
        isEmailVerified: verified,
      );
    } else {
      final credential = await FirebaseEmulatorHelper.createTestUser(
        email: testEmail,
        password: 'testpass123',
        displayName: displayName,
        verified: verified,
      );
      
      return MockUser(
        uid: credential.user!.uid,
        email: credential.user!.email!,
        displayName: credential.user!.displayName,
        isEmailVerified: credential.user!.emailVerified,
      );
    }
  }
  
  /// Convert test data to Firestore format
  static Map<String, Map<String, dynamic>> _convertToFirestoreData(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return {};
    
    final result = <String, Map<String, dynamic>>{};
    
    for (final entry in data.entries) {
      if (entry.value is Map<String, dynamic>) {
        for (final doc in (entry.value as Map<String, dynamic>).entries) {
          result['${entry.key}/${doc.key}'] = doc.value as Map<String, dynamic>;
        }
      }
    }
    
    return result;
  }
}

/// Configuration for different test scenarios
class FirebaseTestScenarios {
  /// Empty database scenario
  static Future<void> setupEmptyDatabase() async {
    await FirebaseTestSetup.initialize(mode: FirebaseTestMode.mocks);
  }
  
  /// User with recipes scenario
  static Future<void> setupUserWithRecipes({
    String userId = 'test_user_123',
    int recipeCount = 5,
  }) async {
    await FirebaseTestSetup.initialize(
      mode: FirebaseTestMode.mocks,
      initialUser: MockUser(
        uid: userId,
        email: 'test@example.com',
        displayName: 'Test User',
      ),
    );
    
    // Generate test recipes
    final recipes = List.generate(recipeCount, (i) => 
      FirebaseTestData.generateRecipe(
        id: 'recipe_$i',
        title: 'Test Recipe $i',
        userId: userId,
      ),
    );
    
    await FirebaseTestSetup.seedTestData(recipes: recipes);
  }
  
  /// Social features scenario
  static Future<void> setupSocialScenario() async {
    await FirebaseTestSetup.initialize(mode: FirebaseTestMode.mocks);
    
    // Create multiple users
    final users = [
      FirebaseTestData.generateUserProfile(
        uid: 'user_1',
        displayName: 'User One',
      ),
      FirebaseTestData.generateUserProfile(
        uid: 'user_2',
        displayName: 'User Two',
      ),
      FirebaseTestData.generateUserProfile(
        uid: 'user_3',
        displayName: 'User Three',
      ),
    ];
    
    // Create recipes from different users
    final recipes = [
      FirebaseTestData.generateRecipe(
        id: 'recipe_1',
        title: 'Recipe from User 1',
        userId: 'user_1',
      ),
      FirebaseTestData.generateRecipe(
        id: 'recipe_2',
        title: 'Recipe from User 2',
        userId: 'user_2',
      ),
    ];
    
    await FirebaseTestSetup.seedTestData(
      users: users,
      recipes: recipes,
      customData: {
        'friends': {
          'user_1_user_2': {
            'users': ['user_1', 'user_2'],
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'accepted',
          },
        },
      },
    );
  }
}