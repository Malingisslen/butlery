import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Repository interface for shopping list data operations and template management.
///
/// This interface extends the base Repository pattern to provide specialized
/// shopping list operations including active list management, item operations,
/// and template functionality. It manages shopping list persistence, collaborative
/// features, and template-based list creation for efficient shopping workflows.
///
/// **Key Shopping Operations:**
/// - **List Management**: CRUD operations for shopping lists and active list tracking
/// - **Item Operations**: Add, remove, and modify shopping list items
/// - **Template System**: Save, manage, and create lists from reusable templates
/// - **Collaborative Features**: Multi-user shopping list support
/// - **Public Templates**: Community template sharing and discovery
/// - **Active List Tracking**: Single active list management for streamlined UX
///
/// **Template System Benefits:**
/// The template system allows users to create reusable shopping list patterns,
/// share common lists with the community, and quickly generate new lists from
/// proven templates. This reduces repetitive work and enables shopping efficiency.
///
/// **Collaborative Shopping:**
/// Shopping lists support real-time collaboration where multiple family members
/// or roommates can simultaneously add items, check off purchases, and coordinate
/// shopping activities across different locations and devices.
///
/// **Usage Examples:**
/// ```dart
/// final shoppingRepo = sl<ShoppingRepository>();
/// 
/// // Create and set active shopping list
/// final newList = UnifiedShoppingList(name: 'Weekly Groceries');
/// final createdList = await shoppingRepo.create(newList);
/// await shoppingRepo.setActiveList(createdList.id);
/// 
/// // Add items to active list
/// final activeList = await shoppingRepo.getActiveList();
/// if (activeList != null) {
///   await shoppingRepo.addItem(activeList.id, 
///     UnifiedShoppingItem(name: 'Milk', quantity: 1));
/// }
/// 
/// // Create list from template
/// final templates = await shoppingRepo.getPublicTemplates();
/// final weeklyTemplate = templates.first;
/// final listId = await shoppingRepo.createListFromTemplate(
///   templateId: weeklyTemplate['id'],
///   listName: 'My Weekly List',
/// );
/// ```
abstract class ShoppingRepository extends Repository<UnifiedShoppingList> {
  /// Sets the specified shopping list as the currently active list.
  ///
  /// Designates a shopping list as the "active" list for streamlined user experience.
  /// The active list is prominently displayed in the UI and serves as the default
  /// target for quick item additions and shopping activities.
  ///
  /// [listId] The unique identifier of the shopping list to make active
  ///
  /// Throws [ShoppingListNotFoundException] if the list doesn't exist
  /// Throws [StorageException] if the active list update fails
  ///
  /// **Active List Benefits:**
  /// - Quick access to primary shopping list
  /// - Streamlined item addition workflow
  /// - Default list for voice commands and shortcuts
  /// - Prominent display in shopping interface
  ///
  /// Example:
  /// ```dart
  /// final newList = await shoppingRepo.create(shoppingList);
  /// await shoppingRepo.setActiveList(newList.id);
  /// // List is now active and prominently displayed
  /// ```
  Future<void> setActiveList(String listId);

  /// Retrieves the currently active shopping list, if one is set.
  ///
  /// Returns the shopping list that has been designated as "active" for the
  /// current user. The active list provides quick access to the primary
  /// shopping list and enables streamlined shopping workflows.
  ///
  /// Returns the active [UnifiedShoppingList] or null if no list is active
  ///
  /// Throws [StorageException] if retrieval fails
  ///
  /// **Usage Patterns:**
  /// - Display primary shopping list in main interface
  /// - Default target for quick item additions
  /// - Shopping mode activation and navigation
  /// - Voice command and shortcut integration
  ///
  /// Example:
  /// ```dart
  /// final activeList = await shoppingRepo.getActiveList();
  /// if (activeList != null) {
  ///   displayActiveShoppingList(activeList);
  ///   enableQuickAddMode();
  /// } else {
  ///   promptUserToSelectActiveList();
  /// }
  /// ```
  Future<UnifiedShoppingList?> getActiveList();

  /// Adds a new item to the specified shopping list.
  ///
  /// Appends the provided item to the shopping list, enabling real-time
  /// collaboration if multiple users are sharing the list. The item is
  /// immediately available to all collaborators.
  ///
  /// [listId] The unique identifier of the shopping list
  /// [item] The shopping item to add to the list
  ///
  /// Throws [ShoppingListNotFoundException] if the list doesn't exist
  /// Throws [ValidationException] if the item data is invalid
  /// Throws [StorageException] if the add operation fails
  ///
  /// **Collaborative Behavior:**
  /// - Item appears immediately for all list collaborators
  /// - Supports real-time synchronization across devices
  /// - Handles concurrent additions gracefully
  /// - Maintains item ordering and categorization
  ///
  /// Example:
  /// ```dart
  /// final newItem = UnifiedShoppingItem(
  ///   name: 'Organic Milk',
  ///   quantity: 2,
  ///   category: 'Dairy',
  ///   notes: '2% fat content',
  /// );
  /// await shoppingRepo.addItem(listId, newItem);
  /// ```
  Future<void> addItem(String listId, UnifiedShoppingItem item);

  /// Removes an item from the specified shopping list.
  ///
  /// Deletes the item with the given ID from the shopping list. This action
  /// is immediately synchronized across all collaborators and cannot be undone.
  /// Consider implementing soft deletion or confirmation for better UX.
  ///
  /// [listId] The unique identifier of the shopping list
  /// [itemId] The unique identifier of the item to remove
  ///
  /// Throws [ShoppingListNotFoundException] if the list doesn't exist
  /// Throws [ShoppingItemNotFoundException] if the item doesn't exist
  /// Throws [StorageException] if the removal operation fails
  ///
  /// **Collaborative Impact:**
  /// - Item removal is immediately visible to all collaborators
  /// - Cannot be undone once completed
  /// - May affect shopping cart totals and calculations
  /// - Triggers real-time UI updates across devices
  ///
  /// Example:
  /// ```dart
  /// // Remove completed item
  /// await shoppingRepo.removeItem(listId, completedItemId);
  /// 
  /// // Remove with confirmation
  /// final shouldRemove = await showRemoveConfirmation(item.name);
  /// if (shouldRemove) {
  ///   await shoppingRepo.removeItem(listId, item.id);
  /// }
  /// ```
  Future<void> removeItem(String listId, String itemId);

  // ===== TEMPLATE OPERATIONS =====

  /// Save shopping list as template
  Future<String> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  });

  /// Update existing template
  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  });

  /// Delete template
  Future<void> deleteTemplate(String templateId);

  /// Get user's templates
  Future<List<Map<String, dynamic>>> getUserTemplates();

  /// Get public templates
  Future<List<Map<String, dynamic>>> getPublicTemplates({
    int limit = 20,
    String? searchQuery,
    List<String>? tags,
  });

  /// Create shopping list from template
  Future<String> createListFromTemplate({
    required String templateId,
    required String listName,
    String? description,
  });
}
