/// Enhanced base test class that enforces proper cleanup
/// 
/// This base class ensures all tests have proper tearDown and stream cleanup
/// to prevent memory leaks and test pollution.
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/mocks/firestore_singleton.dart';
import 'base_unit_test.dart';
import 'stream_test_manager.dart';

/// Base test class that enforces cleanup
abstract class BaseTestWithCleanup {
  /// Track all stream subscriptions for automatic cleanup
  static final List<StreamSubscription> _subscriptions = [];
  
  /// Track all stream controllers for automatic cleanup
  static final List<StreamController> _controllers = [];
  
  /// Track if setup was called
  static bool _setupCalled = false;
  
  /// Setup that MUST be called in setUp()
  static Future<void> setupTestWithCleanup() async {
    _setupCalled = true;
    
    // Initialize base test infrastructure
    await BaseUnitTest.setupUnit();
    
    // Initialize service locator
    await TestServiceLocator.initialize();
    
    // Clear Firestore data for test isolation
    await FirestoreSingleton.clearData();
    
    // Clear any previous subscriptions/controllers (defensive)
    await _cleanupStreams();
  }
  
  /// TearDown that MUST be called in tearDown()
  static Future<void> tearDownTestWithCleanup() async {
    if (!_setupCalled) {
      throw StateError(
        'tearDownTestWithCleanup called without setupTestWithCleanup! '
        'Ensure you call setupTestWithCleanup() in your setUp() method.',
      );
    }
    
    try {
      // Clean up all streams using StreamTestManager
      await StreamTestManager.cleanupAll();
      
      // Also clean up our local tracking (for backwards compatibility)
      await _cleanupStreams();
      
      // Clear service locator state
      await TestServiceLocator.clearState();
      
      // Clear Firestore data
      await FirestoreSingleton.clearData();
      
      // Reset all mocks
      resetMocktailState();
      
      // Small delay for garbage collection
      await Future.delayed(Duration(milliseconds: 5));
    } finally {
      _setupCalled = false;
    }
  }
  
  /// Complete reset (for tearDownAll)
  static Future<void> completeReset() async {
    await StreamTestManager.cleanupAll();
    await _cleanupStreams();
    await TestServiceLocator.reset();
    await FirestoreSingleton.hardReset();
    StreamTestManager.reset();
    _setupCalled = false;
  }
  
  /// Register a stream subscription for automatic cleanup
  static void registerSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
    // Also track with StreamTestManager for double safety
    StreamTestManager.track(subscription);
  }
  
  /// Register a stream controller for automatic cleanup
  static void registerController(StreamController controller) {
    _controllers.add(controller);
    // Also track with StreamTestManager for double safety
    StreamTestManager.trackController(controller);
  }
  
  /// Clean up all streams
  static Future<void> _cleanupStreams() async {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      try {
        await subscription.cancel();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    _subscriptions.clear();
    
    // Close all controllers
    for (final controller in _controllers) {
      try {
        if (!controller.isClosed) {
          await controller.close();
        }
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    _controllers.clear();
  }
  
  /// Verify cleanup was called (for testing the test infrastructure)
  static void verifyCleanup() {
    if (_setupCalled) {
      throw StateError(
        'Test did not call tearDownTestWithCleanup()! '
        'This will cause memory leaks. Add tearDown(() async => '
        'await BaseTestWithCleanup.tearDownTestWithCleanup());',
      );
    }
    
    if (_subscriptions.isNotEmpty) {
      throw StateError(
        'Test has ${_subscriptions.length} uncleaned stream subscriptions!',
      );
    }
    
    if (_controllers.isNotEmpty) {
      throw StateError(
        'Test has ${_controllers.length} uncleaned stream controllers!',
      );
    }
  }
}

/// Mixin to enforce cleanup in test classes
mixin TestCleanupMixin {
  /// Called in setUp - must be overridden
  @mustCallSuper
  Future<void> setUpWithCleanup() async {
    await BaseTestWithCleanup.setupTestWithCleanup();
  }
  
  /// Called in tearDown - must be overridden
  @mustCallSuper
  Future<void> tearDownWithCleanup() async {
    await BaseTestWithCleanup.tearDownTestWithCleanup();
  }
  
  /// Called in tearDownAll - optional
  Future<void> tearDownAllWithCleanup() async {
    await BaseTestWithCleanup.completeReset();
  }
}

/// Helper to wrap test groups with automatic cleanup
void testGroupWithCleanup(
  String description,
  void Function() body, {
  bool skip = false,
}) {
  group(description, () {
    setUp(() async {
      await BaseTestWithCleanup.setupTestWithCleanup();
    });
    
    tearDown(() async {
      await BaseTestWithCleanup.tearDownTestWithCleanup();
    });
    
    tearDownAll(() async {
      await BaseTestWithCleanup.completeReset();
    });
    
    body();
  }, skip: skip);
}

/// Helper to wrap individual tests with automatic cleanup
void testWithCleanup(
  String description,
  Future<void> Function() body, {
  bool skip = false,
  Timeout? timeout,
}) {
  test(description, () async {
    await BaseTestWithCleanup.setupTestWithCleanup();
    try {
      await body();
    } finally {
      await BaseTestWithCleanup.tearDownTestWithCleanup();
    }
  }, skip: skip, timeout: timeout);
}