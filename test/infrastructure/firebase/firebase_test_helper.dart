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
      FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestorePort);
      
      // Connect Auth emulator
      await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authPort);
      
      // Connect Storage emulator
      await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, _storagePort);
      
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
    final createdAtMillis = (data['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch;
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
    await docRef.set({'tags': ['tag1', 'tag2']});
    
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
    await docRef.set({'tags': ['tag1', 'tag2', 'tag3']});
    
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
    updateBatch.update(doc2, {'tags': FieldValue.arrayUnion(['tag1'])});
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