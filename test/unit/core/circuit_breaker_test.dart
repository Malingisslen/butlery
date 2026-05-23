/// Unit tests for CircuitBreaker (P1-3 cascade-failure guard).
///
/// State machine: Closed → Open (after N failures) → Half-Open
/// (after resetTime) → Closed (on success) or Open (on failure).
/// Tests drive `clock.now()` via `withClock` to make the resetTime
/// transition deterministic.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/circuit_breaker.dart';

void main() {
  group('initial state (Closed)', () {
    test('allowRequest is true, isOpen is false', () {
      final cb = CircuitBreaker();
      expect(cb.allowRequest, isTrue);
      expect(cb.isOpen, isFalse);
      expect(cb.isHalfOpen, isFalse);
      expect(cb.failureCount, 0);
    });
  });

  group('failure accumulation', () {
    test('stays closed below threshold', () {
      final cb = CircuitBreaker(failureThreshold: 3);
      cb.recordFailure();
      cb.recordFailure();
      expect(cb.isOpen, isFalse);
      expect(cb.failureCount, 2);
    });

    test('opens at threshold', () {
      final cb = CircuitBreaker(failureThreshold: 3);
      cb.recordFailure();
      cb.recordFailure();
      cb.recordFailure();
      expect(cb.isOpen, isTrue);
      expect(cb.allowRequest, isFalse);
    });
  });

  group('recordSuccess', () {
    test('resets failure count and closes circuit', () {
      final cb = CircuitBreaker(failureThreshold: 3);
      cb.recordFailure();
      cb.recordFailure();
      cb.recordFailure();
      expect(cb.isOpen, isTrue);

      cb.recordSuccess();
      expect(cb.failureCount, 0);
      expect(cb.isOpen, isFalse);
      expect(cb.isHalfOpen, isFalse);
    });
  });

  group('half-open transition', () {
    test('after resetTime elapses, allowRequest returns true', () {
      final start = DateTime.utc(2026, 1, 1);
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTime: const Duration(seconds: 30),
      );
      withClock(Clock(() => start), () {
        cb.recordFailure();
        expect(cb.allowRequest, isFalse);
      });
      // 31 seconds later → resetTime exceeded → allowRequest flips
      withClock(Clock(() => start.add(const Duration(seconds: 31))), () {
        expect(cb.allowRequest, isTrue);
        expect(cb.isHalfOpen, isTrue);
      });
    });

    test('half-open + recordSuccess → fully closed', () {
      final start = DateTime.utc(2026, 1, 1);
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTime: const Duration(seconds: 30),
      );
      withClock(Clock(() => start), cb.recordFailure);
      expect(cb.isOpen, isTrue);

      // After reset time elapses, allowRequest flips to half-open.
      withClock(Clock(() => start.add(const Duration(seconds: 31))), () {
        expect(cb.allowRequest, isTrue); // half-open is true now
        expect(cb.isHalfOpen, isTrue);
        cb.recordSuccess();
      });
      expect(cb.isHalfOpen, isFalse);
      expect(cb.isOpen, isFalse);
      expect(cb.failureCount, 0);
    });

    test('half-open + recordFailure → stays open (failed recovery)', () {
      final start = DateTime.utc(2026, 1, 1);
      final cb = CircuitBreaker(
        failureThreshold: 1,
        resetTime: const Duration(seconds: 30),
      );
      withClock(Clock(() => start), cb.recordFailure);

      withClock(Clock(() => start.add(const Duration(seconds: 31))), () {
        expect(cb.allowRequest, isTrue); // half-open
        cb.recordFailure();
      });
      // After failed half-open test, stays open.
      expect(cb.isOpen, isTrue);
      expect(cb.isHalfOpen, isFalse);
    });
  });

  group('reset', () {
    test('clears all state to initial', () {
      final cb = CircuitBreaker(failureThreshold: 1);
      cb.recordFailure();
      cb.recordFailure();
      cb.reset();
      expect(cb.failureCount, 0);
      expect(cb.isOpen, isFalse);
      expect(cb.isHalfOpen, isFalse);
      expect(cb.allowRequest, isTrue);
    });
  });

  group('execute', () {
    test('returns operation result on success and records success', () async {
      final cb = CircuitBreaker(failureThreshold: 2);
      cb.recordFailure(); // one failure — not yet open

      final result = await cb.execute(() async => 42);
      expect(result, 42);
      expect(cb.failureCount, 0); // success reset
    });

    test('throws CircuitBreakerOpenException when circuit is open', () async {
      final cb = CircuitBreaker(failureThreshold: 1);
      cb.recordFailure(); // now open

      await expectLater(
        () => cb.execute(() async => 'never'),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('records failure and rethrows when operation throws', () async {
      final cb = CircuitBreaker(failureThreshold: 5);

      await expectLater(
        () => cb.execute(() async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      expect(cb.failureCount, 1);
    });
  });

  group('executeWithFallback', () {
    test('returns operation result on success', () async {
      final cb = CircuitBreaker();
      final result = await cb.executeWithFallback(() async => 'ok', 'fallback');
      expect(result, 'ok');
    });

    test('returns fallback when circuit is open', () async {
      final cb = CircuitBreaker(failureThreshold: 1);
      cb.recordFailure(); // open

      final result =
          await cb.executeWithFallback(() async => 'never', 'fallback');
      expect(result, 'fallback');
    });

    test('returns fallback and records failure when operation throws',
        () async {
      final cb = CircuitBreaker(failureThreshold: 5);
      final result = await cb.executeWithFallback(
          () async => throw StateError('boom'), 'fb');
      expect(result, 'fb');
      expect(cb.failureCount, 1);
    });
  });

  test('toString includes counts and open/halfOpen flags', () {
    final cb = CircuitBreaker(failureThreshold: 3);
    expect(cb.toString(), contains('failures: 0/3'));
  });

  test('CircuitBreakerOpenException toString prefixes class name', () {
    expect(
      CircuitBreakerOpenException('retry later').toString(),
      'CircuitBreakerOpenException: retry later',
    );
  });
}
