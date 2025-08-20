/// Async test helper utilities for operation synchronization
///
/// Provides helpers to ensure async operations complete properly
/// and data is available when expected in tests.
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for async operation synchronization in tests
class AsyncTestHelper {
  AsyncTestHelper._();

  /// Wait for a Firestore write operation to complete and be queryable
  static Future<void> waitForFirestoreWrite({
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    // Firestore writes are eventually consistent
    // Wait for the write to propagate
    await Future.delayed(delay);

    // Pump event queue to ensure all async operations complete
    await pumpEventQueue();
  }

  /// Wait for multiple Firestore operations to complete
  static Future<void> waitForFirestoreOperations(
    List<Future> operations, {
    Duration postDelay = const Duration(milliseconds: 100),
  }) async {
    // Wait for all operations to complete
    await Future.wait(operations);

    // Additional delay for eventual consistency
    await Future.delayed(postDelay);

    // Pump event queue
    await pumpEventQueue();
  }

  /// Execute an operation and wait for it to be queryable
  static Future<T> executeAndWait<T>(
    Future<T> Function() operation, {
    Duration postDelay = const Duration(milliseconds: 100),
  }) async {
    final result = await operation();
    await Future.delayed(postDelay);
    await pumpEventQueue();
    return result;
  }

  /// Retry an operation until it succeeds or times out
  static Future<T> retryUntilSuccess<T>(
    Future<T> Function() operation, {
    bool Function(T)? isSuccess,
    Duration retryDelay = const Duration(milliseconds: 100),
    Duration timeout = const Duration(seconds: 5),
    int maxRetries = 50,
  }) async {
    final stopwatch = Stopwatch()..start();
    int attempts = 0;

    while (attempts < maxRetries && stopwatch.elapsed < timeout) {
      try {
        final result = await operation();

        // If no success condition specified, return on first successful result
        if (isSuccess == null || isSuccess(result)) {
          return result;
        }
      } catch (e) {
        // Continue retrying on errors
        debugPrint('Retry attempt $attempts failed: $e');
      }

      attempts++;
      await Future.delayed(retryDelay);
    }

    throw TimeoutException(
      'Operation did not succeed after $attempts attempts in ${stopwatch.elapsed}',
    );
  }

  /// Wait for a document to exist in Firestore
  static Future<DocumentSnapshot> waitForDocument(
    DocumentReference doc, {
    Duration timeout = const Duration(seconds: 5),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    return retryUntilSuccess(
      () async {
        final snapshot = await doc.get();
        if (!snapshot.exists) {
          throw Exception('Document does not exist yet');
        }
        return snapshot;
      },
      timeout: timeout,
      retryDelay: checkInterval,
    );
  }

  /// Wait for a collection to have expected number of documents
  static Future<QuerySnapshot> waitForCollection(
    CollectionReference collection, {
    required int expectedCount,
    Duration timeout = const Duration(seconds: 5),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    return retryUntilSuccess(
      () async {
        final snapshot = await collection.get();
        if (snapshot.docs.length != expectedCount) {
          throw Exception(
            'Collection has ${snapshot.docs.length} docs, expected $expectedCount',
          );
        }
        return snapshot;
      },
      timeout: timeout,
      retryDelay: checkInterval,
    );
  }

  /// Pump the event queue to ensure all microtasks complete
  static Future<void> pumpEventQueue() async {
    // Run through multiple event loop iterations
    for (int i = 0; i < 3; i++) {
      await Future(() {});
      await Future.microtask(() {});
    }
  }

  /// Wait for all pending timers to complete
  static Future<void> waitForTimers() async {
    // Use TestWidgetsFlutterBinding if available
    final binding = TestWidgetsFlutterBinding.instance;
    await binding.pump();
  }

  /// Execute operations in sequence with delays
  static Future<List<T>> executeSequentially<T>(
    List<Future<T> Function()> operations, {
    Duration delayBetween = const Duration(milliseconds: 50),
  }) async {
    final results = <T>[];

    for (final operation in operations) {
      final result = await operation();
      results.add(result);

      if (operation != operations.last) {
        await Future.delayed(delayBetween);
      }
    }

    return results;
  }

  /// Execute operations in parallel and wait for all
  static Future<List<T>> executeInParallel<T>(
    List<Future<T> Function()> operations, {
    Duration postDelay = const Duration(milliseconds: 100),
  }) async {
    final futures = operations.map((op) => op()).toList();
    final results = await Future.wait(futures);

    await Future.delayed(postDelay);
    await pumpEventQueue();

    return results;
  }

  /// Create a completer that times out
  static Completer<T> createTimedCompleter<T>({
    required Duration timeout,
    String? timeoutMessage,
  }) {
    final completer = Completer<T>();

    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException(
              timeoutMessage ?? 'Operation timed out after $timeout'),
        );
      }
    });

    return completer;
  }

  /// Wait for a future with timeout
  static Future<T> withTimeout<T>(
    Future<T> future, {
    Duration timeout = const Duration(seconds: 5),
    String? timeoutMessage,
  }) {
    return future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        timeoutMessage ?? 'Operation timed out after $timeout',
      ),
    );
  }

  /// Ensure data is initialized before proceeding
  static Future<void> ensureDataInitialized(
    Future<void> Function() initOperation, {
    Future<bool> Function()? verifyInitialized,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Execute initialization
    await initOperation();

    // Wait for propagation
    await waitForFirestoreWrite();

    // Verify if provided
    if (verifyInitialized != null) {
      await retryUntilSuccess(
        () async {
          final initialized = await verifyInitialized();
          if (!initialized) {
            throw Exception('Data not yet initialized');
          }
          return initialized;
        },
        timeout: timeout,
      );
    }
  }
}

/// Extension methods for async test operations
extension AsyncTestExtensions<T> on Future<T> {
  /// Execute this future and wait for it to be queryable
  Future<T> thenWait({
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    final result = await this;
    await AsyncTestHelper.waitForFirestoreWrite(delay: delay);
    return result;
  }

  /// Add timeout to this future
  Future<T> withTestTimeout({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return AsyncTestHelper.withTimeout(this, timeout: timeout);
  }
}

/// Mixin for tests that need async synchronization
mixin AsyncTestMixin {
  /// Wait for Firestore write
  Future<void> waitForWrite() => AsyncTestHelper.waitForFirestoreWrite();

  /// Execute and wait
  Future<T> executeAndWait<T>(Future<T> Function() operation) {
    return AsyncTestHelper.executeAndWait(operation);
  }

  /// Retry until success
  Future<T> retryUntil<T>(
    Future<T> Function() operation, {
    bool Function(T)? condition,
  }) {
    return AsyncTestHelper.retryUntilSuccess(
      operation,
      isSuccess: condition,
    );
  }

  /// Pump event queue
  Future<void> pumpEvents() => AsyncTestHelper.pumpEventQueue();
}
