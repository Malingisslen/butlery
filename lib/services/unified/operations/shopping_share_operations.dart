// lib/services/unified/operations/shopping_share_operations.dart

/// Shopping share operations - Refactored with Single Responsibility Principle
/// 
/// This class now serves as a clean coordinator that delegates to focused modules.
/// Each operation type has been separated into its own module with single responsibility:
/// 
/// - ShoppingExportModule: Export operations (text, CSV, JSON)
/// - ShoppingExternalShareModule: External sharing and public links
/// - ShoppingTemplateModule: Template save/load operations
/// - ShoppingImportModule: Import from text/JSON
/// - ShoppingSocialShareModule: Social sharing and collaboration
/// 
/// Shared utilities have been extracted to reduce code duplication.

import 'package:butlery/services/unified/operations/shopping_share/shopping_export_module.dart';
import 'package:butlery/services/unified/operations/shopping_share/shopping_external_share_module.dart';
import 'package:butlery/services/unified/operations/shopping_share/shopping_template_module.dart';
import 'package:butlery/services/unified/operations/shopping_share/shopping_import_module.dart';
import 'package:butlery/services/unified/operations/shopping_share/shopping_social_share_module.dart';

/// Shopping share operations feature interface - Clean coordinator
/// 
/// Provides a unified API for all shopping list sharing operations while
/// delegating to focused, single-responsibility modules.
class ShoppingShareOperations {
  final dynamic _parent; // UnifiedShoppingService

  // Focused modules
  late final ShoppingExportModule _exportModule;
  late final ShoppingExternalShareModule _externalShareModule;
  late final ShoppingTemplateModule _templateModule;
  late final ShoppingImportModule _importModule;
  late final ShoppingSocialShareModule _socialShareModule;

  ShoppingShareOperations(this._parent) {
    _initializeModules();
  }

  /// Initialize all focused modules
  void _initializeModules() {
    _exportModule = ShoppingExportModule(_parent);
    _externalShareModule = ShoppingExternalShareModule(_parent);
    _templateModule = ShoppingTemplateModule(_parent);
    _importModule = ShoppingImportModule(_parent);
    _socialShareModule = ShoppingSocialShareModule(_parent);
  }

  // ===== EXPORT OPERATIONS (DELEGATE TO EXPORT MODULE) =====

  /// Export shopping list as formatted text
  String exportListAsText(String listId) => _exportModule.exportListAsText(listId);

  /// Export shopping list as minimal text (for SMS/messaging)
  String exportListAsMinimalText(String listId) => _exportModule.exportListAsMinimalText(listId);

  /// Export shopping list as structured JSON
  Map<String, dynamic> exportListAsJson(String listId) => _exportModule.exportListAsJson(listId);

  /// Export shopping list as CSV
  String exportListAsCSV(String listId) => _exportModule.exportListAsCSV(listId);

  // ===== EXTERNAL SHARING OPERATIONS (DELEGATE TO EXTERNAL SHARE MODULE) =====

  /// Share shopping list via external apps
  Future<bool> shareList({
    required String listId,
    String format = 'text',
    String? customMessage,
  }) => _externalShareModule.shareList(
    listId: listId,
    format: format,
    customMessage: customMessage,
  );

  /// Create public link for shopping list
  Future<String?> createPublicLink(String listId) => _externalShareModule.createPublicLink(listId);

  // ===== TEMPLATE OPERATIONS (DELEGATE TO TEMPLATE MODULE) =====

  /// Save shopping list as template
  Future<bool> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
  }) => _templateModule.saveAsTemplate(
    listId: listId,
    templateName: templateName,
    description: description,
  );

  /// Create shopping list from template
  Future<String?> createFromTemplate({
    required String templateId,
    String? customName,
  }) => _templateModule.createFromTemplate(
    templateId: templateId,
    customName: customName,
  );

  // ===== IMPORT OPERATIONS (DELEGATE TO IMPORT MODULE) =====

  /// Import shopping list from text
  Future<String?> importFromText({
    required String text,
    String? listName,
  }) => _importModule.importFromText(
    text: text,
    listName: listName,
  );

  /// Import shopping list from JSON
  Future<String?> importFromJson(Map<String, dynamic> jsonData) => 
      _importModule.importFromJson(jsonData);

  // ===== SOCIAL SHARING OPERATIONS (DELEGATE TO SOCIAL SHARE MODULE) =====

  /// Share shopping list with specific friends
  Future<bool> shareWithFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) => _socialShareModule.shareWithFriends(
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
  }) => _socialShareModule.shareListWithMultipleFriends(
    listId: listId,
    friendIds: friendIds,
    message: message,
  );

  /// Share shopping list with specific groups
  Future<bool> shareWithGroups({
    required String listId,
    required List<String> groupIds,
    String? message,
  }) => _socialShareModule.shareWithGroups(
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
  }) => _socialShareModule.shareListWithMultipleGroups(
    listId: listId,
    groupIds: groupIds,
    message: message,
  );

  /// Send shopping list collaboration invitation
  Future<bool> sendCollaborationInvite({
    required String listId,
    required String recipientId,
    String? message,
  }) => _socialShareModule.sendCollaborationInvite(
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
  Future<Map<String, dynamic>> getShoppingListSharingStats() => 
      _socialShareModule.getShoppingListSharingStats();

  // ===== MODULE ACCESS (FOR ADVANCED USAGE) =====

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