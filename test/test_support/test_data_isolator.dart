/// Test data isolation utilities for preventing cross-test contamination
///
/// Provides data namespacing and isolation strategies to ensure
/// tests don't affect each other when using shared resources.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../infrastructure/mocks/firestore_singleton.dart';

/// Helper class for test data isolation
class TestDataIsolator {
  TestDataIsolator._();

  static String? _currentTestName;
  static final Map<String, String> _testPrefixes = {};
  static int _testCounter = 0;

  /// Initialize isolation for a specific test
  static void initializeTest(String testName) {
    _currentTestName = testName;
    _testCounter++;

    // Create unique prefix for this test.
    // Intentionally uses real-clock millisecond epoch so prefixes are unique
    // across test runs (fakeAsync clock starts at epoch 0, which would collide).
    // ignore: butlery_fake_time
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = 'test_${_testCounter}_${timestamp}_';
    _testPrefixes[testName] = prefix;

    // Inform FirestoreSingleton about current test
    FirestoreSingleton.setCurrentTest(testName);

    debugPrint(
        'Initialized test isolation for: $testName with prefix: $prefix');
  }

  /// Get isolated collection name for current test
  static String isolateCollection(String baseCollection) {
    if (_currentTestName == null) {
      debugPrint(
          'Warning: No test isolation active, using base collection name');
      return baseCollection;
    }

    final prefix = _testPrefixes[_currentTestName];
    if (prefix == null) {
      return baseCollection;
    }

    // For some core collections, don't isolate (to maintain compatibility)
    final nonIsolatedCollections = [
      'users',
      'test_collection', // Used by base repository tests
      'realtime_recipes', // Used by collaboration tests
    ];

    if (nonIsolatedCollections.contains(baseCollection)) {
      return baseCollection;
    }

    return '$prefix$baseCollection';
  }

  /// Get isolated document ID for current test
  static String isolateDocumentId(String baseId) {
    if (_currentTestName == null) {
      return baseId;
    }

    final prefix = _testPrefixes[_currentTestName];
    if (prefix == null) {
      return baseId;
    }

    return '$prefix$baseId';
  }

  /// Create isolated test data with unique IDs
  static Map<String, dynamic> isolateData(Map<String, dynamic> data) {
    if (_currentTestName == null) {
      return data;
    }

    final prefix = _testPrefixes[_currentTestName];
    if (prefix == null) {
      return data;
    }

    final isolatedData = Map<String, dynamic>.from(data);

    // Isolate ID fields
    if (isolatedData.containsKey('id')) {
      isolatedData['id'] = '$prefix${isolatedData['id']}';
    }
    if (isolatedData.containsKey('userId')) {
      isolatedData['userId'] = '$prefix${isolatedData['userId']}';
    }
    if (isolatedData.containsKey('ownerId')) {
      isolatedData['ownerId'] = '$prefix${isolatedData['ownerId']}';
    }

    return isolatedData;
  }

  /// Clean up test isolation
  static Future<void> cleanupTest(String testName) async {
    if (testName == _currentTestName) {
      _currentTestName = null;
    }
    _testPrefixes.remove(testName);

    // Clear Firestore data for this test
    await FirestoreSingleton.clearData();
  }

  /// Reset all isolation
  static void reset() {
    _currentTestName = null;
    _testPrefixes.clear();
    _testCounter = 0;
  }

  /// Get current test name
  static String? get currentTest => _currentTestName;

  /// Check if isolation is active
  static bool get isActive => _currentTestName != null;

  /// Get current test prefix
  static String? get currentPrefix {
    if (_currentTestName == null) return null;
    return _testPrefixes[_currentTestName];
  }
}

/// Mixin for test classes that need data isolation
mixin TestDataIsolationMixin {
  String get testName => runtimeType.toString();

  /// Initialize isolation for this test
  void setupIsolation() {
    TestDataIsolator.initializeTest(testName);
  }

  /// Clean up isolation for this test
  Future<void> cleanupIsolation() async {
    await TestDataIsolator.cleanupTest(testName);
  }

  /// Get isolated collection name
  String isolated(String collection) {
    return TestDataIsolator.isolateCollection(collection);
  }

  /// Get isolated document ID
  String isolatedId(String id) {
    return TestDataIsolator.isolateDocumentId(id);
  }

  /// Create isolated data
  Map<String, dynamic> isolatedData(Map<String, dynamic> data) {
    return TestDataIsolator.isolateData(data);
  }
}

/// Extension for Firestore references to use isolation
extension FirestoreIsolationExtensions on FirebaseFirestore {
  /// Get isolated collection reference
  CollectionReference<Map<String, dynamic>> isolatedCollection(String path) {
    return collection(TestDataIsolator.isolateCollection(path));
  }

  /// Get isolated document reference
  DocumentReference<Map<String, dynamic>> isolatedDoc(
      String collectionPath, String docId) {
    return collection(TestDataIsolator.isolateCollection(collectionPath))
        .doc(TestDataIsolator.isolateDocumentId(docId));
  }
}

/// Test group helper with automatic isolation
void isolatedTestGroup(
  String description,
  void Function() body, {
  bool skip = false,
}) {
  group(description, () {
    setUp(() {
      TestDataIsolator.initializeTest(description);
    });

    tearDown(() async {
      await TestDataIsolator.cleanupTest(description);
    });

    tearDownAll(() {
      TestDataIsolator.reset();
    });

    body();
  }, skip: skip);
}

/// Individual test helper with automatic isolation
void isolatedTest(
  String description,
  Future<void> Function() body, {
  bool skip = false,
  Timeout? timeout,
}) {
  test(description, () async {
    TestDataIsolator.initializeTest(description);
    try {
      await body();
    } finally {
      await TestDataIsolator.cleanupTest(description);
    }
  }, skip: skip, timeout: timeout);
}

/// Helper class for creating isolated test data
class IsolatedTestData {
  final String testName;
  final String prefix;

  IsolatedTestData._(this.testName, this.prefix);

  /// Create isolated test data for current test
  factory IsolatedTestData.current() {
    final testName = TestDataIsolator.currentTest;
    final prefix = TestDataIsolator.currentPrefix;

    if (testName == null || prefix == null) {
      throw StateError(
          'No test isolation active. Call TestDataIsolator.initializeTest first.');
    }

    return IsolatedTestData._(testName, prefix);
  }

  /// Create isolated user ID
  String userId([String base = 'user']) => '$prefix$base';

  /// Create isolated document ID
  String docId([String base = 'doc']) => '$prefix$base';

  /// Create isolated collection name
  String collection([String base = 'collection']) => '$prefix$base';

  /// Create isolated email
  String email([String base = 'user']) => '$prefix$base@test.com';

  /// Create isolated display name
  String displayName([String base = 'User']) => '$prefix $base';

  /// Create batch of isolated IDs
  List<String> batchIds(String base, int count) {
    return List.generate(count, (i) => '$prefix${base}_$i');
  }

  /// Create isolated test data map
  Map<String, dynamic> createData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final isolatedData = Map<String, dynamic>.from(data);
    isolatedData['id'] = docId(id);

    // Isolate common ID fields
    if (isolatedData.containsKey('userId')) {
      isolatedData['userId'] = userId(isolatedData['userId']);
    }
    if (isolatedData.containsKey('ownerId')) {
      isolatedData['ownerId'] = userId(isolatedData['ownerId']);
    }
    if (isolatedData.containsKey('createdBy')) {
      isolatedData['createdBy'] = userId(isolatedData['createdBy']);
    }

    return isolatedData;
  }
}
