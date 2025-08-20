/// Stream management utilities for tests to prevent memory leaks
/// 
/// Automatically tracks and cleans up stream subscriptions and controllers
/// to ensure proper resource management in tests.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Manager for tracking and cleaning up streams in tests
class StreamTestManager {
  StreamTestManager._();
  
  /// Global list of active subscriptions
  static final List<StreamSubscription> _activeSubscriptions = [];
  
  /// Global list of active controllers
  static final List<StreamController> _activeControllers = [];
  
  /// Map of test-specific subscriptions
  static final Map<String, List<StreamSubscription>> _testSubscriptions = {};
  
  /// Map of test-specific controllers
  static final Map<String, List<StreamController>> _testControllers = {};
  
  /// Track and register a stream subscription
  static StreamSubscription<T> track<T>(
    StreamSubscription<T> subscription, {
    String? testName,
  }) {
    _activeSubscriptions.add(subscription);
    
    if (testName != null) {
      _testSubscriptions.putIfAbsent(testName, () => []).add(subscription);
    }
    
    return subscription;
  }
  
  /// Track and register a stream controller
  static StreamController<T> trackController<T>(
    StreamController<T> controller, {
    String? testName,
  }) {
    _activeControllers.add(controller);
    
    if (testName != null) {
      _testControllers.putIfAbsent(testName, () => []).add(controller);
    }
    
    return controller;
  }
  
  /// Create a tracked broadcast stream controller
  static StreamController<T> createBroadcastController<T>({
    String? testName,
    void Function()? onListen,
    void Function()? onCancel,
    bool sync = false,
  }) {
    final controller = StreamController<T>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
      sync: sync,
    );
    
    return trackController(controller, testName: testName);
  }
  
  /// Create a tracked single subscription stream controller
  static StreamController<T> createController<T>({
    String? testName,
    void Function()? onListen,
    void Function()? onPause,
    void Function()? onResume,
    void Function()? onCancel,
    bool sync = false,
  }) {
    final controller = StreamController<T>(
      onListen: onListen,
      onPause: onPause,
      onResume: onResume,
      onCancel: onCancel,
      sync: sync,
    );
    
    return trackController(controller, testName: testName);
  }
  
  /// Listen to a stream with automatic tracking
  static StreamSubscription<T> listen<T>(
    Stream<T> stream,
    void Function(T event) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    String? testName,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    
    return track(subscription, testName: testName);
  }
  
  /// Clean up all streams for a specific test
  static Future<void> cleanupTest(String testName) async {
    // Cancel subscriptions for this test
    final subs = _testSubscriptions[testName];
    if (subs != null) {
      for (final sub in subs) {
        try {
          await sub.cancel();
          _activeSubscriptions.remove(sub);
        } catch (e) {
          debugPrint('Error cancelling subscription: $e');
        }
      }
      _testSubscriptions.remove(testName);
    }
    
    // Close controllers for this test
    final controllers = _testControllers[testName];
    if (controllers != null) {
      for (final controller in controllers) {
        try {
          if (!controller.isClosed) {
            await controller.close();
          }
          _activeControllers.remove(controller);
        } catch (e) {
          debugPrint('Error closing controller: $e');
        }
      }
      _testControllers.remove(testName);
    }
  }
  
  /// Clean up all tracked streams
  static Future<void> cleanupAll() async {
    // Cancel all subscriptions
    final subscriptionsCopy = List<StreamSubscription>.from(_activeSubscriptions);
    for (final subscription in subscriptionsCopy) {
      try {
        await subscription.cancel();
      } catch (e) {
        debugPrint('Error cancelling subscription: $e');
      }
    }
    _activeSubscriptions.clear();
    _testSubscriptions.clear();
    
    // Close all controllers
    final controllersCopy = List<StreamController>.from(_activeControllers);
    for (final controller in controllersCopy) {
      try {
        if (!controller.isClosed) {
          await controller.close();
        }
      } catch (e) {
        debugPrint('Error closing controller: $e');
      }
    }
    _activeControllers.clear();
    _testControllers.clear();
  }
  
  /// Get statistics about tracked streams
  static StreamStats get stats => StreamStats(
    activeSubscriptions: _activeSubscriptions.length,
    activeControllers: _activeControllers.length,
    testSubscriptions: _testSubscriptions.length,
    testControllers: _testControllers.length,
    openControllers: _activeControllers.where((c) => !c.isClosed).length,
  );
  
  /// Verify all streams are cleaned up
  static void verifyCleanup() {
    if (_activeSubscriptions.isNotEmpty) {
      throw StateError(
        'Test has ${_activeSubscriptions.length} uncancelled stream subscriptions! '
        'This will cause memory leaks.',
      );
    }
    
    if (_activeControllers.any((c) => !c.isClosed)) {
      final openCount = _activeControllers.where((c) => !c.isClosed).length;
      throw StateError(
        'Test has $openCount unclosed stream controllers! '
        'This will cause memory leaks.',
      );
    }
  }
  
  /// Reset the manager (for test infrastructure only)
  static void reset() {
    _activeSubscriptions.clear();
    _activeControllers.clear();
    _testSubscriptions.clear();
    _testControllers.clear();
  }
}

/// Statistics about tracked streams
class StreamStats {
  final int activeSubscriptions;
  final int activeControllers;
  final int testSubscriptions;
  final int testControllers;
  final int openControllers;
  
  const StreamStats({
    required this.activeSubscriptions,
    required this.activeControllers,
    required this.testSubscriptions,
    required this.testControllers,
    required this.openControllers,
  });
  
  /// Total number of tracked streams
  int get total => activeSubscriptions + activeControllers;
  
  /// Whether there are any active streams
  bool get hasActiveStreams => total > 0;
  
  /// Whether all streams are properly closed
  bool get allClosed => openControllers == 0 && activeSubscriptions == 0;
  
  @override
  String toString() {
    return 'StreamStats(subscriptions: $activeSubscriptions, '
        'controllers: $activeControllers, open: $openControllers)';
  }
}

/// Extension for easier stream tracking in tests
extension StreamTestExtensions<T> on Stream<T> {
  /// Listen to this stream with automatic tracking
  StreamSubscription<T> listenTracked(
    void Function(T event) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    String? testName,
  }) {
    return StreamTestManager.listen(
      this,
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
      testName: testName,
    );
  }
}

/// Extension for easier controller tracking
extension ControllerTestExtensions<T> on StreamController<T> {
  /// Track this controller for automatic cleanup
  StreamController<T> tracked({String? testName}) {
    return StreamTestManager.trackController(this, testName: testName);
  }
}

/// Mixin for tests that use streams
mixin StreamTestMixin {
  /// Clean up all streams for this test
  Future<void> cleanupStreams() async {
    await StreamTestManager.cleanupAll();
  }
  
  /// Create a tracked broadcast controller
  StreamController<T> createBroadcastController<T>() {
    return StreamTestManager.createBroadcastController<T>(
      testName: runtimeType.toString(),
    );
  }
  
  /// Create a tracked controller
  StreamController<T> createController<T>() {
    return StreamTestManager.createController<T>(
      testName: runtimeType.toString(),
    );
  }
  
  /// Listen to a stream with tracking
  StreamSubscription<T> listenTo<T>(
    Stream<T> stream,
    void Function(T event) onData,
  ) {
    return StreamTestManager.listen(
      stream,
      onData,
      testName: runtimeType.toString(),
    );
  }
}