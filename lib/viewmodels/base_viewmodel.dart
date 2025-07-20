// lib/viewmodels/base_viewmodel.dart

import 'package:flutter/foundation.dart';

/// Base ViewModel class that provides common functionality for all ViewModels
/// Eliminates duplication of loading state, error handling, and lifecycle management
abstract class BaseViewModel extends ChangeNotifier {
  // ===== COMMON STATE =====
  
  bool _isLoading = false;
  String? _error;
  bool _isDisposed = false;

  // ===== COMMON GETTERS =====

  /// Whether the ViewModel is currently loading
  bool get isLoading => _isLoading;

  /// Current error message, if any
  String? get error => _error;

  /// Whether there is an active error
  bool get hasError => _error != null;

  /// Whether the ViewModel has been disposed
  bool get isDisposed => _isDisposed;

  // ===== COMMON STATE MANAGEMENT =====

  /// Set loading state and notify listeners
  @protected
  void setLoading(bool loading) {
    if (_isDisposed) return;
    
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message and notify listeners
  @protected
  void setError(String? error) {
    if (_isDisposed) return;
    
    _error = error;
    _isLoading = false; // Stop loading when error occurs
    notifyListeners();
  }

  /// Clear current error
  void clearError() {
    if (_isDisposed) return;
    
    _error = null;
    notifyListeners();
  }

  /// Clear all state (loading and error)
  @protected
  void clearState() {
    if (_isDisposed) return;
    
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // ===== ASYNC OPERATION WRAPPER =====

  /// Execute an async operation with automatic loading state and error handling
  @protected
  Future<T?> executeAsync<T>(
    Future<T> Function() operation, {
    String? errorPrefix,
    bool clearErrorFirst = true,
  }) async {
    if (_isDisposed) return null;

    if (clearErrorFirst) clearError();
    setLoading(true);

    try {
      final result = await operation();
      setLoading(false);
      return result;
    } catch (e) {
      final errorMessage = errorPrefix != null 
          ? '$errorPrefix: ${e.toString()}'
          : e.toString();
      setError(errorMessage);
      return null;
    }
  }

  /// Execute an async operation that returns void
  @protected
  Future<bool> executeAsyncVoid(
    Future<void> Function() operation, {
    String? errorPrefix,
    bool clearErrorFirst = true,
  }) async {
    if (_isDisposed) return false;

    if (clearErrorFirst) clearError();
    setLoading(true);

    try {
      await operation();
      setLoading(false);
      return true;
    } catch (e) {
      final errorMessage = errorPrefix != null 
          ? '$errorPrefix: ${e.toString()}'
          : e.toString();
      setError(errorMessage);
      return false;
    }
  }

  // ===== LIFECYCLE MANAGEMENT =====

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ===== DEBUGGING SUPPORT =====

  /// Get debug information about the ViewModel state
  @protected
  Map<String, dynamic> get debugState => {
    'isLoading': _isLoading,
    'hasError': hasError,
    'error': _error,
    'isDisposed': _isDisposed,
  };

  /// Print debug information (only in debug mode)
  @protected
  void printDebugState([String? prefix]) {
    if (kDebugMode) {
      final label = prefix ?? runtimeType.toString();
      debugPrint('$label State: $debugState');
    }
  }
}

/// Extension methods for common ViewModel patterns
extension BaseViewModelExtensions on BaseViewModel {
  /// Whether the ViewModel is ready (not loading and no error)
  bool get isReady => !isLoading && !hasError;

  /// Whether the ViewModel is in error state
  bool get isInErrorState => hasError && !isLoading;

  /// Whether the ViewModel is busy (loading)
  bool get isBusy => isLoading;
}

/// Mixin for ViewModels that handle async operations with consistent patterns
mixin AsyncOperationMixin on BaseViewModel {
  
  /// Execute operation with retry capability
  Future<T?> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    String? errorPrefix,
  }) async {
    if (isDisposed) return null;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await executeAsync<T>(
        operation,
        errorPrefix: attempt == maxRetries 
            ? errorPrefix 
            : null, // Only show error on final attempt
        clearErrorFirst: attempt == 1,
      );
      
      if (result != null || attempt == maxRetries) {
        return result;
      }
      
      // Wait before retry
      await Future.delayed(delay);
    }
    
    return null;
  }
}

/// Mixin for ViewModels that handle validation
mixin ValidationMixin on BaseViewModel {
  
  final Map<String, String?> _validationErrors = {};

  /// Get validation errors map
  Map<String, String?> get validationErrors => Map.unmodifiable(_validationErrors);

  /// Whether there are any validation errors
  bool get hasValidationErrors => _validationErrors.values.any((error) => error != null);

  /// Set validation error for a specific field
  @protected
  void setValidationError(String field, String? error) {
    if (isDisposed) return;
    
    _validationErrors[field] = error;
    notifyListeners();
  }

  /// Clear validation error for a specific field
  @protected
  void clearValidationError(String field) {
    if (isDisposed) return;
    
    _validationErrors.remove(field);
    notifyListeners();
  }

  /// Clear all validation errors
  @protected
  void clearAllValidationErrors() {
    if (isDisposed) return;
    
    _validationErrors.clear();
    notifyListeners();
  }

  /// Get validation error for a specific field
  String? getValidationError(String field) => _validationErrors[field];

  /// Whether the form/data is valid (no validation errors and no global errors)
  bool get isValid => !hasValidationErrors && !hasError;
}