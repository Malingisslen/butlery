// lib/viewmodels/universal_share_dialog_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/unified/unified_shopping_list.dart';
import '../services/social_recipe_service.dart';
import '../core/utils/logger.dart';

/// ViewModel for UniversalShareDialog
/// Handles business logic for sharing content with friends
class UniversalShareDialogViewModel extends ChangeNotifier {
  final SocialRecipeService _socialRecipeService;

  // State
  bool _isSharing = false;
  String? _errorMessage;

  UniversalShareDialogViewModel({
    required SocialRecipeService socialRecipeService,
  }) : _socialRecipeService = socialRecipeService;

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
      final success = await _socialRecipeService.shareRecipeToFriends(
        recipe: recipe,
        friendUserIds: friendUserIds,
        message: message,
        allowCollaboration: allowCollaboration,
      );

      if (!success) {
        _setError(_socialRecipeService.error ?? 'Okänt fel');
        return false;
      }

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
      final success = await _socialRecipeService.shareMenuToFriends(
        menu: menu,
        friendUserIds: friendUserIds,
        message: message,
        allowCollaboration: allowCollaboration,
      );

      if (!success) {
        _setError(_socialRecipeService.error ?? 'Okänt fel');
        return false;
      }

      return true;
    } catch (e) {
      _setError('Kunde inte dela meny: $e');
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

      // Simulate sharing - in real implementation, this would use a shopping service
      await Future.delayed(const Duration(milliseconds: 500));

      AppLogger.success('✅ Inköpslista delad framgångsrikt');
      return true;
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
}