// lib/services/permission/modules/auth_permission_engine.dart

import '../../auth_service.dart';
import '../../user_service.dart';
import '../../../models/user_profile.dart';

/// Focused module for authentication-based permissions
/// 
/// This module handles ONLY authentication and session validation:
/// - User authentication status checking
/// - Session validity verification
/// - User profile access
/// - Basic ownership validation
/// 
/// ❌ DOES NOT CONTAIN: Resource-specific permissions, caching, utilities
class AuthPermissionEngine {
  final AuthService _authService;
  final UserService _userService;

  AuthPermissionEngine(this._authService, this._userService);

  // ===== CORE AUTHENTICATION =====

  /// Check if user is authenticated
  bool get isAuthenticated => _authService.isAuthenticated;

  /// Get current user ID
  String? get currentUserId => _authService.currentUserId;

  /// Get current user profile
  UserProfile? get currentUser => _userService.currentUserProfile;

  /// Check if user is logged in and has valid session
  bool get hasValidSession => isAuthenticated && currentUserId != null;

  // ===== BASIC OWNERSHIP VALIDATION =====

  /// Check if current user owns a resource
  bool isOwner(String? resourceOwnerId) {
    if (!isAuthenticated || resourceOwnerId == null) return false;
    return currentUserId == resourceOwnerId;
  }

  /// Check if current user is member of a resource
  bool isMember(Map<String, dynamic>? memberPermissions) {
    if (!isAuthenticated || memberPermissions == null) return false;
    return memberPermissions.containsKey(currentUserId);
  }

  /// Check if current user has higher permission than another user
  bool hasHigherPermission(String resourceId, String otherUserId) {
    // Implementation depends on resource type - can be extended
    return isOwner(resourceId);
  }

  // ===== SESSION MANAGEMENT =====

  /// Check if session is expired
  bool get isSessionExpired => !hasValidSession && isAuthenticated;

  /// Validate user for operation
  bool validateUserForOperation() {
    return hasValidSession;
  }

  /// Get authentication context for logging
  Map<String, dynamic> getAuthContext() {
    return {
      'isAuthenticated': isAuthenticated,
      'hasValidSession': hasValidSession,
      'currentUserId': currentUserId,
      'userDisplayName': currentUser?.displayName,
    };
  }

  // ===== USER CONTEXT =====

  /// Check if user ID matches current user
  bool isCurrentUser(String userId) {
    return currentUserId == userId;
  }

  /// Check if user can perform authenticated actions
  bool canPerformAuthenticatedAction() {
    return isAuthenticated;
  }

  /// Get user information for permission checks
  Map<String, dynamic> getUserPermissionContext() {
    return {
      'userId': currentUserId,
      'isAuthenticated': isAuthenticated,
      'hasValidSession': hasValidSession,
      'profile': currentUser?.toJson(),
    };
  }

  // ===== ASYNC USER OPERATIONS =====

  /// Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      return await _userService.getUserProfile(userId);
    } catch (e) {
      return null;
    }
  }

  /// Validate user exists and is accessible
  Future<bool> validateUserExists(String userId) async {
    final profile = await getUserProfile(userId);
    return profile != null;
  }

  // ===== PERMISSION CONTEXT VALIDATION =====

  /// Validate permission context for operation
  bool validatePermissionContext({
    required bool requiresAuth,
    required bool requiresValidSession,
    String? requiredUserId,
  }) {
    if (requiresAuth && !isAuthenticated) return false;
    if (requiresValidSession && !hasValidSession) return false;
    if (requiredUserId != null && !isCurrentUser(requiredUserId)) return false;
    
    return true;
  }

  /// Get permission denial reason
  String getPermissionDenialReason() {
    if (!isAuthenticated) return 'User not authenticated';
    if (!hasValidSession) return 'Session expired';
    return 'Unknown permission denial';
  }

  // ===== AUTHENTICATION STATE =====

  /// Check authentication state for UI
  String getAuthenticationState() {
    if (!isAuthenticated) return 'unauthenticated';
    if (!hasValidSession) return 'session_expired';
    return 'authenticated';
  }

  /// Check if authentication is required for operation
  bool requiresAuthentication(String operation) {
    // Most operations require authentication
    const publicOperations = ['view_public_content', 'browse_public'];
    return !publicOperations.contains(operation);
  }
}