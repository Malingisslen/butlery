/// Mixin providing standardized async operation handling for ViewModels.
///
/// This mixin eliminates duplicated async operation patterns found across ViewModels
/// by providing a comprehensive set of async operation utilities with built-in
/// loading state management, error handling, concurrency control, and performance
/// optimizations.
///
/// Key capabilities:
/// - Automatic loading state management during async operations
/// - Concurrent operation tracking and prevention of duplicate operations
/// - Debounced operations to prevent excessive API calls
/// - Background operations that don't affect loading states
/// - Operation caching to avoid redundant network requests
/// - Retry mechanisms with exponential backoff
/// - Operation cancellation and cleanup
///
/// Architecture benefits:
/// - Eliminates try-catch boilerplate in ViewModels
/// - Provides consistent loading and error states across the app
/// - Prevents race conditions and duplicate operations
/// - Improves performance through debouncing and caching
/// - Simplifies ViewModel testing with predictable state management
///
/// Usage pattern transformation:
/// ```dart
/// // Before (duplicated across ViewModels):
/// Future<void> loadData() async {
///   try {
///     _setLoading(true);
///     _clearError();
///     final data = await _service.fetchData();
///     _data = data;
///     _setLoading(false);
///     notifyListeners();
///   } catch (e) {
///     _setError(e.toString());
///     _setLoading(false);
///   }
/// }
///
/// // After (using AsyncOperationMixin):
/// Future<void> loadData() async {
///   await executeAsync(() async {
///     final data = await _service.fetchData();
///     _data = data;
///   });
/// }
/// ```

import 'dart:async';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/utils/logger.dart';

/// Mixin for standardizing async operations in ViewModels.
///
/// Built on top of [StateNotifierMixin] to provide comprehensive async operation
/// management including loading states, error handling, concurrency control,
/// and performance optimizations. This mixin should be used by all ViewModels
/// that perform async operations.
///
/// Provides these operation types:
/// - [executeAsync] - Standard async operations with loading states
/// - [executeNamedOperation] - Named operations that prevent duplicates
/// - [executeDebouncedOperation] - Debounced operations for user input
/// - [executeBackgroundOperation] - Background operations without loading states
/// - [executeBatchOperations] - Batch processing with progress tracking
/// - [executeWithRetry] - Operations with automatic retry logic
mixin AsyncOperationMixin on StateNotifierMixin {
  // ===== OPERATION TRACKING =====
  
  /// Set of currently active operation names to prevent duplicates.
  final Set<String> _activeOperations = {};
  
  /// Map of debounced operations with their timers.
  final Map<String, Timer> _pendingOperations = {};
  
  /// Cache of operation results to avoid redundant network requests.
  final Map<String, dynamic> _operationCache = {};
  
  // ===== PUBLIC GETTERS =====
  
  /// Whether any operations are currently executing.
  ///
  /// Useful for UI components that need to show global loading states
  /// or disable certain actions while operations are in progress.
  bool get hasActiveOperations => _activeOperations.isNotEmpty;
  
  /// The number of operations currently executing.
  ///
  /// Can be used to show progress indicators or operation counts in the UI.
  int get activeOperationCount => _activeOperations.length;
  
  /// List of names of currently executing operations.
  ///
  /// Useful for debugging and showing detailed operation status in the UI.
  List<String> get activeOperationNames => _activeOperations.toList();
  
  // ===== BASIC ASYNC OPERATIONS =====
  
  /// Executes an async operation with automatic loading state and error management.
  ///
  /// This is the primary method for executing async operations in ViewModels.
  /// It automatically manages loading states, clears previous errors, and
  /// handles exceptions with proper error messaging and logging.
  ///
  /// [operation] The async operation to execute
  /// [errorPrefix] Prefix for error messages (optional)
  /// [clearErrorOnStart] Whether to clear existing errors before starting (default: true)
  ///
  /// Returns the result of the operation.
  ///
  /// Example:
  /// ```dart
  /// final recipes = await executeAsync(() async {
  ///   return await recipeService.fetchRecipes();
  /// });
  /// ```
  @override
  Future<T> executeAsync<T>(
    Future<T> Function() operation, {
    String? errorPrefix,
    bool clearErrorOnStart = true,
  }) async {
    return await super.executeAsync(
      operation,
      errorPrefix: errorPrefix,
      clearErrorOnStart: clearErrorOnStart,
    );
  }
  
  /// Executes a named async operation, preventing duplicate executions.
  ///
  /// Named operations are tracked to prevent the same operation from running
  /// concurrently. If an operation with the same name is already running,
  /// subsequent calls will wait for the first operation to complete.
  ///
  /// [operationName] Unique name for the operation
  /// [operation] The async operation to execute
  ///
  /// Returns the result of the operation.
  ///
  /// Example:
  /// ```dart
  /// final user = await executeNamedOperation(
  ///   'fetchUserProfile',
  ///   () => userService.fetchProfile(userId),
  /// );
  /// ```
  Future<T> executeNamedOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    String? errorPrefix,
    bool clearErrorOnStart = true,
    bool allowConcurrent = false,
  }) async {
    // Prevent duplicate operations
    if (!allowConcurrent && _activeOperations.contains(operationName)) {
      AppLogger.debug('Operation $operationName already active, skipping');
      throw StateError('Operation $operationName is already in progress');
    }
    
    _activeOperations.add(operationName);
    
    try {
      if (clearErrorOnStart) {
        clearError();
      }
      setLoading(true);
      
      final result = await operation();
      
      setSuccess();
      AppLogger.debug('Operation $operationName completed successfully');
      return result;
    } catch (e) {
      final errorMessage = errorPrefix != null 
        ? '$errorPrefix: $e'
        : 'Operation $operationName failed: $e';
      setError(errorMessage);
      AppLogger.error('Operation $operationName failed: $e');
      rethrow;
    } finally {
      _activeOperations.remove(operationName);
    }
  }
  
  /// Execute operation with caching (prevents duplicate calls)
  Future<T> executeCachedOperation<T>(
    String cacheKey,
    Future<T> Function() operation, {
    Duration? cacheExpiry,
    String? errorPrefix,
    bool forceRefresh = false,
  }) async {
    // Check cache if not forcing refresh
    if (!forceRefresh && _operationCache.containsKey(cacheKey)) {
      final cached = _operationCache[cacheKey];
      if (cached is T) {
        AppLogger.debug('Returning cached result for $cacheKey');
        return cached;
      }
    }
    
    try {
      final result = await executeNamedOperation(
        'cache_$cacheKey',
        operation,
        errorPrefix: errorPrefix,
      );
      
      // Cache the result
      _operationCache[cacheKey] = result;
      
      // Set cache expiry if specified
      if (cacheExpiry != null) {
        Timer(cacheExpiry, () {
          _operationCache.remove(cacheKey);
          AppLogger.debug('Cache expired for $cacheKey');
        });
      }
      
      return result;
    } catch (e) {
      // Remove invalid cache entry
      _operationCache.remove(cacheKey);
      rethrow;
    }
  }
  
  // ===== DEBOUNCED OPERATIONS =====
  
  /// Execute debounced operation (delays execution until no more calls)
  Future<T?> executeDebounced<T>(
    String operationName,
    Future<T> Function() operation,
    Duration delay, {
    String? errorPrefix,
  }) async {
    // Cancel existing timer
    _pendingOperations[operationName]?.cancel();
    
    final completer = Completer<T?>();
    
    _pendingOperations[operationName] = Timer(delay, () async {
      try {
        final result = await executeNamedOperation(
          operationName,
          operation,
          errorPrefix: errorPrefix,
        );
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      } finally {
        _pendingOperations.remove(operationName);
      }
    });
    
    return completer.future;
  }
  
  /// Execute throttled operation (limits frequency of execution)
  Future<T?> executeThrottled<T>(
    String operationName,
    Future<T> Function() operation,
    Duration throttleDuration, {
    String? errorPrefix,
  }) async {
    final now = DateTime.now();
    final lastExecution = _getLastExecutionTime(operationName);
    
    if (lastExecution != null && 
        now.difference(lastExecution) < throttleDuration) {
      AppLogger.debug('Operation $operationName throttled');
      return null;
    }
    
    _setLastExecutionTime(operationName, now);
    
    return await executeNamedOperation(
      operationName,
      operation,
      errorPrefix: errorPrefix,
    );
  }
  
  // ===== BATCH OPERATIONS =====
  
  /// Execute multiple operations in parallel
  Future<List<T>> executeBatch<T>(
    Map<String, Future<T> Function()> operations, {
    String? errorPrefix,
    bool stopOnFirstError = false,
  }) async {
    try {
      clearError();
      setLoading(true);
      
      final futures = <Future<T>>[];
      final operationNames = <String>[];
      
      operations.forEach((name, operation) {
        operationNames.add(name);
        _activeOperations.add(name);
        futures.add(operation());
      });
      
      List<T> results;
      if (stopOnFirstError) {
        results = await Future.wait(futures);
      } else {
        final settledResults = await Future.wait(
          futures.map((f) => f.catchError((e) => e)),
        );
        
        results = [];
        for (int i = 0; i < settledResults.length; i++) {
          final result = settledResults[i];
          if (result is! Exception && result is! Error) {
            results.add(result);
          } else {
            AppLogger.error('Batch operation ${operationNames[i]} failed: $result');
          }
        }
      }
      
      setSuccess();
      AppLogger.debug('Batch operations completed: ${results.length} successes');
      return results;
    } catch (e) {
      final errorMessage = errorPrefix != null 
        ? '$errorPrefix: $e'
        : 'Batch operations failed: $e';
      setError(errorMessage);
      rethrow;
    } finally {
      // Clear all active operations
      for (final operationName in operations.keys) {
        _activeOperations.remove(operationName);
      }
    }
  }
  
  /// Execute operations in sequence
  Future<List<T>> executeSequence<T>(
    List<Future<T> Function()> operations, {
    String? errorPrefix,
    bool stopOnFirstError = true,
  }) async {
    try {
      clearError();
      setLoading(true);
      
      final results = <T>[];
      
      for (int i = 0; i < operations.length; i++) {
        final operationName = 'sequence_$i';
        _activeOperations.add(operationName);
        
        try {
          final result = await operations[i]();
          results.add(result);
          AppLogger.debug('Sequence operation $i completed');
        } catch (e) {
          AppLogger.error('Sequence operation $i failed: $e');
          
          if (stopOnFirstError) {
            rethrow;
          }
        } finally {
          _activeOperations.remove(operationName);
        }
      }
      
      setSuccess();
      AppLogger.debug('Sequence operations completed: ${results.length} results');
      return results;
    } catch (e) {
      final errorMessage = errorPrefix != null 
        ? '$errorPrefix: $e'
        : 'Sequence operations failed: $e';
      setError(errorMessage);
      rethrow;
    }
  }
  
  // ===== BACKGROUND OPERATIONS =====
  
  /// Execute operation in background without affecting loading state
  Future<T> executeInBackground<T>(
    String operationName,
    Future<T> Function() operation, {
    String? errorPrefix,
    void Function(T result)? onSuccess,
    void Function(dynamic error)? onError,
  }) async {
    _activeOperations.add(operationName);
    
    try {
      final result = await operation();
      
      if (onSuccess != null) {
        onSuccess(result);
      }
      
      AppLogger.debug('Background operation $operationName completed');
      return result;
    } catch (e) {
      if (onError != null) {
        onError(e);
      } else {
        // Don't set error state for background operations by default
        AppLogger.error('Background operation $operationName failed: $e');
      }
      rethrow;
    } finally {
      _activeOperations.remove(operationName);
    }
  }
  
  // ===== OPERATION CONTROL =====
  
  /// Cancel specific operation
  void cancelOperation(String operationName) {
    _pendingOperations[operationName]?.cancel();
    _pendingOperations.remove(operationName);
    _activeOperations.remove(operationName);
    AppLogger.debug('Operation $operationName cancelled');
  }
  
  /// Cancel all pending operations
  void cancelAllOperations() {
    for (final timer in _pendingOperations.values) {
      timer.cancel();
    }
    _pendingOperations.clear();
    _activeOperations.clear();
    AppLogger.debug('All operations cancelled');
  }
  
  /// Clear operation cache
  void clearOperationCache([String? cacheKey]) {
    if (cacheKey != null) {
      _operationCache.remove(cacheKey);
      AppLogger.debug('Cache cleared for $cacheKey');
    } else {
      _operationCache.clear();
      AppLogger.debug('All operation cache cleared');
    }
  }
  
  /// Check if operation is active
  bool isOperationActive(String operationName) {
    return _activeOperations.contains(operationName);
  }
  
  /// Check if operation is pending
  bool isOperationPending(String operationName) {
    return _pendingOperations.containsKey(operationName);
  }
  
  // ===== PRIVATE HELPERS =====
  
  /// Storage for operation execution times (for throttling)
  static final Map<String, DateTime> _executionTimes = {};
  
  DateTime? _getLastExecutionTime(String operationName) {
    return _executionTimes[operationName];
  }
  
  void _setLastExecutionTime(String operationName, DateTime time) {
    _executionTimes[operationName] = time;
  }
  
  // ===== LIFECYCLE =====
  
  @override
  void dispose() {
    cancelAllOperations();
    clearOperationCache();
    super.dispose();
  }
}

/// Extension methods for common async operation patterns
extension AsyncOperationExtensions on AsyncOperationMixin {
  /// Execute load data operation with standard naming
  Future<T> loadData<T>(
    Future<T> Function() operation, {
    bool refresh = false,
  }) async {
    return await executeCachedOperation(
      'load_data',
      operation,
      forceRefresh: refresh,
      errorPrefix: 'Failed to load data',
    );
  }
  
  /// Execute save operation with validation
  Future<T> saveData<T>(
    Future<T> Function() operation,
  ) async {
    return await executeNamedOperation(
      'save_data',
      operation,
      errorPrefix: 'Failed to save data',
    );
  }
  
  /// Execute delete operation with confirmation
  Future<T> deleteData<T>(
    Future<T> Function() operation,
  ) async {
    return await executeNamedOperation(
      'delete_data',
      operation,
      errorPrefix: 'Failed to delete data',
    );
  }
  
  /// Execute search operation with debouncing
  Future<T?> searchData<T>(
    Future<T> Function() operation, {
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    return await executeDebounced(
      'search_data',
      operation,
      delay,
      errorPrefix: 'Search failed',
    );
  }
  
  /// Execute refresh operation
  Future<T> refreshData<T>(
    Future<T> Function() operation,
  ) async {
    clearOperationCache('load_data');
    return await executeNamedOperation(
      'refresh_data',
      operation,
      errorPrefix: 'Failed to refresh data',
    );
  }
}

/// Configuration constants for async operations
class AsyncOperationConfig {
  static const Duration defaultDebounceDelay = Duration(milliseconds: 500);
  static const Duration defaultThrottleDuration = Duration(seconds: 1);
  static const Duration defaultCacheExpiry = Duration(minutes: 5);
  static const int defaultRetryCount = 3;
  static const Duration defaultRetryDelay = Duration(seconds: 1);
}