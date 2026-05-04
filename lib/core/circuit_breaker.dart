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

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTime = const Duration(minutes: 1),
  });

  /// Whether requests are currently allowed.
  ///
  /// Returns true if circuit is closed or half-open.
  bool get allowRequest {
    if (!_isOpen) return true;

    // Check if enough time has passed to try recovery
    if (_lastFailureTime != null) {
      final elapsed = clock.now().difference(_lastFailureTime!);
      if (elapsed >= resetTime) {
        _isHalfOpen = true;
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
  }

  /// Reset the circuit breaker to initial state.
  void reset() {
    _failureCount = 0;
    _lastFailureTime = null;
    _isOpen = false;
    _isHalfOpen = false;
  }

  /// Execute an async operation with circuit breaker protection.
  ///
  /// Returns the result of [operation] if allowed, or throws
  /// [CircuitBreakerOpenException] if the circuit is open.
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (!allowRequest) {
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
    if (!allowRequest) {
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
