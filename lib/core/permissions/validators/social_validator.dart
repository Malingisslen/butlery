// lib/core/permissions/validators/social_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

/// Social permission validator
class SocialPermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
  /// Validate friend request permissions
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
  
  /// Validate friend removal permissions
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
  
  /// Validate user blocking permissions
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
  
  /// Validate profile editing permissions
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