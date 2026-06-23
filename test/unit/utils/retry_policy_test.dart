/// Tests for `withRetry` — the generic exponential-backoff helper used on
/// user-initiated network calls (image upload retry, recipe save, share-extract).
///
/// Behaviour verified:
/// 1. Succeeds on the first try with no sleeps.
/// 2. Succeeds after N transient failures (sleeps between attempts).
/// 3. Gives up and rethrows after `maxAttempts` exceeded.
/// 4. Does NOT retry non-retryable errors (rethrows immediately).
/// 5. Jitter on each delay stays inside ±jitterFraction of the base.
library;

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/utils/retry_policy.dart';

void main() {
  group('withRetry', () {
    test('succeeds on first attempt with no sleep', () async {
      var calls = 0;
      final sleeps = <Duration>[];

      final result = await withRetry<int>(
        () async {
          calls += 1;
          return 42;
        },
        sleeper: (d) async => sleeps.add(d),
      );

      expect(result, 42);
      expect(calls, 1);
      expect(sleeps, isEmpty);
    });

    test('succeeds after 2 transient failures (3rd attempt)', () async {
      var calls = 0;
      final sleeps = <Duration>[];

      final result = await withRetry<String>(
        () async {
          calls += 1;
          if (calls < 3) {
            throw const SocketException('flaky wifi');
          }
          return 'ok';
        },
        sleeper: (d) async => sleeps.add(d),
        random: () => 0.5, // Centre of jitter range → no offset
      );

      expect(result, 'ok');
      expect(calls, 3);
      expect(sleeps, hasLength(2)); // 2 sleeps between 3 attempts
    });

    test('gives up after maxAttempts and rethrows last error', () async {
      var calls = 0;

      Future<void> run() => withRetry<void>(
        () async {
          calls += 1;
          throw SocketException('attempt $calls failed');
        },
        sleeper: (_) async {}, // Skip real waits
        random: () => 0.5,
      );

      await expectLater(
        run,
        throwsA(
          isA<SocketException>().having(
            (e) => e.message,
            'message',
            'attempt 3 failed',
          ),
        ),
      );
      expect(calls, 3);
    });

    test('does not retry non-retryable errors (StateError)', () async {
      var calls = 0;
      final sleeps = <Duration>[];

      Future<void> run() => withRetry<void>(
        () async {
          calls += 1;
          throw StateError('user bug — do not retry');
        },
        sleeper: (d) async => sleeps.add(d),
      );

      await expectLater(run, throwsStateError);
      expect(calls, 1);
      expect(sleeps, isEmpty);
    });

    test('does not retry FirebaseException permission-denied', () async {
      var calls = 0;

      Future<void> run() => withRetry<void>(
        () async {
          calls += 1;
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'denied',
          );
        },
        sleeper: (_) async {},
      );

      await expectLater(run, throwsA(isA<FirebaseException>()));
      expect(calls, 1);
    });

    test('does retry FirebaseException unavailable', () async {
      var calls = 0;
      final sleeps = <Duration>[];

      final result = await withRetry<String>(
        () async {
          calls += 1;
          if (calls < 2) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
              message: 'temporary',
            );
          }
          return 'recovered';
        },
        sleeper: (d) async => sleeps.add(d),
        random: () => 0.5,
      );

      expect(result, 'recovered');
      expect(calls, 2);
      expect(sleeps, hasLength(1));
    });

    test('respects custom isRetryable predicate', () async {
      var calls = 0;
      final sleeps = <Duration>[];

      final result = await withRetry<int>(
        () async {
          calls += 1;
          if (calls < 2) {
            throw FormatException('bad data');
          }
          return 1;
        },
        isRetryable: (e) => e is FormatException, // Override default
        sleeper: (d) async => sleeps.add(d),
        random: () => 0.5,
      );

      expect(result, 1);
      expect(calls, 2);
      expect(sleeps, hasLength(1));
    });

    test('jitter stays inside ±jitterFraction of the base delay', () {
      // With random=0.0 → max negative jitter; random=1.0 → max positive
      const base = Duration(seconds: 1);
      const fraction = 0.25;

      final scheduleMin = debugComputeSchedule(
        maxAttempts: 4,
        initialDelay: base,
        jitterFraction: fraction,
        random: () => 0.0,
      );
      final scheduleMax = debugComputeSchedule(
        maxAttempts: 4,
        initialDelay: base,
        jitterFraction: fraction,
        random: () => 1.0,
      );
      final scheduleCentre = debugComputeSchedule(
        maxAttempts: 4,
        initialDelay: base,
        jitterFraction: fraction,
        random: () => 0.5,
      );

      // Attempt 1 base = 1s, attempt 2 = 2s, attempt 3 = 4s
      // ±25% bounds:
      //   1s ∈ [0.75, 1.25]
      //   2s ∈ [1.5, 2.5]
      //   4s ∈ [3.0, 5.0]
      expect(scheduleMin, hasLength(3));
      expect(scheduleMin[0].inMilliseconds, 750);
      expect(scheduleMin[1].inMilliseconds, 1500);
      expect(scheduleMin[2].inMilliseconds, 3000);

      expect(scheduleMax[0].inMilliseconds, 1250);
      expect(scheduleMax[1].inMilliseconds, 2500);
      expect(scheduleMax[2].inMilliseconds, 5000);

      expect(scheduleCentre[0].inMilliseconds, 1000);
      expect(scheduleCentre[1].inMilliseconds, 2000);
      expect(scheduleCentre[2].inMilliseconds, 4000);
    });

    test('respects maxDelay cap', () {
      // Base 10s, maxAttempts 6 → would naturally grow 10s, 20s, 40s, 80s, 160s
      // But maxDelay caps at 30s
      final schedule = debugComputeSchedule(
        maxAttempts: 6,
        initialDelay: const Duration(seconds: 10),
        maxDelay: const Duration(seconds: 30),
        jitterFraction: 0.0, // No jitter for clean assertion
        random: () => 0.5,
      );

      expect(schedule.map((d) => d.inSeconds).toList(), [
        10,
        20,
        30,
        30,
        30,
      ]); // 5 sleeps for 6 attempts
    });

    test('TimeoutException is retried', () async {
      var calls = 0;
      final result = await withRetry<int>(
        () async {
          calls += 1;
          if (calls < 2) throw TimeoutException('slow');
          return 7;
        },
        sleeper: (_) async {},
        random: () => 0.5,
      );
      expect(result, 7);
      expect(calls, 2);
    });

    test('maxAttempts=1 means no retries', () async {
      var calls = 0;
      Future<void> run() => withRetry<void>(
        () async {
          calls += 1;
          throw const SocketException('flaky');
        },
        maxAttempts: 1,
        sleeper: (_) async {},
      );
      await expectLater(run, throwsA(isA<SocketException>()));
      expect(calls, 1);
    });
  });
}
