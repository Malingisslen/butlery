/// Comprehensive retry logic utility providing intelligent retry strategies with exponential backoff and error-specific handling.
/// This utility class implements sophisticated retry mechanisms for handling transient failures in network operations,
/// Firebase interactions, and general async operations. It provides exponential backoff algorithms, error-specific
/// retry logic, configurable retry policies, and comprehensive logging for optimal resilience and debugging
/// capabilities throughout the application's async operation lifecycle.
/// **Architecture Integration:**
/// - Uses [AppLogger] for detailed retry attempt logging and failure tracking
/// - Integrates with [dart:math] for exponential backoff calculations and delay optimization
/// - Provides specialized retry strategies for different service types (Network, Firebase, General)
/// - Supports configurable retry policies with intelligent error classification
/// - Implements generic type support for type-safe retry operations across different return types
/// **Retry Strategy Features:**
/// - **Exponential Backoff**: Progressive delay increase with configurable base delay and maximum cap
/// - **Error Classification**: Intelligent error analysis determining retry eligibility based on error type
/// - **Specialized Strategies**: Domain-specific retry logic for network and Firebase operations
/// - **Fixed Delay Option**: Simple retry with consistent delay intervals for specific use cases
/// - **Configurable Limits**: Customizable maximum retry attempts and delay parameters
/// - **Extension Support**: Convenient Future extension methods for seamless retry integration
/// **Retry Categories:**
/// - **Network Operations**: Specialized handling for network timeouts, connection failures, and transient issues
/// - **Firebase Operations**: Firebase-specific error handling with appropriate retry logic for database operations
/// - **General Operations**: Flexible retry logic for any async operation with custom error handling
/// - **Fixed Delay**: Simple retry mechanism with consistent delay intervals for predictable retry patterns
/// **Usage Examples:**
/// ```dart
/// // Network operation with automatic retry
/// final result = await RetryHelper.retryNetworkOperation(() async {
///   return await apiService.fetchUserData();
/// });
/// // Firebase operation with intelligent retry
/// final data = await RetryHelper.retryFirebaseOperation(() async {
///   return await firebaseService.saveRecipe(recipe);
/// });
/// // Custom retry with specific conditions
/// final response = await RetryHelper.retryWithBackoff(
///   () => performComplexOperation(),
///   maxRetries: 5,
///   shouldRetry: (error) => error is! ValidationException,
/// );
/// // Using extension methods for convenience
/// final data = await apiCall().retryNetworkOperation(maxRetries: 3);
/// ```

import 'dart:math';
import 'package:butlery/core/utils/logger.dart';

/// Comprehensive retry logic utility providing intelligent retry strategies with exponential backoff and error-specific handling.
/// This utility class implements sophisticated retry mechanisms for handling transient failures across different
/// operation types. It provides configurable retry policies, intelligent error classification, and specialized
/// strategies for network and Firebase operations with comprehensive logging and monitoring capabilities.
/// **Static Utility Design:**
/// All methods are static for convenient access throughout the application without instantiation requirements.
/// This design ensures consistent retry behavior and optimal performance while providing comprehensive
/// retry strategies for different service types and error conditions.
class RetryHelper {
  /// Default maximum number of retry attempts for standard retry operations.
  /// This constant defines the standard retry limit used across retry operations when no custom
  /// limit is specified. It provides a balance between resilience and performance, allowing
  /// sufficient retry attempts for transient failures without excessive delay.
  static const int defaultMaxRetries = 3;

  /// Base delay duration for exponential backoff calculations in milliseconds.
  /// This constant defines the initial delay used in exponential backoff algorithms before
  /// applying exponential multiplication. It provides the foundation for progressive delay
  /// increase with each retry attempt, starting from a reasonable base duration.
  static const int baseDelayMs = 1000;

  /// Maximum delay cap for exponential backoff to prevent excessively long delays.
  /// This constant defines the upper limit for retry delays, preventing exponential backoff
  /// from creating impractically long delays. It ensures reasonable maximum wait times
  /// while maintaining progressive backoff benefits for resilience.
  static const int maxDelayMs = 30000;

  /// ±fraction of jitter applied to each backoff delay.
  /// Standardized on the same ±25% symmetric jitter as `lib/utils/retry_policy.dart`
  /// so synchronized clients don't retry in lockstep and stampede a recovering backend.
  static const double _jitterFraction = 0.25;

  /// Random source for jitter. A single shared instance is sufficient — jitter
  /// only spreads delay timing, it never influences which errors are retryable.
  static final Random _random = Random();

  /// Executes async operations with intelligent exponential backoff retry strategy and configurable error handling.
  /// This method implements sophisticated retry logic with exponential backoff algorithm, providing progressive
  /// delay increase with each retry attempt. It includes intelligent error classification, configurable retry
  /// limits, comprehensive logging, and optional custom retry condition evaluation for optimal resilience.
  /// [operation] Async operation to execute with retry logic, must return Future\<T\>
  /// [maxRetries] Maximum number of retry attempts before final failure (defaults to 3)
  /// [baseDelay] Initial delay duration for exponential backoff calculation (defaults to 1 second)
  /// [maxDelay] Maximum delay cap to prevent excessive wait times (defaults to 30 seconds)
  /// [shouldRetry] Optional custom function to determine retry eligibility based on error type
  /// Returns Future\<T\> with the operation result after successful execution or retry exhaustion
  /// Throws the final exception if all retry attempts fail
  /// **Exponential Backoff Algorithm:**
  /// - **Formula**: delay = min(baseDelay * 2^(attempt-1), maxDelay)
  /// - **Progressive Increase**: Each retry doubles the previous delay up to maximum cap
  /// - **Delay Sequence**: 1s, 2s, 4s, 8s, 16s, 30s (capped), 30s...
  /// - **Jitter Prevention**: Deterministic delays for predictable retry patterns
  /// **Error Classification Features:**
  /// - **Custom Retry Logic**: Optional shouldRetry function for domain-specific error handling
  /// - **Automatic Rethrow**: Non-retryable errors are immediately rethrown without delay
  /// - **Comprehensive Logging**: Detailed logging for each retry attempt and final failure
  /// - **Generic Type Support**: Works with any return type T for type-safe operations
  /// **Usage Examples:**
  /// ```dart
  /// // Basic exponential backoff retry
  /// final result = await RetryHelper.retryWithBackoff(() async {
  ///   return await performNetworkOperation();
  /// });
  /// // Custom retry with validation error exclusion
  /// final data = await RetryHelper.retryWithBackoff(
  ///   () => processUserData(),
  ///   maxRetries: 5,
  ///   shouldRetry: (error) => error is! ValidationException,
  /// );
  /// ```
  /// **Performance:** O(1) per attempt with exponential delay progression
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

        // Calculate delay with jittered exponential backoff
        final cappedMs = min(
          baseDelay.inMilliseconds * pow(2, attempt - 1).toInt(),
          maxDelay.inMilliseconds,
        );

        // ±25% symmetric jitter — matches lib/utils/retry_policy.dart.
        final jitterRange = (cappedMs * _jitterFraction).round();
        final jitterOffset = jitterRange == 0
            ? 0
            : ((_random.nextDouble() * 2 - 1) * jitterRange).round();

        final actualDelay = Duration(
          milliseconds: max(0, cappedMs + jitterOffset),
        );

        AppLogger.info(
          'Retrying operation (attempt $attempt/$maxRetries) after ${actualDelay.inSeconds}s delay',
        );

        await Future.delayed(actualDelay);
      }
    }

    // This should never be reached due to the rethrow above
    throw Exception('Retry logic error');
  }

  /// Executes network operations with specialized retry logic for network-specific error handling.
  /// This method provides specialized retry logic optimized for network operations, implementing intelligent
  /// error classification for network-related failures while excluding non-retryable errors such as
  /// authentication and permission issues. It uses exponential backoff with network-optimized retry conditions.
  /// [operation] Network async operation to execute with specialized retry logic
  /// [maxRetries] Maximum number of retry attempts for network operation (defaults to 3)
  /// Returns Future\<T\> with operation result after successful network operation or retry exhaustion
  /// Throws the final exception if network operation fails after all retry attempts
  /// **Network Error Classification:**
  /// - **Retryable Errors**: SocketException, TimeoutException, HandshakeException, network unavailable
  /// - **Connection Issues**: connection-failed, deadline-exceeded, service unavailable errors
  /// - **Non-Retryable Errors**: permission-denied, unauthenticated, invalid-argument (immediate rethrow)
  /// - **Default Behavior**: Unknown errors rethrow immediately (not proven transient)
  /// **Network-Specific Features:**
  /// - **Intelligent Classification**: Automatic detection of network vs authentication errors
  /// - **Exponential Backoff**: Standard exponential backoff algorithm for network resilience
  /// - **Comprehensive Logging**: Detailed network retry attempt logging for debugging
  /// - **Type Safety**: Generic type support for different network operation return types
  /// **Usage Examples:**
  /// ```dart
  /// // API call with network retry
  /// final userData = await RetryHelper.retryNetworkOperation(() async {
  ///   return await apiService.fetchUserProfile();
  /// });
  /// // File download with network resilience
  /// final file = await RetryHelper.retryNetworkOperation(
  ///   () => downloadService.downloadFile(url),
  ///   maxRetries: 5,
  /// );
  /// ```
  /// **Performance:** Network-optimized retry with intelligent error classification
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

        // Rethrow-on-unknown (matches lib/utils/retry_policy.dart): an
        // unclassified error is not proven transient, so retrying just burns
        // the user's quota and time. Add a case above to opt an error in.
        return false;
      },
    );
  }

  /// Executes Firebase operations with specialized retry logic for Firebase-specific error handling.
  /// This method provides specialized retry logic optimized for Firebase database operations, implementing
  /// intelligent error classification for Firebase-related failures while excluding permanent errors that
  /// should not be retried. It uses exponential backoff with Firebase-optimized retry conditions.
  /// [operation] Firebase async operation to execute with specialized retry logic
  /// [maxRetries] Maximum number of retry attempts for Firebase operation (defaults to 3)
  /// Returns Future\<T\> with operation result after successful Firebase operation or retry exhaustion
  /// Throws the final exception if Firebase operation fails after all retry attempts
  /// **Firebase Error Classification:**
  /// - **Retryable Errors**: unavailable, deadline-exceeded, internal, aborted, cancelled (transient issues)
  /// - **Non-Retryable Errors**: permission-denied, unauthenticated, invalid-argument, not-found, already-exists
  /// - **Permanent Failures**: failed-precondition, out-of-range (immediate rethrow without retry)
  /// - **Default Behavior**: Unknown Firebase errors rethrow immediately (not proven transient)
  /// **Firebase-Specific Features:**
  /// - **Intelligent Classification**: Automatic detection of transient vs permanent Firebase errors
  /// - **Database Optimization**: Specialized handling for Firestore and Realtime Database operations
  /// - **Exponential Backoff**: Standard exponential backoff algorithm for Firebase resilience
  /// - **Comprehensive Logging**: Detailed Firebase retry attempt logging for debugging
  /// **Usage Examples:**
  /// ```dart
  /// // Recipe save with Firebase retry
  /// final recipe = await RetryHelper.retryFirebaseOperation(() async {
  ///   return await firebaseService.saveRecipe(newRecipe);
  /// });
  /// // User data fetch with Firebase resilience
  /// final profile = await RetryHelper.retryFirebaseOperation(
  ///   () => firebaseService.getUserProfile(userId),
  ///   maxRetries: 4,
  /// );
  /// ```
  /// **Performance:** Firebase-optimized retry with intelligent error classification
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
        // resource-exhausted is a quota/rate-limit signal whose defined
        // response IS back-off-and-retry; and a raw network/socket drop (the
        // offline-sync case) is transient by nature — the sibling
        // retryNetworkOperation already treats these as retryable. Classify
        // them here so the rethrow-on-unknown default below doesn't silently
        // strip in-pass retry from offline sync (its only production caller).
        if (errorString.contains('resource-exhausted')) return true;
        if (errorString.contains('socketexception')) return true;
        if (errorString.contains('network-request-failed')) return true;
        if (errorString.contains('network error')) return true;

        // Don't retry on permanent errors
        if (errorString.contains('permission-denied')) return false;
        if (errorString.contains('unauthenticated')) return false;
        if (errorString.contains('invalid-argument')) return false;
        if (errorString.contains('not-found')) return false;
        if (errorString.contains('already-exists')) return false;
        if (errorString.contains('failed-precondition')) return false;
        if (errorString.contains('out-of-range')) return false;

        // Rethrow-on-unknown (matches lib/utils/retry_policy.dart): an
        // unclassified error is not proven transient, so retrying just burns
        // the user's quota and time. Add a case above to opt an error in.
        return false;
      },
    );
  }

  /// Executes async operations with simple fixed delay retry strategy for predictable retry patterns.
  /// This method provides simple retry logic with consistent delay intervals between attempts, offering
  /// predictable retry timing without exponential increase. It's useful for operations requiring consistent
  /// retry intervals or when exponential backoff is not desired for specific use cases.
  /// [operation] Async operation to execute with fixed delay retry logic
  /// [maxRetries] Maximum number of retry attempts before final failure (defaults to 3)
  /// [delay] Fixed delay duration between retry attempts (defaults to 1 second)
  /// Returns Future\<T\> with operation result after successful execution or retry exhaustion
  /// Throws the final exception if operation fails after all retry attempts
  /// **Fixed Delay Features:**
  /// - **Consistent Timing**: Fixed delay between all retry attempts for predictable patterns
  /// - **Simple Logic**: Straightforward retry without complex backoff calculations
  /// - **Configurable Delay**: Customizable delay duration for different operation requirements
  /// - **Comprehensive Logging**: Detailed logging for each retry attempt and final failure
  /// **Usage Examples:**
  /// ```dart
  /// // Simple retry with 2-second intervals
  /// final result = await RetryHelper.retryWithFixedDelay(
  ///   () => performDatabaseOperation(),
  ///   delay: Duration(seconds: 2),
  /// );
  /// // Quick retry with minimal delay
  /// final data = await RetryHelper.retryWithFixedDelay(
  ///   () => fetchCachedData(),
  ///   maxRetries: 2,
  ///   delay: Duration(milliseconds: 500),
  /// );
  /// ```
  /// **Performance:** O(1) per attempt with consistent fixed delay timing
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

        AppLogger.info(
          'Retrying operation (attempt $attempt/$maxRetries) after ${delay.inSeconds}s delay',
        );
        await Future.delayed(delay);
      }
    }

    throw Exception('Retry logic error');
  }
}

/// Convenient extension methods for Future operations enabling seamless retry integration with fluent API patterns.
/// This extension provides convenient method chaining for retry operations, enabling fluent API patterns
/// for adding retry logic to existing Future operations. It wraps the static RetryHelper methods with
/// instance methods for more natural and readable retry operation integration throughout the application.
/// **Extension Benefits:**
/// - **Fluent API**: Method chaining for natural retry operation integration
/// - **Seamless Integration**: Easy addition of retry logic to existing Future operations
/// - **Type Safety**: Generic type preservation throughout retry operation chain
/// - **Convenience Methods**: Simplified access to specialized retry strategies
extension RetryableOperation<T> on Future<T> {
  /// Applies exponential backoff retry strategy to this Future operation with configurable parameters.
  /// This method enables fluent API retry integration by applying exponential backoff retry logic
  /// to the current Future operation. It provides the same functionality as RetryHelper.retryWithBackoff
  /// but with convenient method chaining syntax for more natural integration.
  /// [maxRetries] Maximum number of retry attempts before final failure (defaults to 3)
  /// [baseDelay] Initial delay duration for exponential backoff calculation (defaults to 1 second)
  /// [maxDelay] Maximum delay cap to prevent excessive wait times (defaults to 30 seconds)
  /// [shouldRetry] Optional custom function to determine retry eligibility based on error type
  /// Returns Future\<T\> with retry logic applied to this operation
  /// **Usage Examples:**
  /// ```dart
  /// // Method chaining with exponential backoff
  /// final result = await apiCall().retryWithBackoff(maxRetries: 5);
  /// // Custom retry condition with method chaining
  /// final data = await operation().retryWithBackoff(
  ///   shouldRetry: (error) => error is! ValidationException,
  /// );
  /// ```
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
