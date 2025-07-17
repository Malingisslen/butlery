/// 🔍 AI INFO BLOCK:
/// Component: StateNotifier Mixin - Eliminates state management duplication in 37+ files
/// File: lib/core/mixins/state_notifier_mixin.dart
/// Quick Guide: Provides common loading/error state management for services and ViewModels
/// Dependencies IN: Flutter ChangeNotifier, Logger utilities
/// Dependencies OUT: Used by all services and ViewModels needing state management
/// Data flow: State changes -> StateNotifier -> UI updates via notifyListeners
/// State management: Centralized loading/error state with consistent patterns
/// Purpose: Eliminate duplicated _isLoading, _error, _setLoading, _setError patterns
/// Common issues: State consistency, error clearing, loading state conflicts
/// Test coverage: Unit tests for all state transitions and edge cases
/// Performance: Minimal overhead, efficient state change notifications
/// Analytics: State change tracking, error occurrence monitoring
/// Code smells: None - clean abstraction for common state patterns
/// Connected to: All services, ViewModels, and components with async operations
/// Used in phases: Phase 7 - Additional Code Duplication Elimination

import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Mixin that provides common state management functionality
/// 
/// This mixin eliminates the duplicated state management pattern found in 37+ files:
/// - `bool _isLoading = false;`
/// - `String? _error;`
/// - `void _setLoading(bool loading) { ... }`
/// - `void _setError(String message) { ... }`
/// - `void _clearError() { ... }`
/// 
/// Pattern eliminated:
/// ```dart
/// // Before (duplicated in 37+ files):
/// class MyService extends ChangeNotifier {
///   bool _isLoading = false;
///   String? _error;
///   
///   bool get isLoading => _isLoading;
///   String? get error => _error;
///   bool get hasError => _error != null;
///   
///   void _setLoading(bool loading) {
///     _isLoading = loading;
///     notifyListeners();
///   }
///   
///   void _setError(String message) {
///     _error = message;
///     _isLoading = false;
///     notifyListeners();
///   }
/// }
/// 
/// // After (centralized):
/// class MyService extends ChangeNotifier with StateNotifierMixin {
///   // State management methods are automatically available
/// }
/// ```
mixin StateNotifierMixin on ChangeNotifier {
  // ===== PRIVATE STATE =====
  
  bool _isLoading = false;
  String? _error;
  
  // ===== PUBLIC GETTERS =====
  
  /// Whether the component is currently loading
  bool get isLoading => _isLoading;
  
  /// Current error message, null if no error
  String? get error => _error;
  
  /// Whether the component has an error
  bool get hasError => _error != null;
  
  /// Whether the component is in a success state (not loading, no error)
  bool get isSuccess => !_isLoading && _error == null;
  
  /// Whether the component is ready for user interaction
  bool get isIdle => !_isLoading;
  
  // ===== STATE MANAGEMENT METHODS =====
  
  /// Set loading state and notify listeners
  @protected
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
      AppLogger.debug('State changed: loading=$loading');
    }
  }
  
  /// Set error state, clear loading, and notify listeners
  @protected
  void setError(String message) {
    _error = message;
    _isLoading = false;
    notifyListeners();
    AppLogger.error('State error: $message');
  }
  
  /// Clear error state and notify listeners
  @protected
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
      AppLogger.debug('Error cleared');
    }
  }
  
  /// Clear all state (loading and error) and notify listeners
  @protected
  void clearState() {
    if (_isLoading || _error != null) {
      _isLoading = false;
      _error = null;
      notifyListeners();
      AppLogger.debug('All state cleared');
    }
  }
  
  /// Set success state (clear loading and error) and notify listeners
  @protected
  void setSuccess() {
    if (_isLoading || _error != null) {
      _isLoading = false;
      _error = null;
      notifyListeners();
      AppLogger.debug('Success state set');
    }
  }
  
  // ===== ASYNC OPERATION HELPERS =====
  
  /// Execute an async operation with automatic state management
  @protected
  Future<T> executeAsync<T>(
    Future<T> Function() operation, {
    String? errorPrefix,
    bool clearErrorOnStart = true,
  }) async {
    try {
      if (clearErrorOnStart) {
        clearError();
      }
      setLoading(true);
      
      final result = await operation();
      
      setSuccess();
      return result;
    } catch (e) {
      final errorMessage = errorPrefix != null 
        ? '$errorPrefix: $e'
        : e.toString();
      setError(errorMessage);
      rethrow;
    }
  }
  
  /// Execute an async operation without changing loading state (for background operations)
  @protected
  Future<T> executeAsyncSilent<T>(
    Future<T> Function() operation, {
    String? errorPrefix,
  }) async {
    try {
      final result = await operation();
      return result;
    } catch (e) {
      final errorMessage = errorPrefix != null 
        ? '$errorPrefix: $e'
        : e.toString();
      setError(errorMessage);
      rethrow;
    }
  }
  
  /// Execute multiple async operations in parallel with state management
  @protected
  Future<List<T>> executeAsyncParallel<T>(
    List<Future<T> Function()> operations, {
    String? errorPrefix,
    bool clearErrorOnStart = true,
  }) async {
    try {
      if (clearErrorOnStart) {
        clearError();
      }
      setLoading(true);
      
      final futures = operations.map((op) => op()).toList();
      final results = await Future.wait(futures);
      
      setSuccess();
      return results;
    } catch (e) {
      final errorMessage = errorPrefix != null 
        ? '$errorPrefix: $e'
        : e.toString();
      setError(errorMessage);
      rethrow;
    }
  }
  
  // ===== CONDITIONAL EXECUTION =====
  
  /// Execute operation only if not currently loading
  @protected
  Future<T?> executeIfNotLoading<T>(
    Future<T> Function() operation, {
    String? errorPrefix,
  }) async {
    if (_isLoading) {
      AppLogger.debug('Skipping operation: already loading');
      return null;
    }
    
    return await executeAsync(operation, errorPrefix: errorPrefix);
  }
  
  /// Execute operation and retry on failure with exponential backoff
  @protected
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    String? errorPrefix,
  }) async {
    int attempts = 0;
    Duration currentDelay = initialDelay;
    
    while (attempts < maxRetries) {
      try {
        if (attempts == 0) {
          clearError();
          setLoading(true);
        }
        
        final result = await operation();
        
        setSuccess();
        return result;
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          final errorMessage = errorPrefix != null 
            ? '$errorPrefix (after $attempts attempts): $e'
            : 'After $attempts attempts: $e';
          setError(errorMessage);
          rethrow;
        }
        
        AppLogger.warning('Operation failed, retrying in ${currentDelay.inSeconds}s (attempt $attempts/$maxRetries): $e');
        await Future.delayed(currentDelay);
        currentDelay *= 2; // Exponential backoff
      }
    }
    
    throw StateError('Should not reach here');
  }
  
  // ===== LIFECYCLE MANAGEMENT =====
  
  @override
  void dispose() {
    clearState();
    super.dispose();
  }
}

/// Extension methods for common state patterns
extension StateNotifierExtensions on StateNotifierMixin {
  /// Check if the component is ready for new operations
  bool get canExecuteOperation => !isLoading;
  
  /// Get state description for debugging
  String get stateDescription {
    if (isLoading) return 'Loading';
    if (hasError) return 'Error: $error';
    return 'Ready';
  }
  
  /// Execute operation with custom error message formatting
  Future<T> executeWithCustomError<T>(
    Future<T> Function() operation,
    String Function(dynamic error) errorFormatter,
  ) async {
    try {
      clearError();
      setLoading(true);
      
      final result = await operation();
      
      setSuccess();
      return result;
    } catch (e) {
      setError(errorFormatter(e));
      rethrow;
    }
  }
}

/// Specialized state notifier for network operations
mixin NetworkStateNotifierMixin on StateNotifierMixin {
  bool _isOnline = true;
  
  /// Whether the component is online
  bool get isOnline => _isOnline;
  
  /// Whether the component is offline
  bool get isOffline => !_isOnline;
  
  /// Set online/offline state
  @protected
  void setNetworkState(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
      AppLogger.info('Network state: ${online ? 'online' : 'offline'}');
    }
  }
  
  /// Execute operation with network state awareness
  @protected
  Future<T> executeNetworkOperation<T>(
    Future<T> Function() operation, {
    String offlineMessage = 'No internet connection',
  }) async {
    if (isOffline) {
      setError(offlineMessage);
      throw StateError(offlineMessage);
    }
    
    return await executeAsync(operation);
  }
}

/// Specialized state notifier for paginated data
mixin PaginatedStateNotifierMixin on StateNotifierMixin {
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  
  /// Whether more data is being loaded
  bool get isLoadingMore => _isLoadingMore;
  
  /// Whether more data is available
  bool get hasMoreData => _hasMoreData;
  
  /// Whether the component can load more data
  bool get canLoadMore => !_isLoadingMore && _hasMoreData && !isLoading;
  
  /// Set loading more state
  @protected
  void setLoadingMore(bool loading) {
    if (_isLoadingMore != loading) {
      _isLoadingMore = loading;
      notifyListeners();
      AppLogger.debug('Loading more: $loading');
    }
  }
  
  /// Set whether more data is available
  @protected
  void setHasMoreData(bool hasMore) {
    if (_hasMoreData != hasMore) {
      _hasMoreData = hasMore;
      notifyListeners();
      AppLogger.debug('Has more data: $hasMore');
    }
  }
  
  /// Execute load more operation
  @protected
  Future<T> executeLoadMore<T>(
    Future<T> Function() operation, {
    String? errorPrefix,
  }) async {
    if (!canLoadMore) {
      AppLogger.debug('Cannot load more: already loading or no more data');
      return null as T;
    }
    
    try {
      setLoadingMore(true);
      
      final result = await operation();
      
      return result;
    } catch (e) {
      final errorMessage = errorPrefix != null 
        ? '$errorPrefix: $e'
        : e.toString();
      setError(errorMessage);
      rethrow;
    } finally {
      setLoadingMore(false);
    }
  }
  
  /// Reset pagination state
  @protected
  void resetPagination() {
    _isLoadingMore = false;
    _hasMoreData = true;
    notifyListeners();
    AppLogger.debug('Pagination reset');
  }
  
  @override
  void dispose() {
    resetPagination();
    super.dispose();
  }
}