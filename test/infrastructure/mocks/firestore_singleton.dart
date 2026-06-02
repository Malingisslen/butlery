/// Enhanced Singleton management for FakeFirebaseFirestore with aggressive memory management
///
/// This singleton ensures only one FakeFirebaseFirestore instance exists
/// across all tests, with aggressive cleanup to prevent memory exhaustion.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Enhanced singleton manager for FakeFirebaseFirestore with memory protection
class FirestoreSingleton {
  FirestoreSingleton._();

  static FakeFirebaseFirestore? _instance;
  static int _referenceCount = 0;
  static int _operationCount = 0;
  static const int _maxOperationsBeforeReset =
      100; // Force reset after 100 operations
  static const int _maxDataSize = 1000; // Max documents before forcing cleanup

  // Test isolation tracking
  static String? _currentTestName;
  static final Map<String, Set<String>> _testCollections = {};
  static final List<StreamSubscription> _activeStreams = [];
  static final Map<String, dynamic> _testSnapshots = {};

  /// Set the current test name for isolation tracking
  static void setCurrentTest(String testName) {
    if (_currentTestName != testName) {
      _currentTestName = testName;
      _testCollections[testName] ??= {};
    }
  }

  /// Get or create the singleton FakeFirebaseFirestore instance
  /// Automatically manages memory by resetting after threshold
  static FakeFirebaseFirestore get instance {
    // Force reset if we've done too many operations
    if (_operationCount > _maxOperationsBeforeReset) {
      debugPrint(
          'Force resetting FakeFirebaseFirestore after $_operationCount operations');
      _forceRecreate();
    }

    if (_instance == null) {
      _instance = FakeFirebaseFirestore();
      _referenceCount = 0;
      _operationCount = 0;
      debugPrint('Created new FakeFirebaseFirestore instance');
    }

    _referenceCount++;
    _operationCount++;
    return _instance!;
  }

  /// Force recreate the instance (aggressive memory management)
  static void _forceRecreate() {
    _instance = null;
    _instance = FakeFirebaseFirestore();
    _referenceCount = 0;
    _operationCount = 0;
    debugPrint('Force recreated FakeFirebaseFirestore instance');
  }

  /// Clear all data in the Firestore instance (called after EVERY test).
  ///
  /// Nuke-and-recreate by default: the selective per-collection cleanup
  /// below missed any collection not hardcoded in the list, and that
  /// residual state was the source of cross-test count pollution
  /// (tests asserting `count == 3` getting 12 because previous tests'
  /// docs persisted). The hard reset is cheap and bulletproof.
  static Future<void> clearData() async {
    if (_instance == null) return;

    try {
      // Cancel all active streams first
      await _cancelAllStreams();

      _forceRecreate();

      _currentTestName = null;
      _testCollections.clear();
      _testSnapshots.clear();
      return;
    } catch (e) {
      debugPrint('Error resetting Firestore data: $e');
      _forceRecreate();
      return;
    }

    // ignore: dead_code — legacy selective path kept for reference.
    try {
      await _cancelAllStreams();

      // Count operations
      _operationCount++;

      // More comprehensive collection list
      final collections = [
        'users',
        'recipes',
        'menus',
        'shopping_lists',
        'social_requests',
        'friend_categories',
        'comments',
        'ratings',
        'notifications',
        'conversations',
        'messages',
        'shared_content',
        'realtime_recipes',
        'universal_links',
        'user_stats',
        'test_models',
        'test_collection', // For base repository tests
        'collaborative_recipes',
        'presence',
        'recipe_members',
        'recipe_versions',
        'groups',
        'user_presence',
        'typing_indicators',
        'read_receipts',
      ];

      // Add any test-specific collections
      if (_currentTestName != null &&
          _testCollections[_currentTestName] != null) {
        collections.addAll(_testCollections[_currentTestName]!);
      }

      int totalDeleted = 0;

      // Clear each collection aggressively
      for (final collection in collections) {
        totalDeleted += await _clearCollectionComplete(collection);
      }

      // If we deleted a lot of data, consider forcing a reset
      if (totalDeleted > _maxDataSize) {
        debugPrint('Deleted $totalDeleted documents, forcing instance reset');
        _forceRecreate();
      } else if (totalDeleted > 0) {
        debugPrint(
            'Cleared $totalDeleted documents from FakeFirebaseFirestore');
      }

      // Clear test tracking
      _currentTestName = null;
      _testCollections.clear();
      _testSnapshots.clear();
    } catch (e) {
      debugPrint('Error clearing Firestore data: $e');
      // On error, force recreate to ensure clean state
      _forceRecreate();
    }
  }

  /// Completely clear a collection and all subcollections
  static Future<int> _clearCollectionComplete(String collectionPath) async {
    if (_instance == null) return 0;

    int deletedCount = 0;

    try {
      final collection = _instance!.collection(collectionPath);
      final snapshot = await collection.get();

      // Delete all documents and their subcollections
      for (final doc in snapshot.docs) {
        // Clear ALL possible subcollections (comprehensive list)
        final subcollections = [
          'friends',
          'messages',
          'members',
          'versions',
          'activities',
          'notifications',
          'comments',
          'reactions',
          'read_receipts',
          'typing_indicators',
          'presence',
          'editors',
          'viewers',
          'history',
          'audit_log',
          'permissions',
          'invitations',
          'requests',
        ];

        for (final sub in subcollections) {
          try {
            final subCollection = _instance!
                .collection(collectionPath)
                .doc(doc.id)
                .collection(sub);
            final subSnapshot = await subCollection.get();

            for (final subDoc in subSnapshot.docs) {
              await subDoc.reference.delete();
              deletedCount++;
            }
          } catch (e) {
            // Subcollection might not exist, continue
          }
        }

        // Delete the document itself
        await doc.reference.delete();
        deletedCount++;
      }
    } catch (e) {
      // Collection might not exist, which is fine
    }

    return deletedCount;
  }

  /// Reset the singleton instance with reference counting
  static void reset() {
    _referenceCount--;
    if (_referenceCount <= 0) {
      _instance = null;
      _referenceCount = 0;
      _operationCount = 0;
      debugPrint('FakeFirebaseFirestore singleton reset');
    }
  }

  /// Force reset regardless of reference count (use with extreme caution)
  static void forceReset() {
    _instance = null;
    _referenceCount = 0;
    _operationCount = 0;
    debugPrint('FakeFirebaseFirestore singleton force reset');
  }

  /// Hard reset - completely destroy and recreate (for critical cleanup)
  static Future<void> hardReset() async {
    debugPrint('Performing hard reset of FakeFirebaseFirestore');

    // Cancel all streams
    await _cancelAllStreams();

    // Clear all data first
    if (_instance != null) {
      await clearData();
    }

    // Force recreate
    _instance = null;
    _referenceCount = 0;
    _operationCount = 0;
    _currentTestName = null;
    _testCollections.clear();
    _testSnapshots.clear();

    // BUT-1155: removed the "GC delay" `Future.delayed(10ms)`. hardReset()
    // runs inside the `testWidgets` fake-async zone via the view-test
    // teardown chain (reset → hardReset); a real timer never fires un-pumped
    // and hangs the runner. The await was cargo-cult — the recreate above is
    // synchronous and GC is not influenced by awaiting a timer.

    debugPrint('Hard reset complete');
  }

  /// Cancel all active stream subscriptions
  static Future<void> _cancelAllStreams() async {
    for (final stream in _activeStreams) {
      try {
        await stream.cancel();
      } catch (e) {
        // Ignore cancellation errors
      }
    }
    _activeStreams.clear();
  }

  /// Track a stream subscription for cleanup
  static void trackStream(StreamSubscription subscription) {
    _activeStreams.add(subscription);
  }

  /// Track that a collection was used by current test
  static void trackCollection(String collectionName) {
    if (_currentTestName != null) {
      _testCollections[_currentTestName]?.add(collectionName);
    }
  }

  /// Get current stats for debugging
  static Map<String, dynamic> get stats => {
        'referenceCount': _referenceCount,
        'operationCount': _operationCount,
        'hasInstance': _instance != null ? 1 : 0,
        'activeStreams': _activeStreams.length,
        'currentTest': _currentTestName ?? 'none',
        'testCollections': _testCollections.length,
      };

  /// Check if we should force a cleanup
  static bool get shouldForceCleanup =>
      _operationCount > _maxOperationsBeforeReset || _referenceCount < 0;
}
