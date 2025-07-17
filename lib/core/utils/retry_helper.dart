// lib/core/utils/retry_helper.dart

import 'dart:math';
import 'logger.dart';

/// Utility class for handling retry logic with exponential backoff
class RetryHelper {
  /// Maximum number of retry attempts
  static const int defaultMaxRetries = 3;
  
  /// Base delay for exponential backoff (in milliseconds)
  static const int baseDelayMs = 1000;
  
  /// Maximum delay cap (in milliseconds)
  static const int maxDelayMs = 30000;

  /// Executes an operation with exponential backoff retry
  /// 
  /// [operation] - The async operation to retry
  /// [maxRetries] - Maximum number of retry attempts
  /// [baseDelay] - Base delay for exponential backoff
  /// [maxDelay] - Maximum delay cap
  /// [shouldRetry] - Function to determine if error should trigger retry
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = defaultMaxRetries,
    Duration baseDelay = const Duration(milliseconds: baseDelayMs),
    Duration maxDelay = const Duration(milliseconds: maxDelayMs),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(e)) {
          AppLogger.warning('Error not retryable: $e');
          rethrow;
        }
        
        // If this was the last attempt, rethrow
        if (attempt >= maxRetries) {
          AppLogger.error('Operation failed after $maxRetries attempts: $e');
          rethrow;
        }
        
        // Calculate delay with exponential backoff
        final delayMs = min(
          baseDelay.inMilliseconds * pow(2, attempt - 1).toInt(),
          maxDelay.inMilliseconds,
        );
        
        final actualDelay = Duration(milliseconds: delayMs);
        
        AppLogger.info('Retrying operation (attempt $attempt/$maxRetries) after ${actualDelay.inSeconds}s delay');
        
        await Future.delayed(actualDelay);
      }
    }
    
    // This should never be reached due to the rethrow above
    throw Exception('Retry logic error');
  }

  /// Retry specifically for network operations
  static Future<T> retryNetworkOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = defaultMaxRetries,
  }) async {
    return retryWithBackoff(
      operation,
      maxRetries: maxRetries,
      shouldRetry: (error) {
        // Retry on network-related errors
        if (error.toString().contains('SocketException')) return true;
        if (error.toString().contains('TimeoutException')) return true;
        if (error.toString().contains('HandshakeException')) return true;
        if (error.toString().contains('unavailable')) return true;
        if (error.toString().contains('deadline-exceeded')) return true;
        if (error.toString().contains('connection-failed')) return true;
        
        // Don't retry on authentication or permission errors
        if (error.toString().contains('permission-denied')) return false;
        if (error.toString().contains('unauthenticated')) return false;
        if (error.toString().contains('invalid-argument')) return false;
        
        return true; // Default to retry
      },
    );
  }

  /// Retry specifically for Firebase operations
  static Future<T> retryFirebaseOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = defaultMaxRetries,
  }) async {
    return retryWithBackoff(
      operation,
      maxRetries: maxRetries,
      shouldRetry: (error) {
        final errorString = error.toString().toLowerCase();
        
        // Retry on transient Firebase errors
        if (errorString.contains('unavailable')) return true;
        if (errorString.contains('deadline-exceeded')) return true;
        if (errorString.contains('internal')) return true;
        if (errorString.contains('aborted')) return true;
        if (errorString.contains('cancelled')) return true;
        
        // Don't retry on permanent errors
        if (errorString.contains('permission-denied')) return false;
        if (errorString.contains('unauthenticated')) return false;
        if (errorString.contains('invalid-argument')) return false;
        if (errorString.contains('not-found')) return false;
        if (errorString.contains('already-exists')) return false;
        if (errorString.contains('failed-precondition')) return false;
        if (errorString.contains('out-of-range')) return false;
        
        return true; // Default to retry for unknown errors
      },
    );
  }

  /// Simple retry with fixed delay
  static Future<T> retryWithFixedDelay<T>(
    Future<T> Function() operation, {
    int maxRetries = defaultMaxRetries,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxRetries) {
          AppLogger.error('Operation failed after $maxRetries attempts: $e');
          rethrow;
        }
        
        AppLogger.info('Retrying operation (attempt $attempt/$maxRetries) after ${delay.inSeconds}s delay');
        await Future.delayed(delay);
      }
    }
    
    throw Exception('Retry logic error');
  }
}

/// Extension to make retry operations more convenient
extension RetryableOperation<T> on Future<T> {
  /// Retry this future with exponential backoff
  Future<T> retryWithBackoff({
    int maxRetries = RetryHelper.defaultMaxRetries,
    Duration baseDelay = const Duration(milliseconds: RetryHelper.baseDelayMs),
    Duration maxDelay = const Duration(milliseconds: RetryHelper.maxDelayMs),
    bool Function(dynamic error)? shouldRetry,
  }) {
    return RetryHelper.retryWithBackoff(
      () => this,
      maxRetries: maxRetries,
      baseDelay: baseDelay,
      maxDelay: maxDelay,
      shouldRetry: shouldRetry,
    );
  }

  /// Retry this future for network operations
  Future<T> retryNetworkOperation({
    int maxRetries = RetryHelper.defaultMaxRetries,
  }) {
    return RetryHelper.retryNetworkOperation(
      () => this,
      maxRetries: maxRetries,
    );
  }

  /// Retry this future for Firebase operations
  Future<T> retryFirebaseOperation({
    int maxRetries = RetryHelper.defaultMaxRetries,
  }) {
    return RetryHelper.retryFirebaseOperation(
      () => this,
      maxRetries: maxRetries,
    );
  }
}