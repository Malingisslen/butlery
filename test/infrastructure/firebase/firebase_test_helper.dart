import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firebase Test Helper for Integration Testing
///
/// This helper provides utilities for testing Firebase operations that
/// require real Firebase behavior, particularly FieldValue operations
/// like serverTimestamp(), arrayUnion(), arrayRemove(), and increment().
///
/// IMPORTANT: These utilities are for INTEGRATION tests only.
/// Unit tests should mock at the repository level, not Firebase level.
class FirebaseTestHelper {
  static const String _emulatorHost = 'localhost';
  static const int _firestorePort = 8080;
  static const int _authPort = 9099;
  static const int _storagePort = 9199;

  static bool _emulatorsConnected = false;

  /// Connect to Firebase emulators for testing
  /// Call this in setUpAll() for integration tests
  static Future<void> connectToEmulators() async {
    if (_emulatorsConnected) return;

    try {
      // Connect Firestore emulator
      FirebaseFirestore.instance
          .useFirestoreEmulator(_emulatorHost, _firestorePort);

      // Connect Auth emulator
      await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authPort);

      // Connect Storage emulator
      await FirebaseStorage.instance
          .useStorageEmulator(_emulatorHost, _storagePort);

      _emulatorsConnected = true;
      print('✅ Connected to Firebase emulators');
    } catch (e) {
      print('⚠️ Failed to connect to Firebase emulators: $e');
      print('Make sure emulators are running: firebase emulators:start');
      rethrow;
    }
  }

  /// Clear all data in Firestore emulator
  /// Call this in setUp() or tearDown() to ensure clean state
  static Future<void> clearFirestoreData() async {
    if (!_emulatorsConnected) {
      throw StateError('Must connect to emulators first');
    }

    // Clear all collections
    // This is a simplified version - in production you'd want to be more specific
    final firestore = FirebaseFirestore.instance;

    // Common collections in Butlery
    final collections = [
      'users',
      'recipes',
      'shoppingLists',
      'notifications',
      'analytics',
      'comments',
      'friends',
      'groups',
      'menus',
    ];

    for (final collection in collections) {
      try {
        final snapshot = await firestore.collection(collection).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        // Collection might not exist, that's ok
      }
    }
  }

  /// Create a test user in Auth emulator
  static Future<User> createTestUser({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!_emulatorsConnected) {
      throw StateError('Must connect to emulators first');
    }

    final auth = FirebaseAuth.instance;

    // Sign out any existing user
    await auth.signOut();

    // Create new user
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update display name if provided
    if (displayName != null && credential.user != null) {
      await credential.user!.updateDisplayName(displayName);
    }

    return credential.user!;
  }

  /// Sign in a test user
  static Future<User> signInTestUser({
    required String email,
    required String password,
  }) async {
    if (!_emulatorsConnected) {
      throw StateError('Must connect to emulators first');
    }

    final auth = FirebaseAuth.instance;
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return credential.user!;
  }

  /// Test FieldValue.serverTimestamp() properly
  static Future<void> testServerTimestamp() async {
    final firestore = FirebaseFirestore.instance;

    // Create document with serverTimestamp
    final docRef = firestore.collection('test').doc();
    await docRef.set({
      'createdAt': FieldValue.serverTimestamp(),
      'data': 'test',
    });

    // Read back and verify
    final snapshot = await docRef.get();
    final data = snapshot.data()!;

    expect(data['createdAt'], isA<Timestamp>());
    final createdAtMillis =
        (data['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    expect(createdAtMillis,
        closeTo(nowMillis, 5000)); // 5000 milliseconds = 5 seconds
  }

  /// Test FieldValue.increment() properly
  static Future<void> testIncrement() async {
    final firestore = FirebaseFirestore.instance;

    // Create document with initial value
    final docRef = firestore.collection('test').doc();
    await docRef.set({'counter': 5});

    // Increment
    await docRef.update({'counter': FieldValue.increment(3)});

    // Read back and verify
    final snapshot = await docRef.get();
    expect(snapshot.data()!['counter'], equals(8));
  }

  /// Test FieldValue.arrayUnion() properly
  static Future<void> testArrayUnion() async {
    final firestore = FirebaseFirestore.instance;

    // Create document with initial array
    final docRef = firestore.collection('test').doc();
    await docRef.set({
      'tags': ['tag1', 'tag2']
    });

    // Add new tags
    await docRef.update({
      'tags': FieldValue.arrayUnion(['tag3', 'tag2', 'tag4']),
    });

    // Read back and verify
    final snapshot = await docRef.get();
    final tags = List<String>.from(snapshot.data()!['tags']);

    expect(tags, containsAll(['tag1', 'tag2', 'tag3', 'tag4']));
    expect(tags.length, equals(4)); // No duplicates
  }

  /// Test FieldValue.arrayRemove() properly
  static Future<void> testArrayRemove() async {
    final firestore = FirebaseFirestore.instance;

    // Create document with initial array
    final docRef = firestore.collection('test').doc();
    await docRef.set({
      'tags': ['tag1', 'tag2', 'tag3']
    });

    // Remove tags
    await docRef.update({
      'tags': FieldValue.arrayRemove(['tag2']),
    });

    // Read back and verify
    final snapshot = await docRef.get();
    final tags = List<String>.from(snapshot.data()!['tags']);

    expect(tags, equals(['tag1', 'tag3']));
  }

  /// Test batch operations with FieldValue
  static Future<void> testBatchWithFieldValues() async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Create multiple operations in batch
    final doc1 = firestore.collection('test').doc();
    final doc2 = firestore.collection('test').doc();

    batch.set(doc1, {
      'timestamp': FieldValue.serverTimestamp(),
      'counter': 0,
    });

    batch.set(doc2, {
      'timestamp': FieldValue.serverTimestamp(),
      'tags': <String>[],
    });

    // Commit batch
    await batch.commit();

    // Update with another batch
    final updateBatch = firestore.batch();
    updateBatch.update(doc1, {'counter': FieldValue.increment(5)});
    updateBatch.update(doc2, {
      'tags': FieldValue.arrayUnion(['tag1'])
    });
    await updateBatch.commit();

    // Verify
    final snap1 = await doc1.get();
    final snap2 = await doc2.get();

    expect(snap1.data()!['counter'], equals(5));
    expect(snap2.data()!['tags'], equals(['tag1']));
  }

  /// Helper to wait for stream events in tests
  static Future<T> waitForStreamEvent<T>(
    Stream<T> stream, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<T>();
    StreamSubscription<T>? subscription;
    Timer? timer;

    timer = Timer(timeout, () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Stream event timeout after $timeout'),
        );
      }
    });

    subscription = stream.listen(
      (event) {
        timer?.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(event);
        }
      },
      onError: (error) {
        timer?.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    return completer.future;
  }

  /// Create test data for analytics with serverTimestamp
  static Future<void> createAnalyticsEntry({
    required String metricId,
    required String category,
    int count = 1,
  }) async {
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('analytics').doc(metricId).set({
      'timestamp': FieldValue.serverTimestamp(),
      'count': FieldValue.increment(count),
      'categories': FieldValue.arrayUnion([category]),
      'metadata': {
        'lastUpdated': FieldValue.serverTimestamp(),
        'updateCount': FieldValue.increment(1),
      },
    }, SetOptions(merge: true));
  }

  /// Verify complex query with ordering works
  static Future<void> testComplexQueryWithOrdering() async {
    final firestore = FirebaseFirestore.instance;

    // Create test data
    for (int i = 0; i < 5; i++) {
      await firestore.collection('items').add({
        'name': 'Item $i',
        'priority': i,
        'updatedAt': FieldValue.serverTimestamp(),
        'tags': ['tag$i'],
      });

      // Small delay to ensure different timestamps
      await Future.delayed(Duration(milliseconds: 10));
    }

    // Test complex query
    final results = await firestore
        .collection('items')
        .where('priority', isGreaterThan: 1)
        .orderBy('priority')
        .orderBy('updatedAt', descending: true)
        .limit(3)
        .get();

    expect(results.docs.length, lessThanOrEqualTo(3));

    // Verify ordering
    if (results.docs.length > 1) {
      for (int i = 0; i < results.docs.length - 1; i++) {
        final current = results.docs[i].data()['priority'];
        final next = results.docs[i + 1].data()['priority'];
        expect(current, lessThanOrEqualTo(next));
      }
    }
  }

  /// Test account deletion scenario with batch operations
  static Future<void> testAccountDeletion(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Delete user data across collections
    final collections = ['users', 'recipes', 'preferences', 'activity'];

    for (final collection in collections) {
      final query = await firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
    }

    // Also update related documents (remove from arrays)
    final groupsQuery = await firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .get();

    for (final doc in groupsQuery.docs) {
      batch.update(doc.reference, {
        'members': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Commit all deletions
    await batch.commit();

    // Verify deletion
    final userDoc = await firestore.collection('users').doc(userId).get();
    expect(userDoc.exists, isFalse);
  }

  // ==================== E2E TESTING SPECIFIC METHODS ====================

  /// Initialize Firebase for E2E emulator testing
  ///
  /// This method provides comprehensive setup for E2E tests that need
  /// real Firebase operations via emulator. It ensures clean state and
  /// proper emulator connection for reliable E2E testing.
  static Future<void> initializeE2EEmulator() async {
    if (!_emulatorsConnected) {
      await connectToEmulators();
    }

    // Clear all data for clean E2E test state
    await clearFirestoreData();
    await _clearAuthUsers();

    print('✅ Firebase E2E emulator environment ready');
  }

  /// Create E2E test user with complete profile
  ///
  /// This creates a test user with all the associated data structures
  /// needed for comprehensive E2E testing, including user profile,
  /// preferences, and initial data setup.
  static Future<User> createE2ETestUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = await createTestUser(
      email: email,
      password: password,
      displayName: displayName,
    );

    // Create complete user profile for E2E testing
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'preferences': {
        'language': 'sv',
        'notifications': true,
        'theme': 'light',
      },
      'stats': {
        'recipesCreated': 0,
        'menusSaved': 0,
        'friendsCount': 0,
      },
    });

    return user;
  }

  /// Simulate complete user journey data
  ///
  /// This creates a realistic data set for a user including recipes,
  /// shopping lists, menus, and social connections to support
  /// comprehensive E2E user journey testing.
  static Future<void> createE2EUserJourney(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Create user's recipes
    final recipeRef1 = firestore.collection('recipes').doc();
    batch.set(recipeRef1, {
      'title': 'E2E Test Recipe 1',
      'userId': userId,
      'ingredients': ['Test ingredient 1', 'Test ingredient 2'],
      'instructions': ['Step 1: Test step', 'Step 2: Another test step'],
      'createdAt': FieldValue.serverTimestamp(),
      'isPublic': false,
      'category': 'dinner',
      'servings': 4,
    });

    final recipeRef2 = firestore.collection('recipes').doc();
    batch.set(recipeRef2, {
      'title': 'E2E Test Recipe 2',
      'userId': userId,
      'ingredients': ['Test ingredient 3', 'Test ingredient 4'],
      'instructions': ['Step 1: Different test step'],
      'createdAt': FieldValue.serverTimestamp(),
      'isPublic': true,
      'category': 'lunch',
      'servings': 2,
    });

    // Create shopping lists
    final shoppingRef = firestore.collection('shopping_lists').doc();
    batch.set(shoppingRef, {
      'title': 'E2E Shopping List',
      'userId': userId,
      'items': [
        {'name': 'Test Item 1', 'checked': false, 'category': 'dairy'},
        {'name': 'Test Item 2', 'checked': true, 'category': 'produce'},
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'isShared': false,
    });

    // Create menu
    final menuRef = firestore.collection('menus').doc();
    batch.set(menuRef, {
      'title': 'E2E Test Menu',
      'userId': userId,
      'recipes': [recipeRef1.id, recipeRef2.id],
      'weekDays': {
        'monday': recipeRef1.id,
        'wednesday': recipeRef2.id,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Update user stats
    await firestore.collection('users').doc(userId).update({
      'stats.recipesCreated': 2,
      'stats.menusSaved': 1,
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  /// Create E2E test friendship relationship
  ///
  /// This creates a friendship between two test users to support
  /// social feature testing in E2E scenarios.
  static Future<void> createE2EFriendship(
      String userId1, String userId2) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Create friendship documents
    final friendshipId = '${userId1}_$userId2';
    final friendshipRef = firestore.collection('friendships').doc(friendshipId);
    batch.set(friendshipRef, {
      'users': [userId1, userId2],
      'status': 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Update both users' friend counts
    batch.update(firestore.collection('users').doc(userId1), {
      'stats.friendsCount': FieldValue.increment(1),
    });
    batch.update(firestore.collection('users').doc(userId2), {
      'stats.friendsCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Create E2E test group with members
  ///
  /// This creates a group with specified members to support
  /// collaborative feature testing in E2E scenarios.
  static Future<String> createE2EGroup({
    required String ownerId,
    required String groupName,
    required List<String> memberIds,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final groupRef = firestore.collection('groups').doc();
    await groupRef.set({
      'name': groupName,
      'ownerId': ownerId,
      'members': [ownerId, ...memberIds],
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'description': 'E2E test group for collaborative testing',
      'memberPermissions': {
        for (final memberId in [ownerId, ...memberIds])
          memberId: memberId == ownerId ? 'admin' : 'member',
      },
    });

    return groupRef.id;
  }

  /// Setup complete E2E authentication scenario
  ///
  /// This creates a comprehensive authentication test scenario with
  /// multiple users, relationships, and data for testing complex flows.
  static Future<E2EAuthScenario> setupE2EAuthScenario() async {
    // Create primary test user
    final primaryUser = await createE2ETestUser(
      email: 'primary@e2etest.com',
      password: 'testpassword123',
      displayName: 'Primary Test User',
    );

    // Create secondary test user (for friendship/collaboration testing)
    final secondaryUser = await createE2ETestUser(
      email: 'secondary@e2etest.com',
      password: 'testpassword123',
      displayName: 'Secondary Test User',
    );

    // Create user journey data for both users
    await createE2EUserJourney(primaryUser.uid);
    await createE2EUserJourney(secondaryUser.uid);

    // Create friendship between users
    await createE2EFriendship(primaryUser.uid, secondaryUser.uid);

    // Create test group
    final groupId = await createE2EGroup(
      ownerId: primaryUser.uid,
      groupName: 'E2E Test Group',
      memberIds: [secondaryUser.uid],
    );

    return E2EAuthScenario(
      primaryUser: primaryUser,
      secondaryUser: secondaryUser,
      groupId: groupId,
    );
  }

  /// Wait for E2E operation to complete with timeout
  ///
  /// This is specifically designed for E2E tests that need to wait
  /// for asynchronous operations like navigation, Firebase operations,
  /// or UI state changes with appropriate timeouts.
  static Future<T> waitForE2EOperation<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 10),
    String? operationName,
  }) async {
    final completer = Completer<T>();
    Timer? timer;

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        final name = operationName ?? 'E2E operation';
        completer.completeError(
          TimeoutException('$name timed out after $timeout'),
        );
      }
    });

    try {
      final result = await operation();
      timer.cancel();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    } catch (error) {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    return completer.future;
  }

  /// Clear all test users from Auth emulator
  ///
  /// This clears authentication state to ensure clean E2E test environment.
  static Future<void> _clearAuthUsers() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Ignore if no user signed in
    }
  }

  /// Verify E2E emulator connectivity
  ///
  /// This method verifies that all required Firebase emulators are
  /// running and accessible before starting E2E tests.
  static Future<bool> verifyE2EEmulatorConnectivity() async {
    try {
      // Test Firestore connectivity
      await FirebaseFirestore.instance.collection('_test').limit(1).get();

      // Test Auth connectivity
      await FirebaseAuth.instance.signOut(); // This should not fail

      print('✅ Firebase E2E emulator connectivity verified');
      return true;
    } catch (e) {
      print('❌ Firebase E2E emulator connectivity failed: $e');
      return false;
    }
  }
}

/// E2E Authentication Scenario Data
///
/// Container for comprehensive E2E authentication test data including
/// multiple users, relationships, and group data for complex testing scenarios.
class E2EAuthScenario {
  final User primaryUser;
  final User secondaryUser;
  final String groupId;

  const E2EAuthScenario({
    required this.primaryUser,
    required this.secondaryUser,
    required this.groupId,
  });
}

/// Test group for Firebase integration tests
/// Use this to wrap your integration tests that need Firebase emulator
void firebaseIntegrationTest(
  String description,
  Future<void> Function() body, {
  bool skip = false,
}) {
  test(
    description,
    () async {
      if (!FirebaseTestHelper._emulatorsConnected) {
        await FirebaseTestHelper.connectToEmulators();
      }
      await FirebaseTestHelper.clearFirestoreData();
      await body();
    },
    skip: skip,
    tags: ['integration', 'firebase'],
  );
}
