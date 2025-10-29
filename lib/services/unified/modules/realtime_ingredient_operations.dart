// lib/services/unified/modules/realtime_ingredient_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/unified/modules/realtime_field_operations.dart';

/// Real-time ingredient operations module
///
/// Handles all ingredient CRUD operations for real-time recipe editing.
class RealtimeIngredientOperations {

  /// Add ingredient in real-time
  static Future<bool> addIngredientRealtime({
    required String recipeId,
    required String ingredient,
    int? index,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (ingredient.trim().isEmpty) {
      setError('Ingrediens kan inte vara tom');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'add_ingredient',
        'ingredient': ingredient.trim(),
        'index': index,
        'field': 'ingredients',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Update ingredient in real-time
  static Future<bool> updateIngredientRealtime({
    required String recipeId,
    required int index,
    required String newIngredient,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (newIngredient.trim().isEmpty) {
      setError('Ingrediens kan inte vara tom');
      return false;
    }
    if (index < 0) {
      setError('Ogiltigt ingrediens-index');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'update_ingredient',
        'index': index,
        'ingredient': newIngredient.trim(),
        'field': 'ingredients',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Remove ingredient in real-time
  static Future<bool> removeIngredientRealtime({
    required String recipeId,
    required int index,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (index < 0) {
      setError('Ogiltigt ingrediens-index');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'remove_ingredient',
        'index': index,
        'field': 'ingredients',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Reorder ingredients in real-time
  static Future<bool> reorderIngredientsRealtime({
    required String recipeId,
    required int fromIndex,
    required int toIndex,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (fromIndex < 0 || toIndex < 0) {
      setError('Ogiltiga ingrediens-index');
      return false;
    }
    if (fromIndex == toIndex) {
      return true; // No change needed
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'reorder_ingredient',
        'fromIndex': fromIndex,
        'toIndex': toIndex,
        'field': 'ingredients',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }
}
