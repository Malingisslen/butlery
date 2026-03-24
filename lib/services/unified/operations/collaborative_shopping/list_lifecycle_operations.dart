import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Handles collaborative shopping list lifecycle operations (create, convert, query).
class ListLifecycleOperations {
  final List<UnifiedShoppingList> Function() _getCollaborativeLists;
  final List<UnifiedShoppingList> Function() _getPersonalLists;
  final Future<String?> Function({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing,
    bool autoRemoveCompleted,
  }) _createCollaborativeList;
  final Future<bool> Function(String listId) _deleteList;
  final Future<String?> Function(String name,
      {List<UnifiedShoppingItem>? items}) _createPersonalList;

  ListLifecycleOperations({
    required List<UnifiedShoppingList> Function() getCollaborativeLists,
    required List<UnifiedShoppingList> Function() getPersonalLists,
    required Future<String?> Function({
      required String name,
      String? description,
      required List<String> memberIds,
      required Map<String, String> memberDisplayNames,
      List<UnifiedShoppingItem>? items,
      List<String>? categoryIds,
      bool allowGuestEditing,
      bool autoRemoveCompleted,
    }) createCollaborativeList,
    required Future<bool> Function(String listId) deleteList,
    required Future<String?> Function(String name,
            {List<UnifiedShoppingItem>? items})
        createPersonalList,
  })  : _getCollaborativeLists = getCollaborativeLists,
        _getPersonalLists = getPersonalLists,
        _createCollaborativeList = createCollaborativeList,
        _deleteList = deleteList,
        _createPersonalList = createPersonalList;

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
    return await _createCollaborativeList(
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
    return _getCollaborativeLists();
  }

  UnifiedShoppingList? getListById(String id) {
    try {
      return _getCollaborativeLists().firstWhere((list) => list.id == id);
    } catch (e) {
      return null;
    }
  }

  List<UnifiedShoppingList> getOwnedLists() {
    final permissionService = ServiceLocator.get<PermissionService>();
    if (!permissionService.isAuthenticated) return [];

    return _getCollaborativeLists()
        .where((list) => permissionService.isShoppingListOwner(list.id))
        .toList();
  }

  List<UnifiedShoppingList> getSharedWithMe() {
    final permissionService = ServiceLocator.get<PermissionService>();
    if (!permissionService.isAuthenticated) return [];

    return _getCollaborativeLists()
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
          _getPersonalLists().firstWhere((list) => list.id == personalListId);
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
      await _deleteList(personalListId);
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

    final personalId = await _createPersonalList(
      collaborativeList.name,
      items: collaborativeList.items,
    );

    if (personalId != null) {
      await _deleteList(collaborativeListId);
    }

    return personalId;
  }
}
