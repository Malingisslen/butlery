// lib/viewmodels/universal_share_dialog_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/unified/unified_shopping_list.dart';
import '../services/social_recipe_service.dart';
import '../services/unified/unified_shopping_service.dart';
import '../core/utils/logger.dart';

/// ViewModel for UniversalShareDialog
/// Handles business logic for sharing content with friends
class UniversalShareDialogViewModel extends ChangeNotifier {
  final SocialRecipeService _socialRecipeService;
  final UnifiedShoppingService _shoppingService;

  // State
  bool _isSharing = false;
  String? _errorMessage;

  UniversalShareDialogViewModel({
    required SocialRecipeService socialRecipeService,
    required UnifiedShoppingService shoppingService,
  }) : _socialRecipeService = socialRecipeService,
       _shoppingService = shoppingService;

  // Getters
  bool get isSharing => _isSharing;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Share a recipe with selected friends
  Future<bool> shareRecipe({
    required Recipe recipe,
    required List<String> friendUserIds,
    String? message,
    bool allowCollaboration = false,
  }) async {
    if (friendUserIds.isEmpty) {
      _setError('Inga vänner valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      await _socialRecipeService.shareRecipeToFriends(
        recipe.id,
        friendUserIds,
      );

      return true;
    } catch (e) {
      _setError('Kunde inte dela recept: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a menu with selected friends
  Future<bool> shareMenu({
    required Map<String, List<Recipe>> menu,
    required List<String> friendUserIds,
    String? menuId,
    String? message,
    bool allowCollaboration = false,
  }) async {
    if (friendUserIds.isEmpty) {
      _setError('Inga vänner valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      // Generate menu ID if not provided
      final actualMenuId = menuId ?? _generateMenuId(menu);
      
      await _socialRecipeService.shareMenuToFriends(
        actualMenuId,
        friendUserIds,
      );

      AppLogger.success('Menu shared successfully with ${friendUserIds.length} friends');
      return true;
    } catch (e) {
      _setError('Kunde inte dela meny: $e');
      AppLogger.error('Failed to share menu: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a shopping list with selected friends
  Future<bool> shareShoppingList({
    required UnifiedShoppingList shoppingList,
    required List<String> friendUserIds,
    String? message,
  }) async {
    if (friendUserIds.isEmpty) {
      _setError('Inga vänner valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      AppLogger.info(
        '📋 Delar inköpslista: ${shoppingList.name} med ${friendUserIds.length} vänner',
      );

      if (message != null) {
        AppLogger.info('💬 Meddelande: $message');
      }

      // Use UnifiedShoppingService for sharing
      bool allSuccessful = true;
      for (final friendId in friendUserIds) {
        final success = await _shoppingService.sharing.shareListWithFriend(
          shoppingList.id,
          friendId,
        );
        if (!success) {
          allSuccessful = false;
        }
      }

      if (allSuccessful) {
        AppLogger.success('✅ Inköpslista delad framgångsrikt');
        return true;
      } else {
        throw Exception('Några delningar misslyckades');
      }
    } catch (e) {
      _setError('Kunde inte dela inköpslista: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Clear any error messages
  void clearError() {
    _clearError();
  }

  // Private methods
  void _setSharing(bool value) {
    _isSharing = value;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Generate a unique menu ID based on menu content
  String _generateMenuId(Map<String, List<Recipe>> menu) {
    // Create a deterministic ID based on menu content
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final recipeCount = menu.values.fold<int>(0, (sum, recipes) => sum + recipes.length);
    final dayCount = menu.keys.length;
    
    // Generate ID: timestamp_dayCount_recipeCount
    final menuId = 'menu_${timestamp}_${dayCount}d_${recipeCount}r';
    
    AppLogger.info('Generated menu ID: $menuId for menu with $dayCount days and $recipeCount recipes');
    return menuId;
  }
}