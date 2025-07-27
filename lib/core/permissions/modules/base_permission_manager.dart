// lib/core/permissions/modules/base_permission_manager.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';

/// Focused module for base permission management
/// 
/// This module handles ONLY core authentication and user context:
/// - User authentication status
/// - Current user information
/// - Basic permission service access
/// - Session validation
/// 
/// ❌ DOES NOT CONTAIN: Resource-specific permissions, action builders, debug tools
class BasePermissionManager {

  // ===== PERMISSION SERVICE ACCESS =====

  /// Get permission service instance
  static PermissionService get permissionService => sl<PermissionService>();

  // ===== USER AUTHENTICATION =====

  /// Current authenticated user ID
  static String? get currentUserId => permissionService.currentUserId;

  /// Check if user is authenticated
  static bool get isAuthenticated => permissionService.isAuthenticated;

  /// Check if user is logged in with valid session
  static bool get isLoggedIn => permissionService.hasValidSession;

  /// Get current user display name
  static String? get currentUserDisplayName => permissionService.currentUser?.displayName;

  // ===== USER CONTEXT VALIDATION =====

  /// Check if user ID is current user
  static bool isCurrentUser(String userId) {
    return currentUserId == userId;
  }

  /// Check if user can perform authenticated actions
  static bool canPerformAuthenticatedAction() {
    return isAuthenticated;
  }

  /// Check if user can perform action on other users
  static bool canPerformActionOnOtherUser(String targetUserId) {
    return isAuthenticated && currentUserId != targetUserId;
  }

  /// Validate user session before operations
  static bool validateUserSession() {
    return isLoggedIn;
  }

  // ===== USER INFORMATION =====

  /// Get current user information summary
  static Map<String, dynamic> getCurrentUserInfo() {
    return {
      'userId': currentUserId,
      'displayName': currentUserDisplayName,
      'isAuthenticated': isAuthenticated,
      'hasValidSession': isLoggedIn,
    };
  }

  /// Check if user has required authentication level
  static bool hasRequiredAuthLevel({
    bool requireAuthentication = true,
    bool requireValidSession = false,
  }) {
    if (requireAuthentication && !isAuthenticated) return false;
    if (requireValidSession && !isLoggedIn) return false;
    return true;
  }

  // ===== SESSION HELPERS =====

  /// Get authentication status for UI display
  static String getAuthenticationStatus() {
    if (!isAuthenticated) return 'not_authenticated';
    if (!isLoggedIn) return 'session_expired';
    return 'authenticated';
  }

  /// Check if authentication is required for operation
  static bool isAuthenticationRequired() {
    return !isAuthenticated;
  }

  /// Check if session refresh is needed
  static bool needsSessionRefresh() {
    return isAuthenticated && !isLoggedIn;
  }

  // ===== PERMISSION CONTEXT =====

  /// Create permission context for operations
  static Map<String, dynamic> createPermissionContext() {
    return {
      'currentUserId': currentUserId,
      'isAuthenticated': isAuthenticated,
      'hasValidSession': isLoggedIn,
      'displayName': currentUserDisplayName,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Validate permission context
  static bool validatePermissionContext(Map<String, dynamic> context) {
    final userId = context['currentUserId'] as String?;
    final authenticated = context['isAuthenticated'] as bool? ?? false;
    
    return userId == currentUserId && authenticated == isAuthenticated;
  }

  // ===== AUTHORIZATION HELPERS =====

  /// Check if user is authorized for basic operations
  static bool isAuthorizedForBasicOperations() {
    return isAuthenticated && currentUserId != null;
  }

  /// Check if user is authorized for admin operations
  static bool isAuthorizedForAdminOperations() {
    // This would integrate with role-based permissions if implemented
    return isAuthenticated && currentUserId != null;
  }

  /// Get authorization level
  static String getAuthorizationLevel() {
    if (!isAuthenticated) return 'none';
    if (!isLoggedIn) return 'expired';
    return 'basic'; // Could be enhanced with roles
  }

  // ===== ERROR CONTEXT =====

  /// Get permission error context for debugging
  static Map<String, dynamic> getPermissionErrorContext() {
    return {
      'userId': currentUserId ?? 'none',
      'authenticated': isAuthenticated,
      'validSession': isLoggedIn,
      'displayName': currentUserDisplayName ?? 'none',
      'authStatus': getAuthenticationStatus(),
    };
  }

  /// Create permission denied message
  static String createPermissionDeniedMessage(String operation) {
    if (!isAuthenticated) {
      return 'Du måste logga in för att $operation';
    } else if (!isLoggedIn) {
      return 'Din session har upphört - logga in igen för att $operation';
    } else {
      return 'Du har inte behörighet att $operation';
    }
  }
}