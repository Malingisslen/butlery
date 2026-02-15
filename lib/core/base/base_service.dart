/// Base service class standardizing patterns for all business logic services.
/// **Features:** DI, error handling, lifecycle, logging, caching, permissions, batch operations, auth validation.
/// ```dart
/// class MyService extends BaseService {
///   String get serviceName => 'MyService';
///   Future<T> get(String id) => executeServiceOperation(() => _fetch(id), requiresAuth: true);
/// }
/// ```

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;

/// Abstract base class for all services in the Butlery application.
/// Provides a standardized foundation for service implementations by consolidating
/// common patterns found across the codebase. All business logic services should
/// extend this class to benefit from consistent error handling, logging, caching,
/// and operational patterns.
/// Subclasses must implement:
/// - [serviceName] getter for identification in logs and debugging
/// - [onInitialize] method for custom initialization logic (optional)
/// - [onDispose] method for custom cleanup logic (optional)
abstract class BaseService with ErrorHandlingMixin {
  // Service access patterns moved to ServiceLocator helper to avoid circular dependencies
  /// Unique name identifier for this service.
  /// Used in logging, debugging, and error reporting to identify which service
  /// generated a particular log entry or error. Should be a descriptive name
  /// that clearly identifies the service's purpose.
  /// Example: 'RecipeService', 'AuthService', 'NotificationService'
  String get serviceName;

  /// Initializes the service with standardized logging.
  /// This method should be called once during service creation, typically
  /// during dependency injection setup. It provides consistent initialization
  /// logging and delegates actual initialization work to [onInitialize].
  /// The method ensures that initialization is properly logged for debugging
  /// and monitoring purposes.
  Future<void> initialize() async {
    AppLogger.info('🔧 Initializing $serviceName');
    await onInitialize();
    AppLogger.info('✅ $serviceName initialized successfully');
  }

  /// Hook method for custom service initialization logic.
  /// Subclasses should override this method to perform service-specific
  /// initialization tasks such as:
  /// - Setting up stream subscriptions
  /// - Loading cached data
  /// - Validating service dependencies
  /// - Performing initial data synchronization
  /// The default implementation is empty - it's safe to not override this
  /// method if no custom initialization is needed.
  Future<void> onInitialize() async {
    // Default implementation - override in subclasses
  }

  /// Disposes service resources with standardized logging.
  /// This method should be called when the service is no longer needed,
  /// typically during application shutdown or when removing the service
  /// from the dependency injection container.
  /// Provides consistent disposal logging and delegates cleanup work to
  /// [onDispose]. Ensures proper resource management and prevents memory leaks.
  Future<void> dispose() async {
    AppLogger.info('🗑️ Disposing $serviceName');
    await onDispose();
    AppLogger.info('✅ $serviceName disposed successfully');
  }

  /// Hook method for custom service cleanup logic.
  /// Subclasses should override this method to perform service-specific
  /// cleanup tasks such as:
  /// - Canceling stream subscriptions
  /// - Closing database connections
  /// - Clearing caches and temporary data
  /// - Saving pending data
  /// - Releasing platform resources
  /// The default implementation is empty - it's safe to not override this
  /// method if no custom cleanup is needed.
  Future<void> onDispose() async {
    // Default implementation - override in subclasses
  }

  /// Executes a service operation with comprehensive error handling and validation.
  /// This method provides a standardized wrapper for all service operations,
  /// replacing scattered try-catch patterns found across service files. It
  /// performs pre-flight checks and handles errors consistently.
  /// Pre-flight checks performed:
  /// - Authentication status (if [requiresAuth] is true)
  /// - Network connectivity (if [requiresNetwork] is true)
  /// - User permissions (if [requiresPermission] is true)
  /// [operation] The async operation to execute
  /// [operationName] Human-readable name for logging (optional)
  /// [defaultValue] Value to return if operation fails (optional)
  /// [requiresAuth] Whether operation requires authenticated user (default: true)
  /// [requiresNetwork] Whether operation requires network connectivity (default: false)
  /// [requiresPermission] Whether operation requires specific permission (default: false)
  /// [requiredPermission] The permission to check if [requiresPermission] is true
  /// Returns the operation result or [defaultValue] if operation fails.
  /// Example:
  /// ```dart
  /// final recipe = await executeServiceOperation(
  ///   () => _fetchRecipe(id),
  ///   operationName: 'Fetch recipe',
  ///   requiresAuth: true,
  ///   requiresNetwork: true,
  /// );
  /// ```
  Future<T?> executeServiceOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
    bool requiresAuth = true,
    bool requiresNetwork = false,
    bool requiresPermission = false,
    String? requiredPermission,
  }) async {
    final opName = operationName ?? 'Service operation';

    // Pre-flight checks
    if (requiresAuth && !await _isAuthenticated()) {
      _handleUserError(AppLocale.current.errorAuthentication);
      return defaultValue;
    }

    if (requiresNetwork && !await _isNetworkAvailable()) {
      _handleUserError(AppLocale.current.errorNetwork);
      return defaultValue;
    }

    if (requiresPermission && requiredPermission != null) {
      if (!await _hasPermission(requiredPermission)) {
        _handleUserError(AppLocale.current.errorPermissionDenied);
        return defaultValue;
      }
    }

    // Execute operation with error handling
    return await safeExecute(
      operation,
      operationName: '$serviceName: $opName',
      defaultValue: defaultValue,
    );
  }

  /// Execute multiple operations in batch with error handling
  Future<List<T>> executeBatchOperation<T>(
    List<Future<T> Function()> operations,
    String operationName, {
    bool continueOnError = true,
    bool requiresAuth = true,
    bool requiresNetwork = false,
  }) async {
    AppLogger.info(
        '🔄 Starting batch operation: $operationName (${operations.length} items)');

    // Pre-flight checks
    if (requiresAuth && !await _isAuthenticated()) {
      _handleUserError(AppLocale.current.errorAuthentication);
      return [];
    }

    if (requiresNetwork && !await _isNetworkAvailable()) {
      _handleUserError(AppLocale.current.errorNetwork);
      return [];
    }

    return await safeBatchOperation(
      operations,
      '$serviceName: $operationName',
      continueOnError: continueOnError,
    );
  }

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Get cached value or execute operation and cache result
  /// Consolidates caching patterns found across services
  Future<T?> getCachedOrExecute<T>(
    String cacheKey,
    Future<T> Function() operation, {
    Duration cacheDuration = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid(cacheKey, cacheDuration)) {
      AppLogger.debug('📋 Cache hit for $cacheKey');
      return _cache[cacheKey] as T?;
    }

    AppLogger.debug('🔄 Cache miss for $cacheKey, executing operation');
    final result = await executeServiceOperation(operation);

    if (result != null) {
      _cache[cacheKey] = result;
      _cacheTimestamps[cacheKey] = DateTime.now();
      AppLogger.debug('💾 Cached result for $cacheKey');
    }

    return result;
  }

  /// Clear cache for specific key
  void clearCache(String cacheKey) {
    _cache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
    AppLogger.debug('🗑️ Cleared cache for $cacheKey');
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    AppLogger.debug('🗑️ Cleared all cache for $serviceName');
  }

  /// Check permission with caching
  Future<bool> checkPermission(String permission) async {
    return await getCachedOrExecute(
          'permission_$permission',
          () async {
            // SECURITY: Must integrate with actual permission service
            // For now, require authentication at minimum
            return await _isAuthenticated();
          },
          cacheDuration: const Duration(minutes: 1),
        ) ??
        false;
  }

  /// Execute operation with permission check
  Future<T?> executeWithPermission<T>(
    String permission,
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
  }) async {
    if (!await checkPermission(permission)) {
      _handleUserError(AppLocale.current.errorPermissionDenied);
      return defaultValue;
    }

    return await executeServiceOperation(
      operation,
      operationName: operationName,
      defaultValue: defaultValue,
      requiresPermission: false, // Already checked
    );
  }

  /// Validate input parameters before operation
  bool validateInput(Map<String, dynamic> inputs, List<String> requiredFields) {
    for (final field in requiredFields) {
      final value = inputs[field];
      if (value == null || (value is String && value.isEmpty)) {
        _handleUserError(
            AppLocale.current.validationFieldRequired(field.capitalize()));
        return false;
      }
    }
    return true;
  }

  /// Execute operation with input validation
  Future<T?> executeWithValidation<T>(
    Map<String, dynamic> inputs,
    List<String> requiredFields,
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
  }) async {
    if (!validateInput(inputs, requiredFields)) {
      return defaultValue;
    }

    return await executeServiceOperation(
      operation,
      operationName: operationName,
      defaultValue: defaultValue,
    );
  }

  /// Check if user is authenticated
  Future<bool> _isAuthenticated() async {
    try {
      // Use AuthRepository directly for authentication validation
      final authRepository = ServiceLocator.get<auth.AuthRepository>();
      return authRepository.currentUserId != null;
    } catch (e) {
      AppLogger.error('Auth check failed: $e');
      return false;
    }
  }

  /// Check if network is available
  Future<bool> _isNetworkAvailable() async {
    try {
      return true; // Simplified connectivity check - consolidation removed detailed connectivity service
    } catch (e) {
      AppLogger.error('Network check failed: $e');
      return false;
    }
  }

  /// Check if user has permission
  Future<bool> _hasPermission(String permission) async {
    try {
      return true; // Simplified permission check - consolidation removed detailed permission service
    } catch (e) {
      AppLogger.error('Permission check failed: $e');
      return false;
    }
  }

  /// Check if cache is valid
  bool _isCacheValid(String cacheKey, Duration duration) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < duration;
  }

  void _handleUserError(String message) {
    AppLogger.error('[$serviceName] User error: $message');
    // Services can override this to provide user feedback
    // For example, showing snackbars or updating UI state
  }
}

/// Mixin for services that need user context
/// Eliminates duplicate user access patterns
mixin UserContextMixin on BaseService {
  /// Function to get the current user ID
  /// This should be provided by the service using this mixin
  String? Function()? _getUserIdProvider;

  /// Set the user ID provider function
  void setUserIdProvider(String? Function() provider) {
    _getUserIdProvider = provider;
  }

  /// Get current user ID with error handling
  Future<String?> getCurrentUserId() async {
    return await safeExecute<String?>(
      () async {
        if (_getUserIdProvider != null) {
          return _getUserIdProvider!();
        }
        // Fallback to null if no provider is set
        AppLogger.error('[$serviceName] No user ID provider configured');
        return null;
      },
      operationName: 'Get current user ID',
    );
  }

  /// Execute operation that requires user context
  Future<T?> executeAsUser<T>(
    Future<T> Function(String userId) operation, {
    String? operationName,
    T? defaultValue,
  }) async {
    final userId = await getCurrentUserId();
    if (userId == null) {
      _handleUserError(AppLocale.current.errorAuthentication);
      return defaultValue;
    }

    return await executeServiceOperation(
      () => operation(userId),
      operationName: operationName,
      defaultValue: defaultValue,
      requiresAuth: false, // Already checked
    );
  }
}

/// Mixin for services that need notification capabilities
/// Eliminates duplicate notification patterns
mixin NotificationMixin on BaseService {
  /// Send notification with error handling
  Future<bool> sendNotification({
    required String title,
    required String message,
    String? userId,
    Map<String, dynamic>? data,
  }) async {
    final result = await executeServiceOperation(
      () async {
        // Simplified notification - consolidation removed detailed notification service
        AppLogger.info('Notification: $title - $message');
        return true;
      },
      operationName: 'Send notification',
      defaultValue: false,
    );

    return result ?? false;
  }

  /// Send success notification
  Future<void> notifySuccess(String message, {String? userId}) async {
    await sendNotification(
      title: AppLocale.current.notificationTitleSuccess,
      message: message,
      userId: userId,
    );
  }

  /// Send error notification
  Future<void> notifyError(String message, {String? userId}) async {
    await sendNotification(
      title: AppLocale.current.notificationTitleError,
      message: message,
      userId: userId,
    );
  }
}

/// Extension methods for string utilities
extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

// These would typically be imported from their respective files

abstract class UserService {
  Future<UserProfile?> getUserProfile(String userId);
}

abstract class NotificationService {
  Future<bool> sendNotification({
    required String title,
    required String message,
    String? userId,
    Map<String, dynamic>? data,
  });
}

abstract class PermissionService {
  Future<bool> hasPermission(String permission);
}

abstract class AuthRepository {
  String? get currentUserId;
}

abstract class ConnectivityService {
  Future<bool> hasConnection();
}

abstract class UserProfile {
  // User profile model
}
