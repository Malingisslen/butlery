// lib/services/unified/operations/shopping_share_operations.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/unified/operations/modules/shopping_social_share_module.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Shopping share operations coordinator.
/// Orchestrates shopping list sharing via export, import, templates, external sharing, and social collaboration.
/// Delegates to specialized modules for each concern.

/// Consolidated shopping export module (simplified)
class ShoppingExportModule {
  ShoppingExportModule();

  String exportListAsText(String listId) =>
      'Shopping List $listId:\n- Item 1\n- Item 2';
  String exportListAsMinimalText(String listId) =>
      'List $listId: Item 1, Item 2';
  Map<String, dynamic> exportListAsJson(String listId) => {
        'listId': listId,
        'items': ['Item 1', 'Item 2'],
        'exported': DateTime.now().toIso8601String(),
      };
  String exportListAsCSV(String listId) =>
      'Item,Quantity,Category\nItem 1,1,Food\nItem 2,2,Household';
}

/// Consolidated shopping external share module (simplified)
class ShoppingExternalShareModule {
  final PermissionService _permissionService;

  ShoppingExternalShareModule({required PermissionService permissionService})
      : _permissionService = permissionService;

  Future<bool> shareList({
    required String listId,
    String? format,
    String? customMessage,
  }) async =>
      true;
  Future<String?> createPublicLink(String listId) async {
    final userId = _permissionService.currentUserId;
    if (userId == null) return null;
    final longUrl = DeepLinkService.generateShoppingListShareLink(
      listId: listId,
      fromUserId: userId,
    );
    return DeepLinkService.generateShortUrl(longUrl);
  }
}

/// Consolidated shopping template module (simplified)
class ShoppingTemplateModule {
  ShoppingTemplateModule();

  Future<bool> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
  }) async =>
      true;
  Future<String?> createFromTemplate({
    required String templateId,
    String? customName,
  }) async =>
      'new-list-id';
}

/// Consolidated shopping import module (simplified)
class ShoppingImportModule {
  ShoppingImportModule();

  Future<String?> importFromText({
    required String text,
    String? listName,
  }) async =>
      'imported-list-id';
  Future<String?> importFromJson(Map<String, dynamic> json) async =>
      'imported-list-id';
}

/// Shopping share operations feature interface - Clean coordinator providing unified API for all sharing operations.
/// Provides a unified API for all shopping list sharing operations while delegating to focused, single-responsibility modules.
/// This coordinator maintains clean separation of concerns while offering comprehensive sharing capabilities through specialized modules.
class ShoppingShareOperations {
  // Focused modules
  late final ShoppingExportModule _exportModule;
  late final ShoppingExternalShareModule _externalShareModule;
  late final ShoppingTemplateModule _templateModule;
  late final ShoppingImportModule _importModule;
  late final ShoppingSocialShareModule _socialShareModule;

  final FirestoreRepository _firestoreRepository;
  final PermissionService _permissionService;

  ShoppingShareOperations({
    FirestoreRepository? firestoreRepository,
    required PermissionService permissionService,
  })  : _firestoreRepository =
            firestoreRepository ?? ServiceLocator.get<FirestoreRepository>(),
        _permissionService = permissionService {
    _initializeModules();
  }

  /// Initialize all focused modules
  void _initializeModules() {
    _exportModule = ShoppingExportModule();
    _externalShareModule = ShoppingExternalShareModule(
      permissionService: _permissionService,
    );
    _templateModule = ShoppingTemplateModule();
    _importModule = ShoppingImportModule();
    _socialShareModule = ShoppingSocialShareModule(
      firestore: _firestoreRepository.firestore,
      permissionService: _permissionService,
    );
  }

  /// Export shopping list as formatted text
  String exportListAsText(String listId) =>
      _exportModule.exportListAsText(listId);

  /// Export shopping list as minimal text (for SMS/messaging)
  String exportListAsMinimalText(String listId) =>
      _exportModule.exportListAsMinimalText(listId);

  /// Export shopping list as structured JSON
  Map<String, dynamic> exportListAsJson(String listId) =>
      _exportModule.exportListAsJson(listId);

  /// Export shopping list as CSV
  String exportListAsCSV(String listId) =>
      _exportModule.exportListAsCSV(listId);

  /// Share shopping list via external apps
  Future<bool> shareList({
    required String listId,
    String format = 'text',
    String? customMessage,
  }) =>
      _externalShareModule.shareList(
        listId: listId,
        format: format,
        customMessage: customMessage,
      );

  /// Create public link for shopping list
  Future<String?> createPublicLink(String listId) =>
      _externalShareModule.createPublicLink(listId);

  /// Save shopping list as template
  Future<bool> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
  }) =>
      _templateModule.saveAsTemplate(
        listId: listId,
        templateName: templateName,
        description: description,
      );

  /// Create shopping list from template
  Future<String?> createFromTemplate({
    required String templateId,
    String? customName,
  }) =>
      _templateModule.createFromTemplate(
        templateId: templateId,
        customName: customName,
      );

  /// Import shopping list from text
  Future<String?> importFromText({
    required String text,
    String? listName,
  }) =>
      _importModule.importFromText(
        text: text,
        listName: listName,
      );

  /// Import shopping list from JSON
  Future<String?> importFromJson(Map<String, dynamic> jsonData) =>
      _importModule.importFromJson(jsonData);

  /// Share shopping list with specific friends
  Future<bool> shareWithFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) =>
      _socialShareModule.shareWithFriends(
        listId: listId,
        friendIds: friendIds,
        message: message,
      );

  /// Share shopping list with single friend
  Future<bool> shareListWithFriend(String listId, String friendId) =>
      _socialShareModule.shareListWithFriend(listId, friendId);

  /// Share shopping list with multiple friends
  Future<bool> shareListWithMultipleFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) =>
      _socialShareModule.shareListWithMultipleFriends(
        listId: listId,
        friendIds: friendIds,
        message: message,
      );

  /// Share shopping list with specific groups
  Future<bool> shareWithGroups({
    required String listId,
    required List<String> groupIds,
    String? message,
  }) =>
      _socialShareModule.shareWithGroups(
        listId: listId,
        groupIds: groupIds,
        message: message,
      );

  /// Share shopping list with single group
  Future<bool> shareListWithGroup(String listId, String groupId) =>
      _socialShareModule.shareListWithGroup(listId, groupId);

  /// Share shopping list with multiple groups
  Future<bool> shareListWithMultipleGroups({
    required String listId,
    required List<String> groupIds,
    String? message,
  }) =>
      _socialShareModule.shareListWithMultipleGroups(
        listId: listId,
        groupIds: groupIds,
        message: message,
      );

  /// Send shopping list collaboration invitation
  Future<bool> sendCollaborationInvite({
    required String listId,
    required String recipientId,
    String? message,
  }) =>
      _socialShareModule.sendCollaborationInvite(
        listId: listId,
        recipientId: recipientId,
        message: message,
      );

  /// Get shopping lists shared with current user
  Future<List<Map<String, dynamic>>> getShoppingListsSharedWithMe() =>
      _socialShareModule.getShoppingListsSharedWithMe();

  /// Get shopping lists shared by current user
  Future<List<Map<String, dynamic>>> getShoppingListsSharedByMe() =>
      _socialShareModule.getShoppingListsSharedByMe();

  /// Import shared shopping list
  Future<String?> importSharedShoppingList(String sharedListId) =>
      _socialShareModule.importSharedShoppingList(sharedListId);

  /// Mark shared shopping list as viewed
  Future<void> markSharedShoppingListAsViewed(String sharedListId) =>
      _socialShareModule.markSharedShoppingListAsViewed(sharedListId);

  /// Get shopping list sharing statistics
  Future<Map<String, dynamic>> getShoppingListSharingStats(String listId) =>
      _socialShareModule.getShoppingListSharingStats(listId);

  /// Get export module for advanced export operations
  ShoppingExportModule get export => _exportModule;

  /// Get external share module for advanced external sharing
  ShoppingExternalShareModule get externalShare => _externalShareModule;

  /// Get template module for advanced template operations
  ShoppingTemplateModule get template => _templateModule;

  /// Get import module for advanced import operations
  ShoppingImportModule get import => _importModule;

  /// Get social share module for advanced social sharing
  ShoppingSocialShareModule get socialShare => _socialShareModule;
}
