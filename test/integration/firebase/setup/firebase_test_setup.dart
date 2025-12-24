/// Firebase test setup for integration tests
///
/// Configures Firebase to use local emulator for testing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseTestSetup {
  static bool _initialized = false;

  /// Initialize Firebase with emulator configuration
  static Future<void> initialize() async {
    if (_initialized) return;

    // Ensure Flutter bindings are initialized for Firebase
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase app
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'test-project',
      ),
    );

    // Configure Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

    // Configure Auth emulator
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);

    // Clear any existing data
    await clearEmulatorData();

    _initialized = true;
  }

  /// Clear all data from emulator
  static Future<void> clearEmulatorData() async {
    // Clear Firestore
    final firestore = FirebaseFirestore.instance;
    await _deleteCollection(firestore, 'users');
    await _deleteCollection(firestore, 'recipes');
    await _deleteCollection(firestore, 'shared_recipes');
    await _deleteCollection(firestore, 'shared_menus');
    await _deleteCollection(firestore, 'shared_content');

    // Sign out any authenticated users
    await FirebaseAuth.instance.signOut();
  }

  /// Delete all documents in a collection
  static Future<void> _deleteCollection(
    FirebaseFirestore firestore,
    String collectionPath,
  ) async {
    final collection = firestore.collection(collectionPath);
    final snapshots = await collection.get();

    for (final doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }

  /// Create test user for integration tests
  static Future<User> createTestUser({
    String email = 'test@example.com',
    String password = 'testpass123',
  }) async {
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  /// Sign in test user
  static Future<User> signInTestUser({
    String email = 'test@example.com',
    String password = 'testpass123',
  }) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }
}
