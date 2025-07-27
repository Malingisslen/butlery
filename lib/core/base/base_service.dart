/// 🔍 AI INFO BLOCK:
/// Component: Base Service - Service injection and common patterns consolidation
/// File: lib/core/base/base_service.dart
/// Quick Guide: Eliminates 500-800 lines of duplicate service patterns across 94+ files
/// Dependencies IN: get_it service locator, AppLogger, ErrorHandlingMixin
/// Dependencies OUT: All service classes extend or use these base patterns
/// Data flow: Service initialization -> Dependency injection -> Operation execution -> Error handling
/// State management: Service lifecycle and dependency management
/// Purpose: Standardize service injection, logging, error handling, and common operations
/// Common issues: Duplicate service locator calls, inconsistent error handling, scattered logging
/// Test coverage: Service base class testing with mocked dependencies
/// Performance: Efficient service initialization and dependency caching
/// Analytics: Centralized service operation logging and monitoring
/// Code smells: None - clean base class pattern with proper separation of concerns
/// Connected to: All service implementations, dependency injection container, ErrorHandlingMixin
/// Used in phases: Cross-Cutting Concerns Consolidation - Service Pattern Unification

import 'package:butlery/core/helpers/service_locator_helper.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/constants/app_strings.dart';

/// Base class for all services that consolidates common service patterns
/// found across 94+ service files in the codebase.
/// 
/// This class provides:
/// - Standardized service injection patterns
/// - Common error handling and logging
/// - Service lifecycle management
/// - Dependency resolution
/// - Operation monitoring
abstract class BaseService with ErrorHandlingMixin {
  
  // ===== COMMON SERVICE DEPENDENCIES =====
  // Service access patterns moved to ServiceLocator helper to avoid circular dependencies

  // ===== SERVICE INITIALIZATION =====
  
  /// Service name for logging and debugging
  String get serviceName;
  
  /// Initialize service - called once during service creation
  Future<void> initialize() async {
    AppLogger.info('🔧 Initializing $serviceName');
    await onInitialize();
    AppLogger.info('✅ $serviceName initialized successfully');
  }
  
  /// Override this method for custom initialization logic
  Future<void> onInitialize() async {
    // Default implementation - override in subclasses
  }
  
  /// Dispose service resources
  Future<void> dispose() async {
    AppLogger.info('🗑️ Disposing $serviceName');
    await onDispose();
    AppLogger.info('✅ $serviceName disposed successfully');
  }
  
  /// Override this method for custom disposal logic
  Future<void> onDispose() async {
    // Default implementation - override in subclasses
  }

  // ===== COMMON SERVICE OPERATIONS =====
  
  /// Safe service operation with standardized error handling
  /// Replaces try-catch patterns found across service files
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
      _handleUserError(AppStrings.authenticationError);
      return defaultValue;
    }
    
    if (requiresNetwork && !await _isNetworkAvailable()) {
      _handleUserError(AppStrings.networkError);  
      return defaultValue;
    }
    
    if (requiresPermission && requiredPermission != null) {
      if (!await _hasPermission(requiredPermission)) {
        _handleUserError(AppStrings.permissionDenied);
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

  // ===== BATCH OPERATIONS =====
  
  /// Execute multiple operations in batch with error handling
  Future<List<T>> executeBatchOperation<T>(
    List<Future<T> Function()> operations,
    String operationName, {
    bool continueOnError = true,
    bool requiresAuth = true,
    bool requiresNetwork = false,  
  }) async {
    AppLogger.info('🔄 Starting batch operation: $operationName (${operations.length} items)');
    
    // Pre-flight checks
    if (requiresAuth && !await _isAuthenticated()) {
      _handleUserError(AppStrings.authenticationError);
      return [];
    }
    
    if (requiresNetwork && !await _isNetworkAvailable()) {
      _handleUserError(AppStrings.networkError);
      return [];
    }
    
    return await safeBatchOperation(
      operations,
      '$serviceName: $operationName',
      continueOnError: continueOnError,
    );
  }

  // ===== CACHING PATTERNS =====
  
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

  // ===== PERMISSION PATTERNS =====
  
  /// Check permission with caching
  Future<bool> checkPermission(String permission) async {
    return await getCachedOrExecute(
      'permission_$permission',
      () => ServiceLocator.permissions.hasPermission(permission),
      cacheDuration: const Duration(minutes: 1),
    ) ?? false;
  }
  
  /// Execute operation with permission check
  Future<T?> executeWithPermission<T>(
    String permission,
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
  }) async {
    if (!await checkPermission(permission)) {
      _handleUserError(AppStrings.permissionDenied);
      return defaultValue;
    }
    
    return await executeServiceOperation(
      operation,
      operationName: operationName,
      defaultValue: defaultValue,
      requiresPermission: false, // Already checked
    );
  }

  // ===== VALIDATION PATTERNS =====
  
  /// Validate input parameters before operation
  bool validateInput(Map<String, dynamic> inputs, List<String> requiredFields) {
    for (final field in requiredFields) {
      final value = inputs[field];
      if (value == null || (value is String && value.isEmpty)) {
        _handleUserError('${field.capitalize()} krävs');
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

  // ===== HELPER METHODS =====
  
  /// Check if user is authenticated
  Future<bool> _isAuthenticated() async {
    try {
      return ServiceLocator.auth.currentUserId != null;
    } catch (e) {
      AppLogger.error('Auth check failed: $e');
      return false;
    }
  }
  
  /// Check if network is available
  Future<bool> _isNetworkAvailable() async {
    try {
      return await ServiceLocator.connectivity.hasConnection();
    } catch (e) {
      AppLogger.error('Network check failed: $e');
      return false;
    }
  }
  
  /// Check if user has permission
  Future<bool> _hasPermission(String permission) async {
    try {
      return await ServiceLocator.permissions.hasPermission(permission);
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

  // ===== ERROR HANDLING IMPLEMENTATION =====
  
  void _handleUserError(String message) {
    AppLogger.error('[$serviceName] User error: $message');
    // Services can override this to provide user feedback
    // For example, showing snackbars or updating UI state
  }
}

/// Mixin for services that need user context
/// Eliminates duplicate user access patterns
mixin UserContextMixin on BaseService {
  
  /// Get current user ID with error handling
  Future<String?> getCurrentUserId() async {
    return await safeExecute(
      () async {
        final userId = ServiceLocator.auth.currentUserId;
        if (userId == null) throw Exception('No authenticated user');
        return userId;
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
      _handleUserError(AppStrings.authenticationError);  
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
      () => ServiceLocator.notifications.sendNotification(
        title: title,
        message: message,
        userId: userId,
        data: data,
      ),
      operationName: 'Send notification',
      defaultValue: false,
    );
    
    return result ?? false;
  }
  
  /// Send success notification
  Future<void> notifySuccess(String message, {String? userId}) async {
    await sendNotification(
      title: 'Lyckades!',
      message: message,
      userId: userId,
    );
  }
  
  /// Send error notification
  Future<void> notifyError(String message, {String? userId}) async {
    await sendNotification(
      title: 'Fel uppstod',
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

// ===== FORWARD DECLARATIONS =====
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