// lib/models/user_counters.dart

/// Field names in `users/{userId}/counters/shared_content`, for atomic
/// `FieldValue.increment()` updates.
///
/// Only fields the `firestore.rules` counters allowlist accepts belong here: a
/// write that adds any other key is refused, and so is every later write to
/// the same document, because the rule checks the whole stored document.
class UserCounterIncrements {
  static const String unreadSharedRecipes = 'unreadSharedRecipes';
  static const String unreadSharedMenus = 'unreadSharedMenus';
  static const String unreadSharedShoppingLists = 'unreadSharedShoppingLists';
  static const String totalSharedContent = 'totalSharedContent';

  /// Get field name for content type
  static String fieldForType(String type) {
    switch (type) {
      case 'recipes':
      case 'shared_recipes':
        return unreadSharedRecipes;
      case 'menus':
      case 'shared_menus':
        return unreadSharedMenus;
      case 'shopping_lists':
      case 'shared_shopping_lists':
        return unreadSharedShoppingLists;
      default:
        throw ArgumentError('Unknown counter type: $type');
    }
  }
}
