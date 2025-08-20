/// Stream stabilization utilities for fixing test timing issues
///
/// Provides helpers to wait for streams to stabilize, filter out
/// stale emissions, and ensure proper synchronization in tests.
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for stabilizing streams in tests
class StreamStabilizer {
  StreamStabilizer._();

  /// Wait for a stream to emit its first stable value
  /// Filters out initial/cached emissions
  static Future<T> waitForStableEmission<T>(
    Stream<T> stream, {
    Duration stabilizationDelay = const Duration(milliseconds: 100),
    Duration timeout = const Duration(seconds: 5),
    bool Function(T)? isStable,
  }) async {
    final completer = Completer<T>();
    StreamSubscription<T>? subscription;
    Timer? stabilizationTimer;
    Timer? timeoutTimer;

    // Set timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        stabilizationTimer?.cancel();
        completer.completeError(
          TimeoutException('Stream did not stabilize within $timeout'),
        );
      }
    });

    T? lastValue;

    subscription = stream.listen(
      (value) {
        lastValue = value;

        // Cancel previous stabilization timer
        stabilizationTimer?.cancel();

        // Check if value is considered stable
        if (isStable != null && !isStable(value)) {
          return; // Wait for stable value
        }

        // Wait for stabilization delay to ensure no more emissions
        stabilizationTimer = Timer(stabilizationDelay, () {
          if (!completer.isCompleted && lastValue != null) {
            subscription?.cancel();
            timeoutTimer?.cancel();
            completer.complete(lastValue!);
          }
        });
      },
      onError: (error) {
        if (!completer.isCompleted) {
          subscription?.cancel();
          stabilizationTimer?.cancel();
          timeoutTimer?.cancel();
          completer.completeError(error);
        }
      },
    );

    return completer.future;
  }

  /// Collect stream emissions until stable
  /// Returns list of emissions after filtering out initial cached data
  static Future<List<T>> collectStableEmissions<T>(
    Stream<T> stream, {
    required int expectedCount,
    Duration stabilizationDelay = const Duration(milliseconds: 100),
    Duration timeout = const Duration(seconds: 5),
    bool skipInitial = true,
  }) async {
    final emissions = <T>[];
    final completer = Completer<List<T>>();
    StreamSubscription<T>? subscription;
    Timer? stabilizationTimer;
    Timer? timeoutTimer;

    // Set timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        stabilizationTimer?.cancel();
        if (emissions.isNotEmpty) {
          // Return what we have if we got some emissions
          completer.complete(emissions);
        } else {
          completer.completeError(
            TimeoutException(
                'Stream did not emit $expectedCount items within $timeout'),
          );
        }
      }
    });

    bool skippedInitial = false;

    subscription = stream.listen(
      (value) {
        // Skip first emission if requested (often cached data)
        if (skipInitial && !skippedInitial) {
          skippedInitial = true;
          return;
        }

        emissions.add(value);

        // Cancel previous stabilization timer
        stabilizationTimer?.cancel();

        if (emissions.length >= expectedCount) {
          // Wait for stabilization to ensure no more emissions
          stabilizationTimer = Timer(stabilizationDelay, () {
            if (!completer.isCompleted) {
              subscription?.cancel();
              timeoutTimer?.cancel();
              completer.complete(emissions);
            }
          });
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          subscription?.cancel();
          stabilizationTimer?.cancel();
          timeoutTimer?.cancel();
          completer.completeError(error);
        }
      },
    );

    return completer.future;
  }

  /// Wait for stream to emit specific number of updates
  /// Useful for tests that expect exact emission counts
  static Future<List<T>> waitForEmissions<T>(
    Stream<T> stream, {
    required int count,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final emissions = <T>[];
    final completer = Completer<List<T>>();
    StreamSubscription<T>? subscription;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.completeError(
          TimeoutException(
            'Expected $count emissions but got ${emissions.length} within $timeout',
          ),
        );
      }
    });

    subscription = stream.listen(
      (value) {
        emissions.add(value);
        if (emissions.length == count) {
          timer.cancel();
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(emissions);
          }
        }
      },
      onError: (error) {
        timer.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    return completer.future;
  }

  /// Create a stabilized stream that filters out rapid emissions
  /// Useful for debouncing stream updates in tests
  static Stream<T> createStabilizedStream<T>(
    Stream<T> source, {
    Duration debounceDelay = const Duration(milliseconds: 50),
  }) {
    Timer? debounceTimer;
    T? lastValue;
    bool hasValue = false;

    final controller = StreamController<T>.broadcast();

    final subscription = source.listen(
      (value) {
        lastValue = value;
        hasValue = true;

        debounceTimer?.cancel();
        debounceTimer = Timer(debounceDelay, () {
          if (hasValue && !controller.isClosed) {
            controller.add(lastValue as T);
          }
        });
      },
      onError: controller.addError,
      onDone: () {
        debounceTimer?.cancel();
        if (hasValue && !controller.isClosed) {
          controller.add(lastValue as T);
        }
        controller.close();
      },
    );

    controller.onCancel = () {
      debounceTimer?.cancel();
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Test helper to wait for async operations to complete
  /// More reliable than Future.delayed for test synchronization
  static Future<void> waitForAsync({
    Duration duration = const Duration(milliseconds: 100),
    int iterations = 1,
  }) async {
    for (int i = 0; i < iterations; i++) {
      await Future.delayed(duration);
      await pumpEventQueue();
    }
  }

  /// Pump the event queue to ensure all microtasks complete
  static Future<void> pumpEventQueue() async {
    await Future(() {});
    await Future.microtask(() {});
  }

  /// Wait for a condition to become true
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration checkInterval = const Duration(milliseconds: 50),
    Duration timeout = const Duration(seconds: 5),
    String? timeoutMessage,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (!condition()) {
      if (stopwatch.elapsed > timeout) {
        throw TimeoutException(
          timeoutMessage ?? 'Condition not met within $timeout',
        );
      }
      await Future.delayed(checkInterval);
    }
  }

  /// Create a test stream with controlled emissions
  static Stream<T> createTestStream<T>(
    List<T> values, {
    Duration emissionDelay = const Duration(milliseconds: 50),
    bool includeInitialDelay = true,
  }) async* {
    if (includeInitialDelay) {
      await Future.delayed(emissionDelay);
    }

    for (final value in values) {
      yield value;
      if (value != values.last) {
        await Future.delayed(emissionDelay);
      }
    }
  }
}

/// Extension for stream testing helpers
extension StreamTestingExtensions<T> on Stream<T> {
  /// Wait for this stream to stabilize and return first stable value
  Future<T> stabilized({
    Duration delay = const Duration(milliseconds: 100),
    bool Function(T)? isStable,
  }) {
    return StreamStabilizer.waitForStableEmission(
      this,
      stabilizationDelay: delay,
      isStable: isStable,
    );
  }

  /// Collect emissions from this stream
  Future<List<T>> collectEmissions({
    required int count,
    bool skipInitial = true,
  }) {
    return StreamStabilizer.collectStableEmissions(
      this,
      expectedCount: count,
      skipInitial: skipInitial,
    );
  }

  /// Create a debounced version of this stream
  Stream<T> debounced({
    Duration delay = const Duration(milliseconds: 50),
  }) {
    return StreamStabilizer.createStabilizedStream(
      this,
      debounceDelay: delay,
    );
  }
}

/// Matcher for stream emissions
class StreamEmissionMatcher<T> extends Matcher {
  final int expectedCount;
  final Duration timeout;
  final bool skipInitial;

  const StreamEmissionMatcher({
    required this.expectedCount,
    this.timeout = const Duration(seconds: 5),
    this.skipInitial = true,
  });

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Stream<T>) return false;

    try {
      final emissions = StreamStabilizer.collectStableEmissions<T>(
        item,
        expectedCount: expectedCount,
        timeout: timeout,
        skipInitial: skipInitial,
      );

      emissions.then((list) {
        matchState['emissions'] = list;
        matchState['count'] = list.length;
      }).catchError((error) {
        matchState['error'] = error;
      });

      return true;
    } catch (e) {
      matchState['error'] = e;
      return false;
    }
  }

  @override
  Description describe(Description description) {
    return description.add('stream to emit $expectedCount items');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription
          .add('failed with error: ${matchState['error']}');
    }
    if (matchState.containsKey('count')) {
      return mismatchDescription.add(
        'emitted ${matchState['count']} items instead of $expectedCount',
      );
    }
    return mismatchDescription.add('was not a Stream<$T>');
  }
}

/// Helper to create stream emission matchers
Matcher emitsCount<T>(int count) =>
    StreamEmissionMatcher<T>(expectedCount: count);
