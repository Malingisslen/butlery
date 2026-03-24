import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';

/// Handles collaborative shopping list member operations (add, remove, permissions).
class ListMemberOperations {
  final String? Function() _getCurrentUserId;
  final Future<bool> Function(UnifiedShoppingList list) _updateList;
  final ListLifecycleOperations _lifecycleOps;

  ListMemberOperations({
    required String? Function() getCurrentUserId,
    required Future<bool> Function(UnifiedShoppingList list) updateList,
    required ListLifecycleOperations lifecycleOps,
  })  : _getCurrentUserId = getCurrentUserId,
        _updateList = updateList,
        _lifecycleOps = lifecycleOps;

  Future<bool> addMember({
    required String listId,
    required String userId,
    required String userDisplayName,
    SharedListPermission permission = SharedListPermission.edit,
  }) async {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot add member: Collaborative list not found');
      return false;
    }

    if (!canManageMembers(listId)) {
      AppLogger.error('Cannot add member: No permission to manage members');
      return false;
    }

    if (list.memberPermissions.containsKey(userId)) {
      AppLogger.warning('User is already a member of this list');
      return false;
    }

    try {
      final updatedPermissions = {
        ...list.memberPermissions,
        userId: permission,
      };

      final updatedList = list.copyWith(
        memberPermissions: updatedPermissions,
        updatedAt: DateTime.now(),
      );

      await _updateList(updatedList);

      AppLogger.success(
          'Added member ${userDisplayName.maskedName} to ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to add member', e);
      return false;
    }
  }

  Future<bool> removeMember({
    required String listId,
    required String userId,
  }) async {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot remove member: Collaborative list not found');
      return false;
    }

    final isRemovingSelf = _getCurrentUserId() == userId;
    if (!isRemovingSelf && !canManageMembers(listId)) {
      AppLogger.error('Cannot remove member: No permission to manage members');
      return false;
    }

    if (ServiceLocator.get<PermissionService>().isShoppingListOwner(listId) &&
        ServiceLocator.get<PermissionService>().currentUserId == userId) {
      AppLogger.error('Cannot remove owner from list');
      return false;
    }

    try {
      final updatedPermissions =
          Map<String, SharedListPermission>.from(list.memberPermissions);
      updatedPermissions.remove(userId);

      final updatedList = list.copyWith(
        memberPermissions: updatedPermissions,
        updatedAt: DateTime.now(),
      );

      await _updateList(updatedList);

      AppLogger.success('Removed member from ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove member', e);
      return false;
    }
  }

  Future<bool> updateMemberPermission({
    required String listId,
    required String userId,
    required SharedListPermission permission,
  }) async {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot update permission: Collaborative list not found');
      return false;
    }

    if (!canManageMembers(listId)) {
      AppLogger.error(
          'Cannot update permission: No permission to manage members');
      return false;
    }

    if (ServiceLocator.get<PermissionService>().isShoppingListOwner(listId) &&
        ServiceLocator.get<PermissionService>().currentUserId == userId) {
      AppLogger.error('Cannot change owner permission');
      return false;
    }

    try {
      final updatedPermissions = {
        ...list.memberPermissions,
        userId: permission,
      };

      final updatedList = list.copyWith(
        memberPermissions: updatedPermissions,
        updatedAt: DateTime.now(),
      );

      await _updateList(updatedList);

      AppLogger.success('Updated member permission in ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update member permission', e);
      return false;
    }
  }

  Map<String, SharedListPermission> getListMembers(String listId) {
    final list = _lifecycleOps.getListById(listId);
    return list?.memberPermissions ?? {};
  }

  Future<bool> leaveList(String listId) async {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot leave: Collaborative list not found');
      return false;
    }

    if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
      AppLogger.error('Cannot leave: User not authenticated');
      return false;
    }

    if (ServiceLocator.get<PermissionService>().isShoppingListOwner(listId)) {
      AppLogger.error(
          'Owner cannot leave list. Transfer ownership or delete list.');
      return false;
    }

    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot leave list: User not authenticated');
      return false;
    }

    return await removeMember(
      listId: listId,
      userId: currentUserId,
    );
  }

  bool canManageMembers(String listId) {
    return ServiceLocator.get<PermissionService>()
        .canManageShoppingList(listId);
  }
}
