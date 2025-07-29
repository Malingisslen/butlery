// lib/viewmodels/universal_share_dialog_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/core/utils/logger.dart';

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

  /// Share a recipe with selected friends and groups
  Future<bool> shareRecipe({
    required Recipe recipe,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? message,
    bool allowCollaboration = false,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError('Inga vänner eller grupper valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      // Share to friends if any selected
      if (friendUserIds.isNotEmpty) {
        await _socialRecipeService.shareRecipeToFriends(
          recipe.id,
          friendUserIds,
        );
      }

      // Share to groups if any selected
      if (groupIds != null && groupIds.isNotEmpty) {
        await _socialRecipeService.shareRecipeToGroups(
          recipe.id,
          groupIds,
        );
      }

      return true;
    } catch (e) {
      _setError('Kunde inte dela recept: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a menu with selected friends and groups
  Future<bool> shareMenu({
    required Map<String, List<Recipe>> menu,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? menuId,
    String? message,
    bool allowCollaboration = false,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError('Inga vänner eller grupper valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      // Generate menu ID if not provided
      final actualMenuId = menuId ?? _generateMenuId(menu);
      
      // Share to friends if any selected
      if (friendUserIds.isNotEmpty) {
        await _socialRecipeService.shareMenuToFriends(
          actualMenuId,
          friendUserIds,
        );
      }

      // Share to groups if any selected
      if (groupIds != null && groupIds.isNotEmpty) {
        await _socialRecipeService.shareMenuToGroups(
          actualMenuId,
          groupIds,
        );
      }

      final totalTargets = friendUserIds.length + (groupIds?.length ?? 0);
      AppLogger.success('Menu shared successfully with $totalTargets targets (${friendUserIds.length} friends, ${groupIds?.length ?? 0} groups)');
      return true;
    } catch (e) {
      _setError('Kunde inte dela meny: $e');
      AppLogger.error('Failed to share menu: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a shopping list with selected friends and groups
  Future<bool> shareShoppingList({
    required UnifiedShoppingList shoppingList,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? message,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError('Inga vänner eller grupper valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      final totalTargets = friendUserIds.length + (groupIds?.length ?? 0);
      AppLogger.info(
        '📋 Delar inköpslista: ${shoppingList.name} med $totalTargets mottagare (${friendUserIds.length} vänner, ${groupIds?.length ?? 0} grupper)',
      );

      if (message != null) {
        AppLogger.info('💬 Meddelande: $message');
      }

      // Use UnifiedShoppingService for sharing to friends
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

      // Share to groups if any selected
      if (groupIds != null && groupIds.isNotEmpty) {
        for (final groupId in groupIds) {
          final success = await _shoppingService.sharing.shareListWithGroup(
            shoppingList.id,
            groupId,
          );
          if (!success) {
            allSuccessful = false;
          }
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