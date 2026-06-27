/// Circuit breaker pattern for protecting against cascading failures.
///
/// P1-3 Security Fix: Prevents cascade failures when Firestore or other
/// external services are experiencing outages. After a threshold of failures,
/// the circuit "opens" and requests are rejected immediately without
/// attempting the operation.
///
/// States:
/// - Closed: Normal operation, requests pass through
/// - Open: Failures exceeded threshold, requests rejected immediately
/// - Half-Open: After reset time, one request allowed to test recovery

import 'package:clock/clock.dart';

class CircuitBreaker {
  /// Number of failures before opening the circuit.
  final int failureThreshold;

  /// Time after which to attempt recovery (half-open state).
  final Duration resetTime;

  /// Current failure count.
  int _failureCount = 0;

  /// Last failure timestamp.
  DateTime? _lastFailureTime;

  /// Whether the circuit is currently open.
  bool _isOpen = false;

  /// Whether we're in half-open state (testing recovery).
  bool _isHalfOpen = false;

  /// BUT-1414: true once a half-open probe has been handed out and is still
  /// awaiting its outcome. Guarantees the "one request tests recovery" promise:
  /// while a probe is in flight, further callers are rejected so N queued
  /// requests don't all hit the recovering backend at once. Cleared by
  /// recordSuccess / recordFailure / reset.
  bool _halfOpenProbeInFlight = false;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTime = const Duration(minutes: 1),
  });

  /// Whether a request is currently allowed.
  ///
  /// Returns true if the circuit is closed, or if it is open but the reset time
  /// has elapsed AND no half-open probe is already in flight. This is a METHOD,
  /// not a getter (BUT-1414): it mutates state (marks a probe in flight), and a
  /// side-effecting getter is a maintenance trap.
  ///
  /// At the reset boundary exactly ONE caller is admitted to test recovery;
  /// concurrent callers get `false` until that probe resolves via
  /// recordSuccess / recordFailure. The caller MUST record the outcome (every
  /// production caller does), or the breaker stays latched in half-open.
  bool allowRequest() {
    if (!_isOpen) return true;

    // Check if enough time has passed to try recovery
    if (_lastFailureTime != null) {
      final elapsed = clock.now().difference(_lastFailureTime!);
      if (elapsed >= resetTime) {
        // Only the first caller at the boundary gets the probe slot.
        if (_halfOpenProbeInFlight) return false;
        _isHalfOpen = true;
        _halfOpenProbeInFlight = true;
        return true;
      }
    }

    return false;
  }

  /// Whether the circuit is currently open (blocking requests).
  bool get isOpen => _isOpen && !_isHalfOpen;

  /// Whether the circuit is in half-open state (testing recovery).
  bool get isHalfOpen => _isHalfOpen;

  /// Current failure count.
  int get failureCount => _failureCount;

  /// Record a successful operation.
  ///
  /// Resets the failure count and closes the circuit.
  void recordSuccess() {
    _failureCount = 0;
    _isOpen = false;
    _isHalfOpen = false;
    _halfOpenProbeInFlight = false;
  }

  /// Record a failed operation.
  ///
  /// Increments failure count and opens circuit if threshold exceeded.
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = clock.now();

    if (_isHalfOpen) {
      // Failed during recovery test, stay open
      _isHalfOpen = false;
      _isOpen = true;
    } else if (_failureCount >= failureThreshold) {
      _isOpen = true;
    }
    // The probe (if any) has resolved — release the half-open slot so the next
    // boundary can admit a fresh probe.
    _halfOpenProbeInFlight = false;
  }

  /// Reset the circuit breaker to initial state.
  void reset() {
    _failureCount = 0;
    _lastFailureTime = null;
    _isOpen = false;
    _isHalfOpen = false;
    _halfOpenProbeInFlight = false;
  }

  /// Execute an async operation with circuit breaker protection.
  ///
  /// Returns the result of [operation] if allowed, or throws
  /// [CircuitBreakerOpenException] if the circuit is open.
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (!allowRequest()) {
      throw CircuitBreakerOpenException(
        'Circuit breaker is open. Retry after ${resetTime.inSeconds}s.',
      );
    }

    try {
      final result = await operation();
      recordSuccess();
      return result;
    } catch (e) {
      recordFailure();
      rethrow;
    }
  }

  /// Execute an async operation with fallback on circuit open.
  ///
  /// Returns the result of [operation] if allowed, or [fallback] if
  /// the circuit is open.
  Future<T> executeWithFallback<T>(
    Future<T> Function() operation,
    T fallback,
  ) async {
    if (!allowRequest()) {
      return fallback;
    }

    try {
      final result = await operation();
      recordSuccess();
      return result;
    } catch (e) {
      recordFailure();
      return fallback;
    }
  }

  @override
  String toString() =>
      'CircuitBreaker(failures: $_failureCount/$failureThreshold, '
      'open: $_isOpen, halfOpen: $_isHalfOpen)';
}

/// Exception thrown when circuit breaker is open.
class CircuitBreakerOpenException implements Exception {
  final String message;

  CircuitBreakerOpenException(this.message);

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}
