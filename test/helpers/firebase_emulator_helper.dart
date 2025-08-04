import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:mocktail/mocktail.dart';

/// Comprehensive Firebase Emulator configuration and helper utilities
/// Provides both emulator setup for integration tests and mock setup for unit tests
class FirebaseEmulatorHelper {
  // Emulator ports (standard Firebase emulator ports)
  static const int authEmulatorPort = 9099;
  static const int firestoreEmulatorPort = 8080;
  static const int storageEmulatorPort = 9199;
  static const int functionsEmulatorPort = 5001;
  static const int databaseEmulatorPort = 9000;

  // Emulator host configuration
  static String get emulatorHost {
    if (Platform.isAndroid) {
      return '10.0.2.2'; // Android emulator localhost
    } else if (Platform.isIOS || Platform.isMacOS) {
      return 'localhost';
    } else {
      return '127.0.0.1';
    }
  }

  // Track emulator state
  static bool _emulatorsConfigured = false;
  static bool _usingEmulators = false;

  // Mock instances for unit testing
  static FakeFirebaseFirestore? _mockFirestore;
  static MockFirebaseAuth? _mockAuth;
  static MockFirebaseStorage? _mockStorage;

  /// Initialize Firebase with emulators for integration testing
  static Future<void> initializeWithEmulators({
    bool useAuthEmulator = true,
    bool useFirestoreEmulator = true,
    bool useStorageEmulator = true,
    bool useFunctionsEmulator = false,
    bool useDatabaseEmulator = false,
    String? projectId,
  }) async {
    if (_emulatorsConfigured) {
      debugPrint('[Firebase] Emulators already configured');
      return;
    }

    try {
      // Initialize Firebase app with test project
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: 'test-api-key',
          appId: 'test-app-id',
          messagingSenderId: 'test-sender-id',
          projectId: projectId ?? 'butlery-test',
          storageBucket: 'butlery-test.appspot.com',
          authDomain: 'butlery-test.firebaseapp.com',
        ),
      );

      // Configure Auth emulator
      if (useAuthEmulator) {
        await FirebaseAuth.instance
            .useAuthEmulator(emulatorHost, authEmulatorPort);
        debugPrint(
            '[Firebase] Auth emulator configured at $emulatorHost:$authEmulatorPort');
      }

      // Configure Firestore emulator
      if (useFirestoreEmulator) {
        FirebaseFirestore.instance.settings = Settings(
          host: '$emulatorHost:$firestoreEmulatorPort',
          sslEnabled: false,
          persistenceEnabled: false,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint(
            '[Firebase] Firestore emulator configured at $emulatorHost:$firestoreEmulatorPort');
      }

      // Configure Storage emulator
      if (useStorageEmulator) {
        await FirebaseStorage.instance.useStorageEmulator(
          emulatorHost,
          storageEmulatorPort,
        );
        debugPrint(
            '[Firebase] Storage emulator configured at $emulatorHost:$storageEmulatorPort');
      }

      _emulatorsConfigured = true;
      _usingEmulators = true;

      debugPrint('[Firebase] All emulators initialized successfully');
    } catch (e) {
      debugPrint('[Firebase] Error initializing emulators: $e');
      rethrow;
    }
  }

  /// Initialize with mocks for unit testing (no real Firebase connection)
  static Future<void> initializeWithMocks({
    MockUser? initialUser,
    Map<String, Map<String, dynamic>>? initialFirestoreData,
    Map<String, List<int>>? initialStorageFiles,
  }) async {
    if (_emulatorsConfigured) {
      debugPrint('[Firebase] Already configured, skipping mock initialization');
      return;
    }

    // Create mock instances
    _mockFirestore = FakeFirebaseFirestore();
    _mockAuth = MockFirebaseAuth(
      mockUser: initialUser,
      signedIn: initialUser != null,
    );
    _mockStorage = MockFirebaseStorage();

    // Seed initial Firestore data
    if (initialFirestoreData != null) {
      for (final entry in initialFirestoreData.entries) {
        final parts = entry.key.split('/');
        if (parts.length == 2) {
          // Collection/Document
          await _mockFirestore!
              .collection(parts[0])
              .doc(parts[1])
              .set(entry.value);
        }
      }
    }

    // Seed initial storage files
    if (initialStorageFiles != null) {
      for (final entry in initialStorageFiles.entries) {
        final ref = _mockStorage!.ref(entry.key);
        await ref.putData(
          Uint8List.fromList(entry.value),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
    }

    _emulatorsConfigured = true;
    _usingEmulators = false;

    debugPrint('[Firebase] Mock services initialized');
  }

  /// Get current Firestore instance (emulator or mock)
  static FirebaseFirestore get firestore {
    if (_usingEmulators) {
      return FirebaseFirestore.instance;
    } else if (_mockFirestore != null) {
      return _mockFirestore!;
    } else {
      throw StateError(
          'Firebase not initialized. Call initializeWithEmulators or initializeWithMocks first.');
    }
  }

  /// Get current Auth instance (emulator or mock)
  static FirebaseAuth get auth {
    if (_usingEmulators) {
      return FirebaseAuth.instance;
    } else if (_mockAuth != null) {
      return _mockAuth! as FirebaseAuth;
    } else {
      throw StateError(
          'Firebase not initialized. Call initializeWithEmulators or initializeWithMocks first.');
    }
  }

  /// Get current Storage instance (emulator or mock)
  static FirebaseStorage get storage {
    if (_usingEmulators) {
      return FirebaseStorage.instance;
    } else if (_mockStorage != null) {
      return _mockStorage! as FirebaseStorage;
    } else {
      throw StateError(
          'Firebase not initialized. Call initializeWithEmulators or initializeWithMocks first.');
    }
  }

  /// Clear all emulator data
  static Future<void> clearEmulatorData() async {
    if (!_usingEmulators) {
      debugPrint('[Firebase] Not using emulators, skipping clear');
      return;
    }

    try {
      // Clear Firestore
      await _clearFirestoreEmulator();

      // Clear Auth
      await _clearAuthEmulator();

      // Clear Storage
      await _clearStorageEmulator();

      debugPrint('[Firebase] All emulator data cleared');
    } catch (e) {
      debugPrint('[Firebase] Error clearing emulator data: $e');
    }
  }

  /// Clear Firestore emulator data
  static Future<void> _clearFirestoreEmulator() async {
    final url =
        'http://$emulatorHost:$firestoreEmulatorPort/emulator/v1/projects/butlery-test/databases/(default)/documents';
    try {
      final client = HttpClient();
      final request = await client.deleteUrl(Uri.parse(url));
      final response = await request.close();
      await response.drain();
      client.close();
      debugPrint('[Firebase] Firestore emulator cleared');
    } catch (e) {
      debugPrint('[Firebase] Failed to clear Firestore emulator: $e');
    }
  }

  /// Clear Auth emulator data
  static Future<void> _clearAuthEmulator() async {
    final url =
        'http://$emulatorHost:$authEmulatorPort/emulator/v1/projects/butlery-test/accounts';
    try {
      final client = HttpClient();
      final request = await client.deleteUrl(Uri.parse(url));
      final response = await request.close();
      await response.drain();
      client.close();
      debugPrint('[Firebase] Auth emulator cleared');
    } catch (e) {
      debugPrint('[Firebase] Failed to clear Auth emulator: $e');
    }
  }

  /// Clear Storage emulator data
  static Future<void> _clearStorageEmulator() async {
    // Storage emulator doesn't have a REST API for clearing
    // Would need to be done through Firebase Admin SDK
    debugPrint('[Firebase] Storage emulator clear not implemented');
  }

  /// Create test user in emulator or mock
  static Future<UserCredential> createTestUser({
    required String email,
    required String password,
    String? displayName,
    String? photoURL,
    bool verified = true,
  }) async {
    if (_usingEmulators) {
      // Create user in emulator
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update profile
      if (displayName != null || photoURL != null) {
        await credential.user?.updateProfile(
          displayName: displayName,
          photoURL: photoURL,
        );
      }

      // Verify email if requested
      if (verified) {
        await credential.user?.reload();
      }

      return credential;
    } else if (_mockAuth != null) {
      // Create mock user
      final mockUser = MockUser(
        uid: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        displayName: displayName,
        photoURL: photoURL,
        isEmailVerified: verified,
      );

      // Sign in with mock
      when(() => _mockAuth!.createUserWithEmailAndPassword(
            email: email,
            password: password,
          )).thenAnswer((_) async => MockUserCredential(
            user: mockUser,
          ));

      return await _mockAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } else {
      throw StateError('Firebase not initialized');
    }
  }

  /// Seed test data in Firestore
  static Future<void> seedFirestoreData(Map<String, dynamic> data) async {
    for (final collection in data.entries) {
      final collectionRef = firestore.collection(collection.key);
      final documents = collection.value as Map<String, dynamic>;

      for (final doc in documents.entries) {
        await collectionRef.doc(doc.key).set(doc.value);
      }
    }
    debugPrint('[Firebase] Seeded ${data.length} collections');
  }

  /// Upload test file to Storage
  static Future<String> uploadTestFile({
    required String path,
    required Uint8List data,
    String contentType = 'image/jpeg',
  }) async {
    final ref = storage.ref(path);
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'test': 'true',
      },
    );

    final uploadTask = ref.putData(data, metadata);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    debugPrint('[Firebase] Uploaded test file to $path');
    return downloadUrl;
  }

  /// Reset Firebase to uninitialized state
  static Future<void> reset() async {
    if (_usingEmulators) {
      await clearEmulatorData();
    }

    _mockFirestore = null;
    _mockAuth = null;
    _mockStorage = null;
    _emulatorsConfigured = false;
    _usingEmulators = false;

    // Delete Firebase app if exists
    try {
      await Firebase.app().delete();
    } catch (e) {
      // App might not exist
    }

    debugPrint('[Firebase] Reset complete');
  }

  /// Wait for Firestore writes to complete
  static Future<void> waitForPendingWrites() async {
    if (_usingEmulators) {
      await firestore.waitForPendingWrites();
    }
    // Mocks complete synchronously
  }

  /// Enable/disable Firestore network (emulator only)
  static Future<void> setNetworkEnabled(bool enabled) async {
    if (_usingEmulators) {
      if (enabled) {
        await firestore.enableNetwork();
      } else {
        await firestore.disableNetwork();
      }
    }
  }

  /// Check if emulators are running
  static Future<bool> areEmulatorsRunning() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://$emulatorHost:4000/'), // Emulator UI
      );
      final response = await request.close();
      await response.drain();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get emulator status information
  static Future<Map<String, bool>> getEmulatorStatus() async {
    final status = <String, bool>{};

    // Check each emulator
    status['auth'] = await _checkEmulator(authEmulatorPort);
    status['firestore'] = await _checkEmulator(firestoreEmulatorPort);
    status['storage'] = await _checkEmulator(storageEmulatorPort);
    status['functions'] = await _checkEmulator(functionsEmulatorPort);
    status['database'] = await _checkEmulator(databaseEmulatorPort);

    return status;
  }

  static Future<bool> _checkEmulator(int port) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://$emulatorHost:$port/'),
      );
      final response = await request.close();
      await response.drain();
      client.close();
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }
}

/// Test data generators for Firebase
class FirebaseTestData {
  /// Generate test recipe document
  static Map<String, dynamic> generateRecipe({
    String? id,
    String? title,
    String? userId,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return {
      'id': id ?? 'recipe_${now.millisecondsSinceEpoch}',
      'title': title ?? 'Test Recipe',
      'description': 'A delicious test recipe',
      'userId': userId ?? 'test_user_123',
      'createdAt': Timestamp.fromDate(createdAt ?? now),
      'updatedAt': Timestamp.fromDate(now),
      'ingredients': ['Ingredient 1', 'Ingredient 2'],
      'instructions': ['Step 1', 'Step 2'],
      'cookTime': 30,
      'servings': 4,
      'imageUrl': 'https://example.com/recipe.jpg',
      'tags': ['test', 'recipe'],
      'isPublic': true,
      'favoriteCount': 0,
    };
  }

  /// Generate test user profile document
  static Map<String, dynamic> generateUserProfile({
    String? uid,
    String? email,
    String? displayName,
    DateTime? joinedAt,
  }) {
    final now = DateTime.now();
    return {
      'uid': uid ?? 'user_${now.millisecondsSinceEpoch}',
      'email': email ?? 'test@example.com',
      'displayName': displayName ?? 'Test User',
      'joinedAt': Timestamp.fromDate(joinedAt ?? now),
      'lastActiveAt': Timestamp.fromDate(now),
      'recipeCount': 0,
      'followerCount': 0,
      'followingCount': 0,
      'bio': 'Test user bio',
      'avatarUrl': 'https://example.com/avatar.jpg',
      'isVerified': false,
      'settings': {
        'emailNotifications': true,
        'pushNotifications': true,
        'privateProfile': false,
      },
    };
  }

  /// Generate test message document
  static Map<String, dynamic> generateMessage({
    String? id,
    String? conversationId,
    String? senderId,
    String? text,
    DateTime? sentAt,
  }) {
    final now = DateTime.now();
    return {
      'id': id ?? 'msg_${now.millisecondsSinceEpoch}',
      'conversationId': conversationId ?? 'conv_123',
      'senderId': senderId ?? 'user_123',
      'text': text ?? 'Test message',
      'sentAt': Timestamp.fromDate(sentAt ?? now),
      'readBy': {senderId ?? 'user_123': true},
      'type': 'text',
      'metadata': {},
    };
  }
}

/// Mock implementations for when not using emulators
class MockUserCredential extends Mock implements UserCredential {
  @override
  final User? user;

  MockUserCredential({this.user});
}

/// Annotation for Firebase emulator tests
class FirebaseEmulatorTest {
  const FirebaseEmulatorTest();
}
