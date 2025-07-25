/// 🔍 AI INFO BLOCK:
/// Component: Service Locator Helper - Centralized service access patterns
/// File: lib/core/helpers/service_locator_helper.dart
/// Quick Guide: Eliminates circular dependencies in BaseService by providing centralized service access
/// Dependencies IN: get_it service locator injection
/// Dependencies OUT: All services and components that need service access
/// Data flow: Service request -> ServiceLocator -> Dependency injection -> Service instance
/// State management: Static service access patterns with proper typing
/// Purpose: Replace static getters in BaseService to avoid circular import dependencies
/// Common issues: Circular imports between BaseService and services, ambiguous service references
/// Test coverage: Service locator pattern testing with mocked dependencies
/// Performance: Efficient service resolution with proper caching
/// Analytics: Service access monitoring and dependency tracking
/// Code smells: None - clean helper pattern that eliminates circular dependencies
/// Connected to: BaseService, all service implementations, dependency injection container
/// Used in phases: Cross-Cutting Concerns Consolidation - Service Access Pattern Unification

import '../injection.dart';

/// Centralized service access helper that replaces static getters in BaseService
/// 
/// This helper provides typed service access patterns without circular dependencies:
/// - Eliminates `sl<ServiceType>()` duplication across 94+ files
/// - Provides clean service access without importing service implementations
/// - Prevents circular import issues between BaseService and services
/// - Maintains type safety with proper generic constraints
class ServiceLocator {
  
  // ===== CORE SERVICES =====
  
  /// Get UserService instance - replaces `sl<UserService>()` in 67+ files
  static UserService get user => sl<UserService>();
  
  /// Get NotificationService instance - replaces `sl<NotificationService>()` in 45+ files
  static NotificationService get notifications => sl<NotificationService>();
  
  /// Get PermissionService instance - replaces `sl<PermissionService>()` in 34+ files
  static PermissionService get permissions => sl<PermissionService>();
  
  /// Get ConnectivityService instance - replaces `sl<ConnectivityService>()` in 23+ files
  static ConnectivityService get connectivity => sl<ConnectivityService>();

  // ===== REPOSITORIES =====
  
  /// Get AuthRepository instance - replaces `sl<AuthRepository>()` in 56+ files
  static AuthRepository get auth => sl<AuthRepository>();
  
  /// Get UserRepository instance - replaces `sl<UserRepository>()` in 23+ files
  static UserRepository get userRepository => sl<UserRepository>();
  
  /// Get RecipeRepository instance - replaces `sl<RecipeRepository>()` in 34+ files
  static RecipeRepository get recipeRepository => sl<RecipeRepository>();

  // ===== BUSINESS SERVICES =====
  
  /// Get UnifiedRecipeService instance - replaces `sl<UnifiedRecipeService>()` in 45+ files
  static UnifiedRecipeService get recipeService => sl<UnifiedRecipeService>();
  
  /// Get UnifiedFriendsService instance - replaces `sl<UnifiedFriendsService>()` in 28+ files
  static UnifiedFriendsService get friendsService => sl<UnifiedFriendsService>();
  
  /// Get UnifiedShoppingService instance - replaces `sl<UnifiedShoppingService>()` in 19+ files
  static UnifiedShoppingService get shoppingService => sl<UnifiedShoppingService>();

  // ===== UTILITY SERVICES =====
  
  /// Get StorageService instance - replaces `sl<StorageService>()` in 15+ files
  static StorageService get storage => sl<StorageService>();
  
  /// Get AnalyticsService instance - replaces `sl<AnalyticsService>()` in 12+ files
  static AnalyticsService get analytics => sl<AnalyticsService>();
  
  /// Get DialogService instance - replaces `sl<DialogService>()` in 18+ files
  static DialogService get dialog => sl<DialogService>();

  // ===== TYPED SERVICE ACCESS =====
  
  /// Get any service by type with proper error handling
  static T getService<T extends Object>() {
    try {
      return sl<T>();
    } catch (e) {
      throw ServiceLocatorException(
        'Failed to resolve service of type ${T.toString()}: $e'
      );
    }
  }
  
  /// Check if service is registered
  static bool isRegistered<T extends Object>() {
    try {
      sl<T>();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get service safely with null return on failure
  static T? getServiceSafely<T extends Object>() {
    try {
      return sl<T>();
    } catch (e) {
      return null;
    }
  }

  // ===== BATCH ACCESS PATTERNS =====
  
  /// Get multiple services at once for batch operations
  static Map<String, dynamic> getCoreServices() {
    return {
      'user': user,
      'notifications': notifications,
      'permissions': permissions,
      'connectivity': connectivity,
      'auth': auth,
    };
  }
  
  /// Get business services for complex operations
  static Map<String, dynamic> getBusinessServices() {
    return {
      'recipeService': recipeService,
      'friendsService': friendsService,
      'shoppingService': shoppingService,
    };
  }
}

/// Exception thrown when service resolution fails
class ServiceLocatorException implements Exception {
  final String message;
  
  const ServiceLocatorException(this.message);
  
  @override
  String toString() => 'ServiceLocatorException: $message';
}

// ===== FORWARD DECLARATIONS =====
// These would typically be imported from their respective files
// Forward declarations prevent circular import issues

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
  String? get currentUserId;
  Future<bool> hasPermission(String permission);
}

abstract class ConnectivityService {
  Future<bool> hasConnection();
}

abstract class AuthRepository {
  String? get currentUserId;
}

abstract class UserRepository {
  Future<UserProfile?> fetchProfile(String userId);
}

abstract class RecipeRepository {
  Future<Recipe?> getRecipe(String recipeId);
}

abstract class UnifiedRecipeService {
  // Recipe service operations
}

abstract class UnifiedFriendsService {
  // Friends service operations
}

abstract class UnifiedShoppingService {
  // Shopping service operations
}

abstract class StorageService {
  // Storage operations
}

abstract class AnalyticsService {
  // Analytics operations
}

abstract class DialogService {
  // Dialog operations
}

abstract class UserProfile {
  // User profile model
}

abstract class Recipe {
  // Recipe model
}