/// Retry management with exponential backoff and circuit breaker pattern.
///
/// Provides intelligent retry coordination for failed uploads with circuit breaker
/// protection to prevent cascading failures and resource exhaustion.
///
/// **Architecture:** Service Layer - Resilience Infrastructure
/// **Responsibility:** Retry logic, backoff calculation, circuit breaker, error classification
/// **Used By:** ImageUploadService

// lib/services/upload/upload_retry_manager.dart

import 'dart:async';
import 'dart:math';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages retry logic and circuit breaker for upload resilience.
///
/// Core responsibilities:
/// - Error classification for targeted handling
/// - Exponential backoff with jitter calculation
/// - Circuit breaker state management
/// - Retry eligibility determination
/// - Retry strategy configuration per error type
class UploadRetryManager {
  /// Random instance for jitter calculations
  static final Random _random = Random();

  /// Circuit breaker states per error type
  final Map<ImageUploadErrorType, CircuitBreakerState> _circuitBreakers = {};

  /// Circuit breaker reset time (how long before trying again after circuit opens)
  static const Duration circuitBreakerResetTime = Duration(minutes: 5);

  /// Default retry strategies per error type
  static const Map<ImageUploadErrorType, RetryStrategy> _retryStrategies = {
    ImageUploadErrorType.network: RetryStrategy(
      autoRetry: true,
      maxAttempts: 3,
      description: 'Network errors are automatically retried',
    ),
    ImageUploadErrorType.server: RetryStrategy(
      autoRetry: true,
      maxAttempts: 3,
      description: 'Server errors are automatically retried',
    ),
    ImageUploadErrorType.validation: RetryStrategy(
      autoRetry: false,
      maxAttempts: 1,
      description: 'Validation errors require user action',
    ),
    ImageUploadErrorType.cancelled: RetryStrategy(
      autoRetry: false,
      maxAttempts: 0,
      description: 'Cancelled uploads are not retried',
    ),
    ImageUploadErrorType.unknown: RetryStrategy(
      autoRetry: true,
      maxAttempts: 2,
      description: 'Unknown errors get limited retries',
    ),
  };

  // ===== ERROR CLASSIFICATION =====

  /// Classify error from exception for targeted handling
  ImageUploadErrorType classifyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable')) {
      return ImageUploadErrorType.network;
    }

    if (errorString.contains('permission') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('size') ||
        errorString.contains('format') ||
        errorString.contains('validation')) {
      return ImageUploadErrorType.validation;
    }

    if (errorString.contains('server') ||
        errorString.contains('firebase') ||
        errorString.contains('storage') ||
        errorString.contains('internal')) {
      return ImageUploadErrorType.server;
    }

    if (errorString.contains('cancel')) {
      return ImageUploadErrorType.cancelled;
    }

    return ImageUploadErrorType.unknown;
  }

  // ===== RETRY DELAY CALCULATION =====

  /// Calculate retry delay with exponential backoff and jitter
  ///
  /// Uses full jitter algorithm to prevent thundering herd:
  /// - Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 30s)
  /// - Full jitter: Random delay from 0% to 100% of base delay
  /// - Minimum delay: 1 second
  Duration calculateRetryDelay(int attemptNumber) {
    // Exponential backoff with cap: 1s, 2s, 4s, 8s, 16s (max 30s)
    final exponent = min(attemptNumber, 4); // Cap at 16 seconds base delay
    final baseDelaySeconds = 1 * (1 << exponent);
    final maxDelaySeconds = min(baseDelaySeconds, 30); // Hard cap at 30 seconds

    // Full jitter algorithm (0% to 100% of base delay)
    // More effective at preventing thundering herd than additive jitter
    final jitterFactor = _random.nextDouble(); // 0.0 to 1.0
    final jitteredDelay = (maxDelaySeconds * jitterFactor).round();

    final finalDelay =
        Duration(seconds: max(jitteredDelay, 1)); // Minimum 1 second

    AppLogger.info(
        '🔄 RETRY_BACKOFF: Attempt $attemptNumber -> ${finalDelay.inSeconds}s delay (base: ${maxDelaySeconds}s, jitter: ${jitterFactor.toStringAsFixed(2)})');

    return finalDelay;
  }

  // ===== RETRY ELIGIBILITY =====

  /// Check if upload should be retried based on current status
  bool shouldRetry(ImageUploadStatus status) {
    if (!status.hasError) return false;
    if (status.state == ImageUploadState.cancelled) return false;
    if (status.retryAttempts >= status.maxRetryAttempts) return false;

    // Check circuit breaker
    final errorType = status.errorType ?? ImageUploadErrorType.unknown;
    if (isCircuitBreakerOpen(errorType)) {
      AppLogger.warning(
          '🔄 RETRY: Circuit breaker open for ${errorType.name}, blocking retry');
      return false;
    }

    // Check retry strategy
    final strategy = getRetryStrategy(errorType);
    if (!strategy.autoRetry && status.retryAttempts > 0) {
      return false; // Non-auto-retry errors only get one manual retry
    }

    return true;
  }

  /// Get retry strategy for error type
  RetryStrategy getRetryStrategy(ImageUploadErrorType errorType) {
    return _retryStrategies[errorType] ??
        const RetryStrategy(
          autoRetry: false,
          maxAttempts: 0,
          description: 'No retry strategy defined',
        );
  }

  // ===== CIRCUIT BREAKER =====

  /// Check if circuit breaker is open for error type
  bool isCircuitBreakerOpen(ImageUploadErrorType errorType) {
    final state = _getCircuitBreakerState(errorType);

    // Check if should reset (timeout elapsed)
    if (state.shouldReset(circuitBreakerResetTime)) {
      _circuitBreakers[errorType] = state.reset();
      AppLogger.info('🔄 CIRCUIT_BREAKER: Reset for ${errorType.name}');
      return false;
    }

    return state.isOpen;
  }

  /// Get circuit breaker state for error type
  CircuitBreakerState _getCircuitBreakerState(ImageUploadErrorType errorType) {
    return _circuitBreakers[errorType] ??
        const CircuitBreakerState(
          failureCount: 0,
          lastFailureTime: null,
          isOpen: false,
        );
  }

  /// Record failure and update circuit breaker
  void recordFailure(ImageUploadErrorType errorType) {
    final currentState = _getCircuitBreakerState(errorType);
    final newState = currentState.withFailure();
    _circuitBreakers[errorType] = newState;

    if (newState.isOpen && !currentState.isOpen) {
      AppLogger.warning(
          '🔄 CIRCUIT_BREAKER: Opened for ${errorType.name} after ${newState.failureCount} failures');
    }

    AppLogger.debug(
        '🔄 CIRCUIT_BREAKER: Recorded failure for ${errorType.name} (count: ${newState.failureCount})');
  }

  /// Record success and potentially reset circuit breaker
  void recordSuccess() {
    // Check if any circuit breakers were open
    final hadOpenBreaker =
        _circuitBreakers.values.any((state) => state.isOpen);

    if (hadOpenBreaker) {
      // Reset all circuit breakers on success
      _circuitBreakers.clear();
      AppLogger.info('🔄 CIRCUIT_BREAKER: Reset all breakers after success');
    }
  }

  /// Reset circuit breaker for specific error type
  void resetCircuitBreaker(ImageUploadErrorType errorType) {
    _circuitBreakers[errorType] = const CircuitBreakerState(
      failureCount: 0,
      lastFailureTime: null,
      isOpen: false,
    );
    AppLogger.info('🔄 CIRCUIT_BREAKER: Manually reset for ${errorType.name}');
  }

  /// Clear all circuit breakers
  void clearAllCircuitBreakers() {
    _circuitBreakers.clear();
    AppLogger.info('🔄 CIRCUIT_BREAKER: Cleared all');
  }

  // ===== RETRY EXECUTION =====

  /// Prepare status for retry attempt
  ImageUploadStatus prepareRetry(ImageUploadStatus currentStatus) {
    final newAttemptNumber = currentStatus.retryAttempts + 1;
    final retryDelay = calculateRetryDelay(currentStatus.retryAttempts);

    return currentStatus.copyWith(
      state: ImageUploadState.retrying,
      retryAttempts: newAttemptNumber,
      retryDelay: retryDelay,
      nextRetryAt: DateTime.now().add(retryDelay),
      // Clear progress from previous attempt
      progress: 0.0,
      bytesTransferred: null,
      uploadSpeedBytesPerSecond: null,
      estimatedTimeRemaining: null,
    );
  }

  /// Wait for retry delay
  Future<void> waitForRetryDelay(Duration delay) async {
    AppLogger.info('🔄 RETRY: Waiting ${delay.inSeconds}s before retry...');
    await Future.delayed(delay);
  }
}
