import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Helper class for Firebase testing
class FirebaseTestHelper {
  static FakeFirebaseFirestore? _fakeFirestore;
  static MockFirebaseAuth? _mockAuth;

  /// Get fake Firestore instance
  static FakeFirebaseFirestore get fakeFirestore {
    _fakeFirestore ??= FakeFirebaseFirestore();
    return _fakeFirestore!;
  }

  /// Get mock auth instance
  static MockFirebaseAuth get mockAuth {
    _mockAuth ??= MockFirebaseAuth();
    return _mockAuth!;
  }

  /// Test Firebase options
  static const FirebaseOptions testOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project',
    storageBucket: 'test-bucket',
  );

  /// Initialize Firebase for testing with optional initial data
  static Future<void> initializeFirebase({
    MockUser? initialUser,
    Map<String, dynamic>? firestoreData,
  }) async {
    await Firebase.initializeApp(options: testOptions);

    // Set up initial user if provided
    if (initialUser != null) {
      await mockAuth.signInWithCustomToken('test-token');
    }

    // Set up initial Firestore data if provided
    if (firestoreData != null) {
      // Add initial data to Firestore
    }
  }

  /// Create mock user
  static MockUser createMockUser({
    required String uid,
    required String email,
    String? displayName,
  }) {
    return MockUser(
      uid: uid,
      email: email,
      displayName: displayName,
    );
  }

  /// Use Firebase emulator
  static Future<void> useEmulator() async {
    // Configure emulators if needed
  }

  /// Clear emulator data
  static Future<void> clearEmulatorData() async {
    // Clear data if needed
  }

  /// Create test user
  static Future<void> createTestUser({
    required String email,
    required String password,
    String? displayName,
  }) async {
    // Create test user if needed
  }

  /// Clean up test resources
  static Future<void> cleanup() async {
    _fakeFirestore = null;
    _mockAuth = null;
  }
}
