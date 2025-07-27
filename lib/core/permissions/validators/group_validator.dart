// lib/core/permissions/validators/group_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

/// Group permission validator
class GroupPermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
  /// Validate group creation permissions
  PermissionValidationResult validateGroupCreation() {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group editing permissions
  PermissionValidationResult validateGroupEdit(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'redigera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group management permissions
  PermissionValidationResult validateGroupManagement(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'hantera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group deletion permissions
  PermissionValidationResult validateGroupDeletion(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canDeleteGroup(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'ta bort',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group invitation permissions
  PermissionValidationResult validateGroupInvitation(String groupId, List<String> inviteeIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canInviteToGroup(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'bjuda in till',
      );
    }
    
    // Validate invitees
    for (final userId in inviteeIds) {
      if (!_permissionService.canViewProfile(userId)) {
        return PermissionValidationResult.failure(
          errorMessage: 'Du kan inte bjuda in en eller flera av de valda användarna',
          errorCode: 'INVALID_INVITEE',
        );
      }
      
      // Note: Check for existing membership could be implemented later
      // For now, we'll allow the invitation to be sent
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group member removal permissions
  PermissionValidationResult validateGroupMemberRemoval(String groupId, List<String> memberIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'ta bort medlemmar från',
      );
    }
    
    // Validate member removal permissions
    for (final userId in memberIds) {
      if (_permissionService.isGroupAdmin(groupId) && userId == _permissionService.currentUserId) {
        return PermissionValidationResult.failure(
          errorMessage: 'Gruppägaren kan inte ta bort sig själv',
          errorCode: 'CANNOT_REMOVE_OWNER',
        );
      }
    }
    
    return PermissionValidationResult.success();
  }
}