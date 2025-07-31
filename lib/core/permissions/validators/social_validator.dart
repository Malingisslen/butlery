// lib/core/permissions/validators/social_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

/// Specialized permission validator for social features and user interactions.
///
/// This validator handles all social-specific permission validation including friend
/// requests, user blocking, profile management, and social interaction controls.
/// It manages the complex relationships between users and ensures proper privacy
/// and security boundaries in social contexts.
///
/// **Key Validation Areas:**
/// - **Friend Management**: Validates friend requests, removals, and relationship changes
/// - **User Blocking**: Manages blocking/unblocking permissions and privacy controls
/// - **Profile Access**: Ensures proper profile viewing and editing permissions
/// - **Social Interactions**: Validates messaging, commenting, and interaction permissions
/// - **Privacy Controls**: Manages visibility and access control for social features
///
/// **Social Relationship States:**
/// - **Friends**: Mutual connection allowing enhanced social features
/// - **Blocked**: Restricted relationship preventing all social interactions
/// - **Pending**: Friend request sent but not yet accepted/rejected
/// - **Stranger**: No established relationship, limited interaction permissions
/// - **Self**: Special case with full profile control but restricted self-interactions
///
/// **Privacy & Security Features:**
/// Social features require careful permission management to protect user privacy
/// and prevent harassment. This validator ensures that all social operations
/// respect user preferences, blocking relationships, and privacy settings.
///
/// **Usage Examples:**
/// ```dart
/// final validator = SocialPermissionValidator();
/// 
/// // Validate friend request before sending
/// final friendResult = validator.validateFriendRequest(targetUserId);
/// if (friendResult.isValid) {
///   sendFriendRequest();
/// }
/// 
/// // Validate profile editing access
/// final profileResult = validator.validateProfileEdit(userId);
/// if (profileResult.isValid) {
///   showProfileEditor();
/// }
/// ```
class SocialPermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
  /// Validates that the current user can send a friend request to the target user.
  ///
  /// Performs comprehensive validation for friend request operations including:
  /// - User is not sending request to themselves
  /// - Target user exists and is accessible
  /// - No existing friend relationship or pending request
  /// - Target user is not blocked or blocking the sender
  /// - All privacy settings allow friend requests
  ///
  /// [targetUserId] The unique identifier of the user to send a friend request to
  ///
  /// Returns [PermissionValidationResult.success] if friend request is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the request
  /// cannot be sent due to relationship constraints or privacy settings.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateFriendRequest('user123');
  /// if (result.isValid) {
  ///   sendFriendRequestToUser();
  /// } else {
  ///   showError(result.errorMessage);
  /// }
  /// ```
  PermissionValidationResult validateFriendRequest(String targetUserId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canSendFriendRequest(targetUserId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'användare',
        action: 'skicka vänförfrågan till',
      );
    }
    
    // Note: Friend status check is already handled in canSendFriendRequest
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can remove a friend from their friend list.
  ///
  /// Verifies that the user has the necessary permissions to remove the friendship
  /// relationship. This includes validating that a friendship actually exists and
  /// that the user is not attempting to remove themselves from their own friend list.
  ///
  /// Friend removal is typically available to both parties in a friendship and
  /// results in the termination of the mutual friendship relationship.
  ///
  /// [friendId] The unique identifier of the friend to be removed
  ///
  /// Returns [PermissionValidationResult.success] if friend removal is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the removal
  /// operation is not permitted.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateFriendRemoval('friend123');
  /// if (result.isValid) {
  ///   showRemoveFriendConfirmation();
  /// }
  /// ```
  PermissionValidationResult validateFriendRemoval(String friendId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isAuthenticated || friendId == _permissionService.currentUserId) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'vän',
        action: 'ta bort',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can block the specified user.
  ///
  /// Verifies that the blocking operation is valid and enforces business rules
  /// such as preventing users from blocking themselves. User blocking is a
  /// privacy control that prevents all social interactions between the users
  /// and may affect visibility of content and profiles.
  ///
  /// Blocking operations typically result in:
  /// - Termination of any existing friendship
  /// - Prevention of future friend requests
  /// - Hidden profiles and content
  /// - Blocked messaging and interactions
  ///
  /// [userId] The unique identifier of the user to be blocked
  ///
  /// Returns [PermissionValidationResult.success] if blocking is allowed,
  /// or an appropriate failure result if blocking constraints prevent the operation.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateUserBlocking('user123');
  /// if (result.isValid) {
  ///   showBlockUserConfirmation();
  /// }
  /// ```
  PermissionValidationResult validateUserBlocking(String userId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (userId == _permissionService.currentUserId) {
      return PermissionValidationResult.failure(
        errorMessage: 'Du kan inte blockera dig själv',
        errorCode: 'CANNOT_BLOCK_SELF',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can edit the specified user profile.
  ///
  /// Verifies that the user has sufficient permissions to modify the profile,
  /// which typically means they are editing their own profile. Profile editing
  /// permissions are generally restricted to the profile owner to maintain
  /// privacy and prevent unauthorized modifications.
  ///
  /// Profile editing may include modifying personal information, privacy settings,
  /// profile pictures, and other user-specific data that requires ownership validation.
  ///
  /// [userId] The unique identifier of the user profile to validate edit access for
  ///
  /// Returns [PermissionValidationResult.success] if profile editing is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// lacks the necessary permissions to edit the profile.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateProfileEdit(userId);
  /// if (result.isValid) {
  ///   navigateToProfileEditor();
  /// }
  /// ```
  PermissionValidationResult validateProfileEdit(String userId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canEditProfile(userId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'profil',
        action: 'redigera',
      );
    }
    
    return PermissionValidationResult.success();
  }
}