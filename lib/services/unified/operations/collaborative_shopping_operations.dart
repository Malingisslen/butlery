import 'package:butlery/models/unified/unified_shopping_item.dart'; // ShoppingCategory + UnifiedShoppingItem
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_member_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_item_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_activity_operations.dart';

/// Facade for collaborative shopping operations, delegates to focused modules following Single Responsibility Principle.
class CollaborativeShoppingOperations {
  late final ListLifecycleOperations lifecycle;
  late final ListMemberOperations members;
  late final ListItemOperations items;
  late final ListActivityOperations activity;

  CollaborativeShoppingOperations({
    required ListLifecycleOperations lifecycleOps,
    required ListMemberOperations memberOps,
    required ListItemOperations itemOps,
    required ListActivityOperations activityOps,
  }) {
    lifecycle = lifecycleOps;
    members = memberOps;
    items = itemOps;
    activity = activityOps;
  }

  // Lifecycle delegation
  Future<String?> createList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) => lifecycle.createList(
    name: name,
    description: description,
    memberIds: memberIds,
    memberDisplayNames: memberDisplayNames,
    items: items,
    categoryIds: categoryIds,
    allowGuestEditing: allowGuestEditing,
    autoRemoveCompleted: autoRemoveCompleted,
  );

  List<UnifiedShoppingList> getAllLists() => lifecycle.getAllLists();
  UnifiedShoppingList? getListById(String id) => lifecycle.getListById(id);
  List<UnifiedShoppingList> getOwnedLists() => lifecycle.getOwnedLists();
  List<UnifiedShoppingList> getSharedWithMe() => lifecycle.getSharedWithMe();
  Future<String?> convertPersonalToCollaborative({
    required String personalListId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? description,
  }) => lifecycle.convertPersonalToCollaborative(
    personalListId: personalListId,
    memberIds: memberIds,
    memberDisplayNames: memberDisplayNames,
    description: description,
  );
  Future<String?> convertCollaborativeToPersonal(String collaborativeListId) =>
      lifecycle.convertCollaborativeToPersonal(collaborativeListId);

  // Member delegation
  Future<bool> addMember({
    required String listId,
    required String userId,
    required String userDisplayName,
    SharedListPermission permission = SharedListPermission.edit,
  }) => members.addMember(
    listId: listId,
    userId: userId,
    userDisplayName: userDisplayName,
    permission: permission,
  );
  Future<bool> removeMember({
    required String listId,
    required String userId,
  }) => members.removeMember(listId: listId, userId: userId);
  Future<bool> updateMemberPermission({
    required String listId,
    required String userId,
    required SharedListPermission permission,
  }) => members.updateMemberPermission(
    listId: listId,
    userId: userId,
    permission: permission,
  );
  Map<String, SharedListPermission> getListMembers(String listId) =>
      members.getListMembers(listId);
  Future<bool> leaveList(String listId) => members.leaveList(listId);
  bool canManageMembers(String listId) => members.canManageMembers(listId);

  // Item delegation
  Future<bool> addItem({
    required String listId,
    required String name,
    required double amount,
    String unit = '',
    String category = ShoppingCategory.other,
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) => items.addItem(
    listId: listId,
    name: name,
    amount: amount,
    unit: unit,
    category: category,
    note: note,
    estimatedPrice: estimatedPrice,
    priority: priority,
  );
  Future<bool> toggleItemBought({
    required String listId,
    required String itemId,
  }) => items.toggleItemBought(listId: listId, itemId: itemId);
  Future<bool> removeItem({
    required String listId,
    required String itemId,
  }) => items.removeItem(listId: listId, itemId: itemId);

  // Activity delegation
  List<Map<String, dynamic>> getRecentActivity(String listId) =>
      activity.getRecentActivity(listId);
  Map<String, dynamic> getListStats(String listId) =>
      activity.getListStats(listId);
  bool canEdit(String listId) => activity.canEdit(listId);
  bool canView(String listId) => activity.canView(listId);
  bool canDelete(String listId) => activity.canDelete(listId);
  SharedListPermission? getUserPermission(String listId) =>
      activity.getUserPermission(listId);
  int getNotificationCount() => activity.getNotificationCount();
  Future<bool> markListAsSeen(String listId) => activity.markListAsSeen(listId);
}
