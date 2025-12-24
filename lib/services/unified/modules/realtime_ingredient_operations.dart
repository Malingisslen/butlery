// lib/services/unified/modules/realtime_ingredient_operations.dart

import 'package:butlery/services/unified/modules/realtime_edit_context.dart';
import 'package:butlery/services/unified/modules/realtime_field_operations.dart';

/// Real-time ingredient operations module
/// Handles all ingredient CRUD operations for real-time recipe editing.
class RealtimeIngredientOperations {
  /// Add ingredient in real-time
  static Future<bool> addIngredientRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required String ingredient,
    int? index,
  }) async {
    if (ingredient.trim().isEmpty) {
      context.setError('Ingrediens kan inte vara tom');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'add_ingredient',
        'ingredient': ingredient.trim(),
        'index': index,
        'field': 'ingredients',
      },
    );
  }

  /// Update ingredient in real-time
  static Future<bool> updateIngredientRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int index,
    required String newIngredient,
  }) async {
    if (newIngredient.trim().isEmpty) {
      context.setError('Ingrediens kan inte vara tom');
      return false;
    }
    if (index < 0) {
      context.setError('Ogiltigt ingrediens-index');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'update_ingredient',
        'index': index,
        'ingredient': newIngredient.trim(),
        'field': 'ingredients',
      },
    );
  }

  /// Remove ingredient in real-time
  static Future<bool> removeIngredientRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int index,
  }) async {
    if (index < 0) {
      context.setError('Ogiltigt ingrediens-index');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'remove_ingredient',
        'index': index,
        'field': 'ingredients',
      },
    );
  }

  /// Reorder ingredients in real-time
  static Future<bool> reorderIngredientsRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int fromIndex,
    required int toIndex,
  }) async {
    if (fromIndex < 0 || toIndex < 0) {
      context.setError('Ogiltiga ingrediens-index');
      return false;
    }
    if (fromIndex == toIndex) {
      return true; // No change needed
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'reorder_ingredient',
        'fromIndex': fromIndex,
        'toIndex': toIndex,
        'field': 'ingredients',
      },
    );
  }
}
