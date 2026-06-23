// lib/services/unified/operations/collaborative_menu_operations.dart

import 'dart:ui';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';

/// Collaborative menu operations for real-time menu sharing.
/// Handles collaboration setup, recipe add/remove on shared menus,
/// and real-time listener management.
class CollaborativeMenuOperations {
  final MenuCollaborationRepository _repository;
  final VoidCallback _notifyListeners;

  CollaborativeMenuOperations({
    required VoidCallback notifyListeners,
    required MenuCollaborationRepository repository,
  }) : _notifyListeners = notifyListeners,
       _repository = repository;

  /// Enable real-time collaboration for a menu
  Future<bool> enableMenuCollaboration({
    required String menuId,
    required List<String> collaboratorIds,
    Map<String, String>? collaboratorDisplayNames,
  }) async {
    final result = await _repository.enableCollaboration(
      menuId: menuId,
      collaboratorIds: collaboratorIds,
      collaboratorDisplayNames: collaboratorDisplayNames,
    );

    if (result) {
      _startMenuCollaborationListener(menuId);
    }

    return result;
  }

  /// Add recipe to collaborative menu
  Future<bool> addRecipeToCollaborativeMenu({
    required String menuId,
    required String category,
    required Recipe recipe,
    String? suggestedBy,
    String? suggestion,
  }) async {
    return await _repository.addRecipeToMenu(
      menuId: menuId,
      category: category,
      recipe: recipe,
      suggestedBy: suggestedBy,
      suggestion: suggestion,
    );
  }

  /// Remove recipe from collaborative menu
  Future<bool> removeRecipeFromCollaborativeMenu({
    required String menuId,
    required String category,
    required String recipeId,
    String? reason,
  }) async {
    return await _repository.removeRecipeFromMenu(
      menuId: menuId,
      category: category,
      recipeId: recipeId,
      reason: reason,
    );
  }

  /// Start real-time listener for menu collaboration
  void _startMenuCollaborationListener(String menuId) {
    _repository.startCollaborationListener(menuId, (menu) {
      AppLogger.debug('Menu $menuId updated in real-time');
      _notifyListeners();
    });
  }

  /// Dispose of resources
  void dispose() {
    _repository.disposeAllListeners();
    AppLogger.info('Disposed collaborative menu operations');
  }
}
