import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';

/// Handles collaborative shopping list activity tracking, stats, and notifications.
class ListActivityOperations {
  final ListLifecycleOperations _lifecycleOps;

  ListActivityOperations(this._lifecycleOps);

  List<Map<String, dynamic>> getRecentActivity(String listId) {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) return [];

    return [
      {
        'type': 'list_updated',
        'timestamp': list.updatedAt,
        'userId': list.lastActivityByUserId,
        'userName': list.lastActivityByDisplayName,
        'description': 'Lista uppdaterad',
      }
    ];
  }

  Map<String, dynamic> getListStats(String listId) {
    final list = _lifecycleOps.getListById(listId);
    if (list == null) return {};

    final totalItems = list.items.length;
    final boughtItems = list.items.where((item) => item.bought).length;
    final remainingItems = totalItems - boughtItems;

    final memberActivity = <String, int>{};
    for (final item in list.items) {
      if (item.addedByUserId != null) {
        memberActivity[item.addedByUserId!] =
            (memberActivity[item.addedByUserId!] ?? 0) + 1;
      }
    }

    return {
      'listId': listId,
      'listName': list.name,
      'totalItems': totalItems,
      'boughtItems': boughtItems,
      'remainingItems': remainingItems,
      'completionPercentage':
          totalItems > 0 ? (boughtItems / totalItems * 100).round() : 0,
      'memberCount': list.memberPermissions.length,
      'memberActivity': memberActivity,
      'lastActivity': list.updatedAt,
      'allowGuestEditing': list.allowGuestEditing,
      'autoRemoveCompleted': list.autoRemoveCompleted,
    };
  }

  bool canEdit(String listId) {
    return ServiceLocator.get<PermissionService>().canEditShoppingList(listId);
  }

  bool canView(String listId) {
    return ServiceLocator.get<PermissionService>().canViewShoppingList(listId);
  }

  bool canManageMembers(String listId) {
    return ServiceLocator.get<PermissionService>()
        .canManageShoppingList(listId);
  }

  bool canDelete(String listId) {
    return ServiceLocator.get<PermissionService>()
        .canDeleteShoppingList(listId);
  }

  SharedListPermission? getUserPermission(String listId) {
    final list = _lifecycleOps.getListById(listId);
    if (list == null ||
        !ServiceLocator.get<PermissionService>().isAuthenticated) {
      return null;
    }

    final permissionService = ServiceLocator.get<PermissionService>();

    if (permissionService.canManageShoppingList(listId)) {
      return SharedListPermission.admin;
    } else if (permissionService.canEditShoppingList(listId)) {
      return SharedListPermission.edit;
    } else if (permissionService.canViewShoppingList(listId)) {
      return SharedListPermission.view;
    }

    return null;
  }

  int getNotificationCount() {
    final recentThreshold = DateTime.now().subtract(const Duration(hours: 24));

    return _lifecycleOps
        .getAllLists()
        .where((list) => list.updatedAt.isAfter(recentThreshold))
        .length;
  }

  Future<bool> markListAsSeen(String listId) async {
    try {
      AppLogger.info('Marked list $listId as seen by user');
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark list as seen', e);
      return false;
    }
  }
}
