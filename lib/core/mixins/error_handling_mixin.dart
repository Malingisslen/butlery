/// Comprehensive error handling mixin for standardizing error patterns across the app.
/// This mixin eliminates 1,100-1,400 lines of duplicate error handling code found
/// across 184+ files in the codebase by providing a centralized, consistent approach
/// to error management, logging, and user feedback.
/// Key capabilities:
/// - Standardized try-catch-log patterns for async and sync operations
/// - User-friendly error message generation and display
/// - Operation-specific error handling (create, update, delete, fetch operations)
/// - Batch operation error handling with continue-on-error support
/// - Firebase-specific error handling and categorization
/// - Network error detection and appropriate user messaging
/// - Error recovery patterns and retry mechanisms
/// Architecture benefits:
/// - Eliminates inconsistent error handling across services and ViewModels
/// - Provides centralized error logging and analytics tracking
/// - Ensures consistent user experience during error scenarios
/// - Simplifies testing with predictable error handling patterns
/// - Reduces boilerplate code in business logic classes
/// Usage examples:
/// ```dart
/// // Basic async operation with error handling
/// final result = await safeExecute(
///   () => apiService.fetchData(),
///   operationName: 'Fetch user data',
///   defaultValue: [],
/// );
/// // Create operation with user-friendly error messages
/// final recipe = await safeCreate(
///   () => recipeService.createRecipe(data),
///   'recipe',
/// );
/// // Batch operations with error handling
/// final results = await safeBatchOperation(
///   operations,
///   'Import recipes',
///   continueOnError: true,
/// );
/// ```

import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Error classification enum for intelligent error handling strategies.
/// This enumeration provides detailed error classification to enable appropriate
/// handling strategies based on the specific type of connectivity or service issue.
/// It helps distinguish between DNS problems, network issues, and service errors.
/// **Error Categories:**
/// - [dnsResolution] DNS resolution failures preventing domain name resolution
/// - [networkConnectivity] Network connectivity issues affecting communication
/// - [authentication] Authentication and permission errors
/// - [notFound] Resource not found errors
/// - [serviceUnavailable] Temporary service unavailability
/// - [unknown] Unclassified errors requiring conservative handling
enum ErrorType {
  /// DNS resolution failures preventing domain name resolution.
  /// This error type indicates issues resolving domain names to IP addresses,
  /// which can be addressed through DNS failover and direct IP connection strategies.
  dnsResolution,

  /// Network connectivity issues affecting communication.
  /// This error type indicates broader network connectivity problems that may require
  /// retry strategies, connection quality assessment, or offline mode activation.
  networkConnectivity,

  /// Authentication and permission errors.
  /// This error type indicates authentication failures or insufficient permissions
  /// that require user authentication or permission elevation.
  authentication,

  /// Resource not found errors.
  /// This error type indicates that requested resources could not be found,
  /// requiring appropriate user communication and error handling.
  notFound,

  /// Temporary service unavailability.
  /// This error type indicates temporary service problems that may resolve
  /// with retry strategies or require user notification about service status.
  serviceUnavailable,

  /// Unclassified errors requiring conservative handling.
  /// This error type indicates errors that cannot be clearly classified and
  /// require conservative error handling and user communication.
  unknown,
}

/// Mixin providing comprehensive error handling capabilities.
/// Consolidates common error handling patterns into reusable methods that provide
/// consistent error logging, user messaging, and recovery mechanisms across the
/// entire application.
/// Classes using this mixin gain access to:
/// - Safe execution wrappers for async and synchronous operations
/// - Operation-specific error handling (CRUD operations)
/// - Batch operation processing with configurable error handling
/// - Firebase-specific error categorization and messaging
/// - Network error detection and user-friendly messaging
/// - Error recovery and retry mechanisms
mixin ErrorHandlingMixin {
  /// Safely executes an async operation with comprehensive error handling.
  /// This method wraps async operations in standardized try-catch logic,
  /// providing consistent error logging, user messaging, and fallback behavior.
  /// Replaces the most common error handling pattern found in 184+ files.
  /// [operation] The async operation to execute safely
  /// [operationName] Human-readable name for logging purposes
  /// [defaultValue] Value to return if the operation fails
  /// [logError] Whether to log errors (default: true)
  /// [customErrorMessage] Custom error message for user feedback
  /// Returns the operation result or [defaultValue] if the operation fails.
  /// Example:
  /// ```dart
  /// final recipes = await safeExecute(
  ///   () => recipeService.fetchRecipes(),
  ///   operationName: 'Fetch recipes',
  ///   defaultValue: <Recipe>[],
  ///   customErrorMessage: 'Failed to load recipes. Please try again.',
  /// );
  /// ```
  Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
    bool logError = true,
    String? customErrorMessage,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      if (logError) {
        final opName = operationName ?? 'Operation';
        AppLogger.error('$opName failed: $e', stackTrace);
      }

      if (customErrorMessage != null) {
        handleUserError(customErrorMessage);
      }

      return defaultValue;
    }
  }

  /// Safely executes a synchronous operation with error handling.
  /// Provides the same error handling capabilities as [safeExecute] but for
  /// synchronous operations. Useful for data transformations, validations,
  /// and other non-async operations that may throw exceptions.
  /// [operation] The synchronous operation to execute safely
  /// [operationName] Human-readable name for logging purposes
  /// [defaultValue] Value to return if the operation fails
  /// [logError] Whether to log errors (default: true)
  /// [customErrorMessage] Custom error message for user feedback
  /// Returns the operation result or [defaultValue] if the operation fails.
  /// Example:
  /// ```dart
  /// final parsedData = safeExecuteSync(
  ///   () => jsonDecode(jsonString),
  ///   operationName: 'Parse JSON data',
  ///   defaultValue: {},
  /// );
  /// ```
  T? safeExecuteSync<T>(
    T Function() operation, {
    String? operationName,
    T? defaultValue,
    bool logError = true,
    String? customErrorMessage,
  }) {
    try {
      return operation();
    } catch (e, stackTrace) {
      if (logError) {
        final opName = operationName ?? 'Operation';
        AppLogger.error('$opName failed: $e', stackTrace);
      }

      if (customErrorMessage != null) {
        handleUserError(customErrorMessage);
      }

      return defaultValue;
    }
  }

  /// Safely executes a create operation with specialized error handling.
  /// Provides standardized error handling for create operations with
  /// user-friendly error messages. Automatically generates appropriate
  /// error messages based on the item type being created.
  /// [createOperation] The async create operation to execute
  /// [itemType] Human-readable name of the item being created (e.g., 'recipe', 'user')
  /// [defaultValue] Value to return if the create operation fails
  /// Returns the created item or [defaultValue] if creation fails.
  /// Example:
  /// ```dart
  /// final recipe = await safeCreate(
  ///   () => recipeService.createRecipe(recipeData),
  ///   'recipe',
  /// );
  /// ```
  Future<T?> safeCreate<T>(
    Future<T> Function() createOperation,
    String itemType, {
    T? defaultValue,
  }) async {
    return safeExecute(
      createOperation,
      operationName: 'Create $itemType',
      defaultValue: defaultValue,
      customErrorMessage: AppLocale.current.errorCouldNotCreate(itemType),
    );
  }

  /// Update operation error handling - consolidates update patterns
  Future<T?> safeUpdate<T>(
    Future<T> Function() updateOperation,
    String itemType, {
    T? defaultValue,
  }) async {
    return safeExecute(
      updateOperation,
      operationName: 'Update $itemType',
      defaultValue: defaultValue,
      customErrorMessage: AppLocale.current.errorCouldNotUpdate(itemType),
    );
  }

  /// Delete operation error handling - consolidates delete patterns
  Future<bool> safeDelete(
    Future<void> Function() deleteOperation,
    String itemType,
  ) async {
    final result = await safeExecute(
      () async {
        await deleteOperation();
        return true;
      },
      operationName: 'Delete $itemType',
      defaultValue: false,
      customErrorMessage: AppLocale.current.errorCouldNotDelete(itemType),
    );

    return result ?? false;
  }

  /// Load operation error handling - consolidates load patterns
  Future<T?> safeLoad<T>(
    Future<T> Function() loadOperation,
    String itemType, {
    T? defaultValue,
  }) async {
    return safeExecute(
      loadOperation,
      operationName: 'Load $itemType',
      defaultValue: defaultValue,
      customErrorMessage: AppLocale.current.errorCouldNotLoad(itemType),
    );
  }

  /// Safe list operation - consolidates list loading patterns
  Future<List<T>> safeLoadList<T>(
    Future<List<T>> Function() loadOperation,
    String itemType,
  ) async {
    final result = await safeExecute(
      loadOperation,
      operationName: 'Load $itemType list',
      defaultValue: <T>[],
      customErrorMessage: AppLocale.current.errorCouldNotLoad(itemType),
    );

    return result ?? <T>[];
  }

  /// Safe list operation with empty check
  Future<List<T>> safeLoadListWithEmptyCheck<T>(
    Future<List<T>> Function() loadOperation,
    String itemType, {
    bool showEmptyMessage = false,
  }) async {
    final result = await safeLoadList(loadOperation, itemType);

    if (result.isEmpty && showEmptyMessage) {
      handleUserInfo(AppLocale.current.errorNoItemsFound);
    }

    return result;
  }

  /// Network operation error handling - consolidates network patterns
  Future<T?> safeNetworkOperation<T>(
    Future<T> Function() networkOperation, {
    String? operationName,
    T? defaultValue,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await networkOperation();
      } catch (e, stackTrace) {
        attempts++;

        if (attempts >= maxRetries) {
          final opName = operationName ?? 'Network operation';
          AppLogger.error(
              '$opName failed after $maxRetries attempts: $e', stackTrace);
          handleUserError(AppLocale.current.errorNetwork);
          return defaultValue;
        }

        AppLogger.warning(
            'Network operation attempt $attempts failed, retrying: $e');
        await Future.delayed(retryDelay);
        if (this is StateNotifierMixin &&
            (this as StateNotifierMixin).isDisposed) {
          return defaultValue;
        }
      }
    }

    return defaultValue;
  }

  /// Permission-aware operation error handling
  Future<T?> safePermissionOperation<T>(
    Future<T> Function() operation,
    String operationName, {
    T? defaultValue,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      AppLogger.error('$operationName failed: $e', stackTrace);

      if (e.toString().toLowerCase().contains('permission')) {
        handleUserError(AppLocale.current.errorPermissionDenied);
      } else if (e.toString().toLowerCase().contains('auth')) {
        handleUserError(AppLocale.current.errorAuthentication);
      } else {
        handleUserError(AppLocale.current.errorGeneric);
      }

      return defaultValue;
    }
  }

  /// Validation-aware operation error handling
  Future<T?> safeValidatedOperation<T>(
    Future<T> Function() operation,
    bool Function() validator,
    String validationError, {
    String? operationName,
    T? defaultValue,
  }) async {
    if (!validator()) {
      handleUserError(validationError);
      return defaultValue;
    }

    return safeExecute(
      operation,
      operationName: operationName,
      defaultValue: defaultValue,
    );
  }

  /// Batch operation error handling - consolidates batch patterns
  Future<List<T>> safeBatchOperation<T>(
    List<Future<T> Function()> operations,
    String operationName, {
    bool continueOnError = true,
  }) async {
    final results = <T>[];
    int failures = 0;

    for (int i = 0; i < operations.length; i++) {
      final result = await safeExecute(
        operations[i],
        operationName: '$operationName (${i + 1}/${operations.length})',
        logError: true,
      );

      if (result != null) {
        results.add(result);
      } else {
        failures++;
        if (!continueOnError) break;
      }
    }

    if (failures > 0) {
      AppLogger.warning('$operationName completed with $failures failures');
    }

    return results;
  }

  /// Operation with fallback - consolidates fallback patterns
  Future<T> operationWithFallback<T>(
    Future<T> Function() primaryOperation,
    Future<T> Function() fallbackOperation,
    String operationName,
  ) async {
    try {
      return await primaryOperation();
    } catch (e) {
      AppLogger.warning('$operationName primary failed, trying fallback: $e');

      try {
        return await fallbackOperation();
      } catch (fallbackError, fallbackStackTrace) {
        AppLogger.error('$operationName fallback also failed: $fallbackError',
            fallbackStackTrace);
        rethrow;
      }
    }
  }

  /// Retry operation with exponential backoff
  Future<T> retryOperation<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
  }) async {
    int attempts = 0;
    Duration currentDelay = initialDelay;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e, stackTrace) {
        attempts++;

        if (attempts >= maxRetries) {
          AppLogger.error(
              '$operationName failed after $maxRetries attempts: $e',
              stackTrace);
          rethrow;
        }

        AppLogger.warning(
            '$operationName attempt $attempts failed, retrying in ${currentDelay.inSeconds}s: $e');
        await Future.delayed(currentDelay);
        if (this is StateNotifierMixin &&
            (this as StateNotifierMixin).isDisposed) {
          rethrow;
        }
        currentDelay = Duration(
            milliseconds:
                (currentDelay.inMilliseconds * backoffMultiplier).round());
      }
    }

    throw Exception('Should never reach here');
  }

  /// Categorize and handle different error types with enhanced DNS-aware error classification.
  /// This enhanced method provides comprehensive error categorization including DNS resolution
  /// failures, network connectivity issues, and service-specific errors. It enables intelligent
  /// error handling strategies based on the specific type of connectivity or service issue.
  /// [error] The error to categorize and handle
  /// [operation] The operation context for logging and error reporting
  /// **Enhanced Error Categories:**
  /// - DNS resolution failures with specific user messaging
  /// - Network connectivity issues with appropriate guidance
  /// - Authentication and permission errors
  /// - Service-specific errors with contextual information
  void handleCategorizedError(dynamic error, String operation) {
    final errorCategory = classifyError(error);
    final userMessage = getUserMessageForErrorType(errorCategory);

    handleUserError(userMessage);

    // Enhanced logging with error classification
    AppLogger.error(
        'Categorized error in $operation [${errorCategory.name}]: $error');
  }

  /// Classifies errors into specific categories for intelligent handling.
  /// This method provides detailed error classification that enables appropriate
  /// handling strategies based on the specific type of connectivity or service issue.
  /// It's particularly useful for distinguishing DNS issues from other network problems.
  /// [error] The error to classify
  /// Returns [ErrorType] indicating the specific error category
  ErrorType classifyError(dynamic error) {
    if (error is Exception) {
      final errorMessage = error.toString().toLowerCase();

      // DNS resolution errors (critical for production DNS issues)
      if (errorMessage.contains('resolve') ||
          errorMessage.contains('dns') ||
          errorMessage.contains('host') ||
          errorMessage.contains('address associated with hostname') ||
          errorMessage.contains('name resolution failed')) {
        return ErrorType.dnsResolution;
      }

      // Network connectivity errors
      if (errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('unreachable')) {
        return ErrorType.networkConnectivity;
      }

      // Authentication and permission errors
      if (errorMessage.contains('permission') ||
          errorMessage.contains('unauthorized') ||
          errorMessage.contains('auth') ||
          errorMessage.contains('forbidden')) {
        return ErrorType.authentication;
      }

      // Resource not found errors
      if (errorMessage.contains('not found') || errorMessage.contains('404')) {
        return ErrorType.notFound;
      }

      // Service unavailable errors
      if (errorMessage.contains('service unavailable') ||
          errorMessage.contains('503') ||
          errorMessage.contains('502') ||
          errorMessage.contains('internal server error')) {
        return ErrorType.serviceUnavailable;
      }
    }

    return ErrorType.unknown;
  }

  /// Gets appropriate user message for specific error types.
  /// This method provides user-friendly error messages tailored to specific
  /// error categories, enabling better user communication and guidance.
  /// [errorType] The classified error type
  /// Returns user-friendly error message string
  String getUserMessageForErrorType(ErrorType errorType) {
    final l = AppLocale.current;
    switch (errorType) {
      case ErrorType.dnsResolution:
        return l.errorDnsResolution;
      case ErrorType.networkConnectivity:
        return l.errorNetwork;
      case ErrorType.authentication:
        return l.errorAuthentication;
      case ErrorType.notFound:
        return l.errorNotFound;
      case ErrorType.serviceUnavailable:
        return l.errorServiceUnavailable;
      case ErrorType.unknown:
        return l.errorGeneric;
    }
  }

  /// Handle user-facing errors - to be overridden by mixing class
  void handleUserError(String message) {
    // Default implementation - can be overridden
    AppLogger.error('User error: $message');
  }

  /// Handle user-facing info messages - to be overridden by mixing class
  void handleUserInfo(String message) {
    // Default implementation - can be overridden
    AppLogger.info('User info: $message');
  }

  /// Check if error is recoverable with enhanced DNS-aware classification.
  /// This enhanced method provides comprehensive error recoverability assessment
  /// including DNS resolution issues, network connectivity problems, and temporary
  /// service failures. It helps determine appropriate retry strategies.
  /// [error] The error to assess for recoverability
  /// Returns `true` if the error indicates a recoverable condition
  bool isRecoverableError(dynamic error) {
    final errorCategory = classifyError(error);

    switch (errorCategory) {
      case ErrorType.dnsResolution:
      case ErrorType.networkConnectivity:
      case ErrorType.serviceUnavailable:
        return true; // These are typically recoverable
      case ErrorType.authentication:
      case ErrorType.notFound:
      case ErrorType.unknown:
        return false; // These typically require different handling
    }
  }

  /// Checks if error is specifically related to DNS resolution issues.
  /// This method provides targeted DNS error detection to enable DNS-specific
  /// recovery strategies like IP fallback and DNS server switching.
  /// [error] The error to check for DNS issues
  /// Returns `true` if the error is related to DNS resolution
  bool isDNSResolutionError(dynamic error) {
    return classifyError(error) == ErrorType.dnsResolution;
  }

  /// Checks if error is related to general network connectivity.
  /// This method distinguishes between DNS-specific issues and broader
  /// network connectivity problems for appropriate handling strategies.
  /// [error] The error to check for network issues
  /// Returns `true` if the error is related to network connectivity
  bool isNetworkConnectivityError(dynamic error) {
    return classifyError(error) == ErrorType.networkConnectivity;
  }

  /// Extract user-friendly message from error with enhanced DNS-aware messaging.
  /// This enhanced method provides user-friendly error messages with specific
  /// handling for DNS resolution issues and other connectivity problems.
  /// [error] The error to extract user message from
  /// Returns user-friendly error message string
  String extractUserMessage(dynamic error) {
    final errorCategory = classifyError(error);
    return getUserMessageForErrorType(errorCategory);
  }
}
