import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

/// Handles collaborative shopping list lifecycle operations (create, convert, query).
class ListLifecycleOperations {
  final UnifiedShoppingService _parent;

  ListLifecycleOperations(this._parent);

  Future<String?> createList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    return await _parent.createCollaborativeList(
      name: name,
      description: description,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      items: items,
      categoryIds: categoryIds,
      allowGuestEditing: allowGuestEditing,
      autoRemoveCompleted: autoRemoveCompleted,
    );
  }

  List<UnifiedShoppingList> getAllLists() {
    return _parent.collaborativeLists;
  }

  UnifiedShoppingList? getListById(String id) {
    try {
      return _parent.collaborativeLists.firstWhere((list) => list.id == id);
    } catch (e) {
      return null;
    }
  }

  List<UnifiedShoppingList> getOwnedLists() {
    final permissionService = ServiceLocator.get<PermissionService>();
    if (!permissionService.isAuthenticated) return [];

    return _parent.collaborativeLists
        .where((list) => permissionService.isShoppingListOwner(list.id))
        .toList();
  }

  List<UnifiedShoppingList> getSharedWithMe() {
    final permissionService = ServiceLocator.get<PermissionService>();
    if (!permissionService.isAuthenticated) return [];

    return _parent.collaborativeLists
        .where((list) =>
            !permissionService.isShoppingListOwner(list.id) &&
            permissionService.canViewShoppingList(list.id))
        .toList();
  }

  Future<String?> convertPersonalToCollaborative({
    required String personalListId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? description,
  }) async {
    UnifiedShoppingList? personalList;
    try {
      personalList =
          _parent.personalLists.firstWhere((list) => list.id == personalListId);
    } catch (e) {
      AppLogger.error('Cannot convert: Personal list not found');
      return null;
    }

    final collaborativeId = await createList(
      name: personalList.name,
      description: description ?? personalList.description,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      items: personalList.items,
    );

    if (collaborativeId != null) {
      await _parent.deleteList(personalListId);
    }

    return collaborativeId;
  }

  Future<String?> convertCollaborativeToPersonal(
      String collaborativeListId) async {
    final collaborativeList = getListById(collaborativeListId);
    if (collaborativeList == null) {
      AppLogger.error('Cannot convert: Collaborative list not found');
      return null;
    }

    if (!ServiceLocator.get<PermissionService>()
        .isShoppingListOwner(collaborativeList.id)) {
      AppLogger.error('Cannot convert: Only owner can convert to personal');
      return null;
    }

    final personalId = await _parent.createPersonalList(
      collaborativeList.name,
      items: collaborativeList.items,
    );

    if (personalId != null) {
      await _parent.deleteList(collaborativeListId);
    }

    return personalId;
  }
}
