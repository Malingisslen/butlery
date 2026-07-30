import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';
import 'package:clock/clock.dart';

/// Handles collaborative shopping list member operations (add, remove, permissions).
class ListMemberOperations {
  final String? Function() _getCurrentUserId;

  /// BUT-1726: membership does NOT go through the ordinary list update.
  ///
  /// That path takes a whole entity and cannot tell a deliberate ACL change
  /// from a stale member map riding along on a rename, so it writes no access
  /// control at all — every add, remove, permission change and leave persisted
  /// nothing while this class returned `true` and the dialog said it worked.
  /// This seam states the intent explicitly and carries the base the change was
  /// computed from, so the server can refuse a change computed against a list
  /// that has since moved instead of silently replaying it.
  final Future<bool> Function(
    UnifiedShoppingList updated,
    UnifiedShoppingList base,
  )
  _updateMembership;

  /// Clears any parked failure reason, so a caller reading
  /// `consumeMutationError()` after one of these operations can only ever see a
  /// reason describing THIS operation.
  ///
  /// Every early `return false` below (list gone, may not manage members,
  /// already a member, cannot remove the owner) exits before the service is
  /// reached, so without this the dialog reports whatever sentence an earlier,
  /// unrelated failure left behind — "du saknar behörighet att redigera denna
  /// delade inköpslista" shown as the cause of a member add. That is the exact
  /// wrong-cause class BUT-1696 exists to prevent.
  final void Function() _beginMutation;

  final ListLifecycleOperations _lifecycleOps;

  ListMemberOperations({
    required String? Function() getCurrentUserId,
    required Future<bool> Function(
      UnifiedShoppingList updated,
      UnifiedShoppingList base,
    )
    updateMembership,
    required void Function() beginMutation,
    required ListLifecycleOperations lifecycleOps,
  }) : _getCurrentUserId = getCurrentUserId,
       _updateMembership = updateMembership,
       _beginMutation = beginMutation,
       _lifecycleOps = lifecycleOps;

  Future<bool> addMember({
    required String listId,
    required String userId,
    required String userDisplayName,
    SharedListPermission permission = SharedListPermission.edit,
  }) async {
    _beginMutation();
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
        updatedAt: clock.now(),
      );

      // The write's own verdict, not an assumed one: returning `true` over a
      // refused write is what told an owner the member had been added.
      if (!await _updateMembership(updatedList, list)) {
        AppLogger.error('Add member rejected for ${list.name}');
        return false;
      }

      AppLogger.success(
        'Added member ${userDisplayName.maskedName} to ${list.name}',
      );
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
    _beginMutation();
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
      final updatedPermissions = Map<String, SharedListPermission>.from(
        list.memberPermissions,
      );
      updatedPermissions.remove(userId);

      final updatedList = list.copyWith(
        memberPermissions: updatedPermissions,
        updatedAt: clock.now(),
      );

      if (!await _updateMembership(updatedList, list)) {
        AppLogger.error('Remove member rejected for ${list.name}');
        return false;
      }

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
    _beginMutation();
    final list = _lifecycleOps.getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot update permission: Collaborative list not found');
      return false;
    }

    if (!canManageMembers(listId)) {
      AppLogger.error(
        'Cannot update permission: No permission to manage members',
      );
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
        updatedAt: clock.now(),
      );

      if (!await _updateMembership(updatedList, list)) {
        AppLogger.error('Permission change rejected for ${list.name}');
        return false;
      }

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
    _beginMutation();
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
        'Owner cannot leave list. Transfer ownership or delete list.',
      );
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
    return ServiceLocator.get<PermissionService>().canManageShoppingList(
      listId,
    );
  }
}
