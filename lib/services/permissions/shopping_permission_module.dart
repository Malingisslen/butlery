// lib/services/permissions/shopping_permission_module.dart

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

/// Module handling shopping list permission checks and ownership validation.
/// Provides comprehensive permission validation for shopping list access, editing, and collaboration.
class ShoppingPermissionModule {
  final UnifiedShoppingService shoppingService;
  final String? Function() getCurrentUserId;

  ShoppingPermissionModule({
    required this.shoppingService,
    required this.getCurrentUserId,
  });

  /// Validates whether the current user is the owner of a specific shopping list.
  /// Returns `true` if current user owns the shopping list, `false` otherwise
  bool isShoppingListOwner(String listId) {
    // Security: Must be authenticated to own shopping lists
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    try {
      // SECURITY FIX: Get actual shopping list from Firebase data
      final list = shoppingService.lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw StateError('List not found'),
      );

      // Check ownership against actual Firebase data
      return list.ownerId == currentUserId;
    } catch (e) {
      // If list not found or error occurs, deny access (secure default)
      return false;
    }
  }

  /// Validates user permission to view and access a specific shopping list.
  /// Returns `true` if user can view the shopping list, `false` otherwise
  bool canViewShoppingList(String listId) {
    // Security: Must be authenticated to view shopping lists
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    try {
      // SECURITY FIX: Get actual shopping list from Firebase data
      final list = shoppingService.lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw StateError('List not found'),
      );

      // Check ownership first
      if (list.ownerId == currentUserId) return true;

      // For collaborative lists, check member permissions
      if (list.type == ListType.collaborative) {
        final userPermission = list.memberPermissions[currentUserId];
        return userPermission != null; // Any permission level allows viewing
      }

      // For personal lists, only owner can view
      return false;
    } catch (e) {
      // If list not found or error occurs, deny access (secure default)
      return false;
    }
  }

  /// Validates user permission to edit and modify items in a specific shopping list.
  /// Returns `true` if user can edit the shopping list, `false` otherwise
  bool canEditShoppingList(String listId) {
    // Security: Must be authenticated to edit shopping lists
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) {
      return false;
    }

    // Security: Validate list ID
    if (listId.isEmpty) {
      return false;
    }

    try {
      // SECURITY FIX: Get actual shopping list from Firebase data
      final list = shoppingService.lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw StateError('List not found'),
      );

      // Check ownership first - owners can always edit
      if (list.ownerId == currentUserId) {
        return true;
      }

      // For collaborative lists, check member permissions
      if (list.type == ListType.collaborative) {
        final userPermission = list.memberPermissions[currentUserId];

        // Only admin and edit permissions allow editing
        final canEdit =
            userPermission == SharedListPermission.admin ||
            userPermission == SharedListPermission.edit;

        return canEdit;
      }

      // For personal lists, only owner can edit
      return false;
    } catch (e) {
      // If list not found or error occurs, deny access (secure default)
      return false;
    }
  }

  /// Add retry logic for permission checking with service refresh
  Future<bool> canEditShoppingListWithRetry(
    String listId, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final result = canEditShoppingList(listId);
      if (result) {
        return true;
      }

      if (attempt < maxRetries) {
        // Refresh shopping service data
        await shoppingService.loadLists();

        // Wait a bit for data to propagate
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      }
    }

    return false;
  }

  /// Validates user permission to manage sharing and collaboration settings for a shopping list.
  /// Returns `true` if user can manage the shopping list, `false` otherwise
  bool canManageShoppingList(String listId) {
    // Security: Must be authenticated to manage shopping lists
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    try {
      // SECURITY FIX: Get actual shopping list from Firebase data
      final list = shoppingService.lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw StateError('List not found'),
      );

      // Check ownership first - owners can always manage
      if (list.ownerId == currentUserId) return true;

      // For collaborative lists, only admin permissions allow management
      if (list.type == ListType.collaborative) {
        final userPermission = list.memberPermissions[currentUserId];
        return userPermission == SharedListPermission.admin;
      }

      // For personal lists, only owner can manage
      return false;
    } catch (e) {
      // If list not found or error occurs, deny access (secure default)
      return false;
    }
  }

  /// Validates user permission to permanently delete a specific shopping list.
  /// Returns `true` if user can delete the shopping list, `false` otherwise
  bool canDeleteShoppingList(String listId) {
    // Security: Must be authenticated to delete shopping lists
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    // Only owners can delete shopping lists
    return isShoppingListOwner(listId);
  }

  /// Validates user permission to send shopping list invitations.
  /// Returns `true` if user can send invitations for this list, `false` otherwise
  bool canSendShoppingInvitation(String listId) {
    // Security: Must be authenticated to send invitations
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    // Use the existing management permission check (owners and admins can invite)
    return canManageShoppingList(listId);
  }

  /// Validates user permission to accept/decline shopping list invitations.
  /// Returns `true` if current user can respond to this invitation, `false` otherwise
  bool canRespondToShoppingInvitation(String invitationRecipientId) {
    // Security: Must be authenticated to respond to invitations
    final currentUserId = getCurrentUserId();
    if (currentUserId == null) return false;

    // Security: Validate recipient ID
    if (invitationRecipientId.isEmpty) return false;

    // Only the intended recipient can respond to invitations
    return currentUserId == invitationRecipientId;
  }
}
