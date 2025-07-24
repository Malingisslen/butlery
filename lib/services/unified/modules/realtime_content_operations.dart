// lib/services/unified/modules/realtime_content_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/logger.dart';

/// Focused module for real-time content operations
/// 
/// This module handles ONLY real-time content editing operations:
/// - Real-time recipe field updates (title, description)
/// - Real-time ingredient operations (add, update, remove)
/// - Real-time instruction operations (add, update, remove)
/// - Edit metadata generation and validation
/// 
/// ❌ DOES NOT CONTAIN: Session management, conflict resolution, editor tracking, event handling
class RealtimeContentOperations {

  // ===== CORE REAL-TIME EDIT OPERATION =====

  /// Make a real-time edit to recipe content
  static Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    try {
      // Validate session
      if (!activeEditingSessions.containsKey(recipeId)) {
        setError('Inte i realtidsredigeringsläge');
        return false;
      }

      // Add metadata to changes
      final editMetadata = {
        'editedBy': currentUserId,
        'editedByDisplayName': currentUserDisplayName,
        'editedAt': FieldValue.serverTimestamp(),
        'editType': 'realtime_edit',
        ...changes,
      };

      // Add to pending edits queue
      pendingRealtimeEdits.putIfAbsent(recipeId, () => []);
      pendingRealtimeEdits[recipeId]!.add(editMetadata);

      // Apply edit with conflict resolution
      await applyEditWithConflictResolution(recipeId, editMetadata);

      AppLogger.debug('Real-time edit applied to recipe $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not apply real-time edit: $e');
      setError('Kunde inte genomföra realtidsändring: $e');
      return false;
    }
  }

  // ===== BASIC FIELD UPDATES =====

  /// Update recipe title in real-time
  static Future<bool> updateTitleRealtime({
    required String recipeId,
    required String newTitle,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (newTitle.trim().isEmpty) {
      setError('Titel kan inte vara tom');
      return false;
    }

    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'title': newTitle.trim(),
        'field': 'title',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Update recipe description in real-time
  static Future<bool> updateDescriptionRealtime({
    required String recipeId,
    required String newDescription,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'description': newDescription.trim(),
        'field': 'description',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Update recipe portions in real-time
  static Future<bool> updatePortionsRealtime({
    required String recipeId,
    required int newPortions,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (newPortions <= 0) {
      setError('Portioner måste vara större än 0');
      return false;
    }

    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'portions': newPortions,
        'field': 'portions',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Update recipe time in real-time
  static Future<bool> updateTimeRealtime({
    required String recipeId,
    required int newTimeMinutes,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (newTimeMinutes <= 0) {
      setError('Tid måste vara större än 0 minuter');
      return false;
    }

    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'timeMinutes': newTimeMinutes,
        'field': 'timeMinutes',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  // ===== INGREDIENT OPERATIONS =====

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

    return await makeRealtimeEdit(
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

    return await makeRealtimeEdit(
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

    return await makeRealtimeEdit(
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

    return await makeRealtimeEdit(
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

  // ===== INSTRUCTION OPERATIONS =====

  /// Add instruction in real-time
  static Future<bool> addInstructionRealtime({
    required String recipeId,
    required String instruction,
    int? index,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (instruction.trim().isEmpty) {
      setError('Instruktion kan inte vara tom');
      return false;
    }

    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'add_instruction',
        'instruction': instruction.trim(),
        'index': index,
        'field': 'instructions',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Update instruction in real-time
  static Future<bool> updateInstructionRealtime({
    required String recipeId,
    required int index,
    required String newInstruction,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (newInstruction.trim().isEmpty) {
      setError('Instruktion kan inte vara tom');
      return false;
    }

    if (index < 0) {
      setError('Ogiltigt instruktions-index');
      return false;
    }

    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'update_instruction',
        'index': index,
        'instruction': newInstruction.trim(),
        'field': 'instructions',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Remove instruction in real-time
  static Future<bool> removeInstructionRealtime({
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
      setError('Ogiltigt instruktions-index');
      return false;
    }

    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'remove_instruction',
        'index': index,
        'field': 'instructions',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  /// Reorder instructions in real-time
  static Future<bool> reorderInstructionsRealtime({
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
      setError('Ogiltiga instruktions-index');
      return false;
    }

    if (fromIndex == toIndex) {
      return true; // No change needed
    }

    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'reorder_instruction',
        'fromIndex': fromIndex,
        'toIndex': toIndex,
        'field': 'instructions',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  // ===== BATCH OPERATIONS =====

  /// Apply multiple edits as a batch
  static Future<bool> applyBatchEdits({
    required String recipeId,
    required List<Map<String, dynamic>> edits,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) async {
    if (edits.isEmpty) return true;

    return await makeRealtimeEdit(
      recipeId: recipeId,
      changes: {
        'operation': 'batch_edit',
        'edits': edits,
        'field': 'batch',
      },
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      activeEditingSessions: activeEditingSessions,
      pendingRealtimeEdits: pendingRealtimeEdits,
      applyEditWithConflictResolution: applyEditWithConflictResolution,
      setError: setError,
    );
  }

  // ===== VALIDATION HELPERS =====

  /// Validate ingredient content
  static bool isValidIngredient(String ingredient) {
    final trimmed = ingredient.trim();
    return trimmed.isNotEmpty && 
           trimmed.length <= 200 && // Reasonable length limit
           !trimmed.contains(RegExp(r'[<>]')); // No HTML tags
  }

  /// Validate instruction content
  static bool isValidInstruction(String instruction) {
    final trimmed = instruction.trim();
    return trimmed.isNotEmpty && 
           trimmed.length <= 1000 && // Reasonable length limit
           !trimmed.contains(RegExp(r'[<>]')); // No HTML tags
  }

  /// Sanitize text content
  static String sanitizeTextContent(String content) {
    return content.trim()
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }

  /// Validate index for list operations
  static bool isValidIndex(int index, int listLength, {bool allowAppend = false}) {
    if (index < 0) return false;
    if (allowAppend) {
      return index <= listLength; // Allow inserting at end
    } else {
      return index < listLength; // Must be within existing bounds
    }
  }
}