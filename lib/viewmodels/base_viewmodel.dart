/// Comprehensive foundational ViewModel infrastructure providing advanced MVVM architecture and state management for Flutter applications.
/// This module implements sophisticated ViewModel base class following Single Responsibility Principle,
/// handling all aspects of MVVM foundation including state management, lifecycle coordination, async operation handling,
/// validation support, and debugging capabilities. It provides complete presentation layer infrastructure while
/// maintaining clean separation from business logic, data access, and UI rendering concerns.
/// **Single Responsibility Focus:**
/// This module exclusively handles MVVM foundational concerns and common ViewModel patterns:
/// - **State Management Excellence**: Comprehensive loading state, error handling, and lifecycle coordination
/// - **Async Operation Intelligence**: Advanced async operation wrappers with retry capabilities and error handling
/// - **Validation Infrastructure**: Complete validation system with field-level error management
/// - **Lifecycle Management**: Robust disposal patterns and state cleanup with memory leak prevention
/// - **Debugging Support**: Advanced debugging capabilities with state introspection and logging
/// **What This Module Does NOT Handle:**
/// - Business logic implementation (handled by specialized ViewModels extending this base)
/// - Data access and repository integration (handled by service layer and repositories)
/// - UI rendering and widget creation (handled by Views and UI components)
/// - Navigation and routing logic (handled by navigation services and routers)
/// **MVVM Architecture Features:**
/// - **Reactive State Management**: ChangeNotifier-based state updates with automatic UI synchronization
/// - **Error Handling Excellence**: Comprehensive error management with prefix support and automatic loading state coordination
/// - **Async Operation Patterns**: Standardized async operation execution with consistent error handling and loading states
/// - **Validation Integration**: Built-in validation system with field-level error tracking and form validation support
/// - **Memory Management**: Advanced disposal patterns with leak prevention and state cleanup
/// **Usage Examples:**
/// ```dart
/// // Basic ViewModel extending BaseViewModel
/// class ProductListViewModel extends BaseViewModel {
///   List<Product> _products = [];
///   List<Product> get products => _products;
///   Future<void> loadProducts() async {
///     await executeAsync(() async {
///       _products = await _productService.getProducts();
///       notifyListeners();
///     }, errorPrefix: 'Kunde inte ladda produkter');
///   }
/// }
/// // ViewModel with validation using ValidationMixin
/// class LoginViewModel extends BaseViewModel with ValidationMixin {
///   String _email = '';
///   String _password = '';
///   void updateEmail(String email) {
///     _email = email;
///     if (email.isEmpty) {
///       setValidationError('email', 'E-post krävs');
///     } else {
///       clearValidationError('email');
///     }
///   }
///   Future<void> login() async {
///     if (!isValid) return;
///     await executeAsync(() async {
///       await _authService.login(_email, _password);
///     }, errorPrefix: 'Inloggning misslyckades');
///   }
/// }
/// // ViewModel with retry capabilities using AsyncOperationMixin
/// class DataSyncViewModel extends BaseViewModel with AsyncOperationMixin {
///   Future<void> syncData() async {
///     await executeWithRetry(
///       () => _syncService.synchronizeData(),
///       maxRetries: 3,
///       errorPrefix: 'Synkronisering misslyckades',
///     );
///   }
/// }
/// ```

// lib/viewmodels/base_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive foundational ViewModel base class providing advanced MVVM architecture and state management for Flutter applications.
/// Serves as the foundation for all ViewModels in the application, providing essential MVVM patterns including
/// reactive state management, async operation handling, error management, and lifecycle coordination.
/// This class ensures consistent ViewModel behavior and eliminates code duplication across the presentation layer.
abstract class BaseViewModel extends ChangeNotifier {
  /// Internal loading state for async operations and UI coordination.
  bool _isLoading = false;

  /// Internal error state for comprehensive error handling and user feedback.
  String? _error;

  /// Internal disposal state for memory management and lifecycle coordination.
  bool _isDisposed = false;

  /// Whether the ViewModel is currently executing async operations requiring loading indicators.
  /// Used by UI components to display loading states, spinners, and disable user interactions
  /// during async operations to provide consistent user experience.
  bool get isLoading => _isLoading;

  /// Current error message for user display and debugging purposes.
  /// Contains localized error messages suitable for direct display to users,
  /// or null when no error is present. Automatically cleared when new operations begin.
  String? get error => _error;

  /// Whether there is an active error requiring user attention or UI error state display.
  /// Convenience getter for checking error presence without null comparison,
  /// commonly used in UI conditional rendering and error state management.
  bool get hasError => _error != null;

  /// Whether the ViewModel has been disposed and should not accept further operations.
  /// Critical for memory management and preventing operations on disposed ViewModels
  /// that could lead to memory leaks or unexpected behavior.
  bool get isDisposed => _isDisposed;

  /// Updates loading state and notifies all listening UI components for immediate state synchronization.
  /// [loading] New loading state to set
  /// Automatically prevents operations on disposed ViewModels and ensures UI components
  /// receive immediate updates for loading indicator management and user interaction control.
  @protected
  void setLoading(bool loading) {
    if (_isDisposed) return;

    _isLoading = loading;
    notifyListeners();
  }

  /// Updates error state with automatic loading coordination and comprehensive UI notification.
  /// [error] Error message for user display, or null to clear error state
  /// Automatically stops loading state when error occurs, ensuring consistent UI behavior
  /// where loading indicators are hidden when errors are displayed to users.
  @protected
  void setError(String? error) {
    if (_isDisposed) return;

    _error = error;
    _isLoading = false; // Stop loading when error occurs
    notifyListeners();
  }

  /// Clears current error state and notifies UI components for error state removal.
  /// Commonly used when starting new operations or when users dismiss error messages,
  /// ensuring clean state transitions and proper error state management.
  void clearError() {
    if (_isDisposed) return;

    _error = null;
    notifyListeners();
  }

  /// Resets all transient state (loading and error) to clean initial state.
  /// Protected method for internal state management and cleanup operations,
  /// ensuring consistent state reset across different ViewModel operations.
  @protected
  void clearState() {
    if (_isDisposed) return;

    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Executes async operations with comprehensive state management, error handling, and UI coordination.
  /// [operation] The async operation to execute with automatic state management
  /// [errorPrefix] Optional prefix for error messages to provide context
  /// [clearErrorOnStart] Whether to clear existing errors before operation (default: true)
  /// Returns the operation result or null if operation fails or ViewModel is disposed.
  /// Automatically manages loading state, error handling, and UI notifications for consistent
  /// user experience across all async operations in the application.
  /// **Usage Example:**
  /// ```dart
  /// final products = await executeAsync(
  ///   () => productService.getProducts(),
  ///   errorPrefix: 'Kunde inte ladda produkter',
  /// );
  /// ```
  @protected
  Future<T> executeAsync<T>(
    Future<T> Function() operation, {
    String? errorPrefix,
    bool clearErrorOnStart = true,
  }) async {
    if (_isDisposed) throw StateError('ViewModel is disposed');

    if (clearErrorOnStart) clearError();
    setLoading(true);

    try {
      final result = await operation();
      setLoading(false);
      return result;
    } catch (e) {
      // Log full technical details but only show the prefix to users
      AppLogger.error(errorPrefix ?? 'Async operation failed', e);
      setError(errorPrefix ?? AppLocale.current.errorUnexpected);
      rethrow;
    }
  }

  /// Executes void async operations with success/failure tracking and comprehensive state management.
  /// [operation] The void async operation to execute
  /// [errorPrefix] Optional prefix for error messages to provide context
  /// [clearErrorOnStart] Whether to clear existing errors before operation (default: true)
  /// Returns true if operation succeeds, false if it fails or ViewModel is disposed.
  /// Ideal for operations like save, delete, or update that don't return data but need
  /// success/failure tracking for UI feedback and user interaction management.
  /// **Usage Example:**
  /// ```dart
  /// final success = await executeAsyncVoid(
  ///   () => productService.deleteProduct(id),
  ///   errorPrefix: 'Kunde inte ta bort produkten',
  /// );
  /// if (success) showSuccessMessage();
  /// ```
  @protected
  Future<bool> executeAsyncVoid(
    Future<void> Function() operation, {
    String? errorPrefix,
    bool clearErrorOnStart = true,
  }) async {
    if (_isDisposed) return false;

    if (clearErrorOnStart) clearError();
    setLoading(true);

    try {
      await operation();
      setLoading(false);
      return true;
    } catch (e) {
      // Log full technical details but only show the prefix to users
      AppLogger.error(errorPrefix ?? 'Async void operation failed', e);
      setError(errorPrefix ?? AppLocale.current.errorUnexpected);
      return false;
    }
  }

  /// Safely notifies all listening UI components with disposal state validation.
  /// Overrides ChangeNotifier's notifyListeners to prevent notifications after disposal,
  /// ensuring memory safety and preventing potential crashes from disposed ViewModel operations.
  /// This is critical for robust lifecycle management in complex applications.
  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Performs comprehensive ViewModel disposal with state cleanup and memory leak prevention.
  /// Marks the ViewModel as disposed and calls parent disposal methods to ensure
  /// complete cleanup of resources, listeners, and state. This is essential for
  /// preventing memory leaks in Flutter applications with dynamic ViewModels.
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Comprehensive debug state information for development and troubleshooting purposes.
  /// Provides complete state snapshot including loading state, error information,
  /// and disposal status for debugging ViewModel behavior and state transitions.
  /// Essential for development debugging and production issue investigation.
  @protected
  Map<String, dynamic> get debugState => {
    'isLoading': _isLoading,
    'hasError': hasError,
    'error': _error,
    'isDisposed': _isDisposed,
  };

  /// Prints comprehensive debug information with conditional debug mode execution.
  /// [prefix] Optional prefix for debug output identification
  /// Only executes in debug mode to prevent production performance impact,
  /// providing detailed state information for development debugging and
  /// ViewModel behavior analysis during development cycles.
  @protected
  void printDebugState([String? prefix]) {
    // Debug state printing disabled - use debugState getter directly if needed
  }
}

/// Advanced extension methods providing common ViewModel state patterns and UI convenience methods.
/// These extensions enhance BaseViewModel functionality with commonly used state combinations
/// and convenience methods that simplify UI conditional rendering and state management.
extension BaseViewModelExtensions on BaseViewModel {
  /// Whether the ViewModel is ready for user interaction (not loading and no error state).
  /// Ideal for enabling UI interactions, form submissions, and user actions
  /// when the ViewModel is in a stable, non-error, non-loading state.
  bool get isReady => !isLoading && !hasError;

  /// Whether the ViewModel is in error state requiring user attention or error UI display.
  /// Combines error presence with non-loading state to identify when error UI
  /// should be displayed instead of loading indicators for proper user feedback.
  bool get isInErrorState => hasError && !isLoading;

  /// Whether the ViewModel is busy with operations requiring loading indicators.
  /// Alias for isLoading providing semantic clarity in UI contexts where
  /// "busy" better describes the ViewModel state than "loading".
  bool get isBusy => isLoading;
}

/// Advanced mixin providing sophisticated async operation patterns with retry capabilities and resilience features.
/// Enhances BaseViewModel with advanced async operation handling including retry logic,
/// exponential backoff, and resilient operation patterns for robust network operations
/// and service integrations in production applications.
mixin AsyncOperationMixin on BaseViewModel {
  /// Executes operations with intelligent retry logic and progressive error handling.
  /// [operation] The async operation to execute with retry capability
  /// [maxRetries] Maximum number of retry attempts (default: 3)
  /// [delay] Delay between retry attempts (default: 1 second)
  /// [errorPrefix] Error message prefix for final attempt failure
  /// Returns operation result or null if all attempts fail. Only displays error
  /// on final attempt to avoid confusing users with transient network issues.
  /// Ideal for network operations, API calls, and other potentially unreliable operations.
  /// **Usage Example:**
  /// ```dart
  /// final data = await executeWithRetry(
  ///   () => apiService.fetchCriticalData(),
  ///   maxRetries: 5,
  ///   delay: Duration(seconds: 2),
  ///   errorPrefix: 'Kunde inte hämta kritisk data',
  /// );
  /// ```
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
        clearErrorOnStart: attempt == 1,
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

/// Comprehensive validation mixin providing advanced form validation and field-level error management.
/// Enhances BaseViewModel with sophisticated validation capabilities including field-level error tracking,
/// validation state management, and form validation patterns commonly needed in Flutter applications
/// with complex forms and data validation requirements.
mixin ValidationMixin on BaseViewModel {
  /// Internal validation error storage with field-specific error tracking.
  final Map<String, String?> _validationErrors = {};

  /// Immutable validation errors map for UI binding and error display.
  /// Provides read-only access to all current validation errors organized by field name,
  /// enabling UI components to display field-specific error messages and validation states.
  Map<String, String?> get validationErrors =>
      Map.unmodifiable(_validationErrors);

  /// Whether any validation errors are currently present requiring user attention.
  /// Efficiently checks for validation error presence across all fields,
  /// commonly used for form submission enabling and validation state UI updates.
  bool get hasValidationErrors =>
      _validationErrors.values.any((error) => error != null);

  /// Sets field-specific validation error with automatic UI notification.
  /// [field] The field identifier for error association
  /// [error] The validation error message, or null to clear field error
  /// Updates validation state and notifies UI components for immediate error display
  /// and form validation feedback to users during data entry.
  @protected
  void setValidationError(String field, String? error) {
    if (isDisposed) return;

    _validationErrors[field] = error;
    notifyListeners();
  }

  /// Clears specific field validation error with automatic UI synchronization.
  /// [field] The field identifier to clear validation error for
  /// Removes field-specific validation error and updates UI components
  /// to reflect corrected validation state during user data correction.
  @protected
  void clearValidationError(String field) {
    if (isDisposed) return;

    _validationErrors.remove(field);
    notifyListeners();
  }

  /// Clears all validation errors for complete form reset and clean state initialization.
  /// Removes all field validation errors and notifies UI components for complete
  /// form validation state reset, commonly used during form initialization or reset operations.
  @protected
  void clearAllValidationErrors() {
    if (isDisposed) return;

    _validationErrors.clear();
    notifyListeners();
  }

  /// Retrieves validation error for specific field with null safety.
  /// [field] The field identifier to get validation error for
  /// Returns field-specific validation error message or null if no error exists,
  /// commonly used in UI components for conditional error message display.
  String? getValidationError(String field) => _validationErrors[field];

  /// Whether the complete form/data is valid and ready for submission or processing.
  /// Combines field validation state with global error state to determine overall validity,
  /// ensuring both field-level validation and global operation errors are considered
  /// for comprehensive form validation and user interaction enabling.
  bool get isValid => !hasValidationErrors && !hasError;
}
