// lib/services/unified/modules/realtime_conflict_resolver.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Focused module for real-time conflict resolution
/// This module handles ONLY edit conflict resolution:
/// - Conflict detection and resolution strategies
/// - Edit merging and field-level conflict handling
/// - List operation conflict resolution
/// - Optimistic update conflict management
/// ❌ DOES NOT CONTAIN: Session management, content operations, editor tracking, event handling
class RealtimeConflictResolver {
  /// Apply real-time edit with conflict resolution
  static Future<void> applyEditWithConflictResolution({
    required FirebaseFirestore firestore,
    required String recipeId,
    required Map<String, dynamic> editMetadata,
    required Map<String, Timer> conflictResolutionTimers,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
  }) async {
    try {
      // Cancel any existing conflict resolution timer
      conflictResolutionTimers[recipeId]?.cancel();

      // Apply edit immediately (optimistic update)
      await firestore
          .collection(FirestoreCollections.realtimeRecipes)
          .doc(recipeId)
          .update(editMetadata);

      // Set up conflict resolution timer
      conflictResolutionTimers[recipeId] = Timer(
        const Duration(milliseconds: 500), // Short delay for conflict detection
        () => resolveEditConflicts(
          firestore: firestore,
          recipeId: recipeId,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
        ),
      );
    } catch (e) {
      AppLogger.error('Conflict during real-time edit application: $e');
      await _handleEditConflict(
        recipeId: recipeId,
        editMetadata: editMetadata,
        pendingRealtimeEdits: pendingRealtimeEdits,
        conflictResolutionTimers: conflictResolutionTimers,
        firestore: firestore,
      );
    }
  }

  /// Resolve edit conflicts for a recipe
  static Future<void> resolveEditConflicts({
    required FirebaseFirestore firestore,
    required String recipeId,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) async {
    try {
      final pendingEdits = pendingRealtimeEdits[recipeId];
      if (pendingEdits == null || pendingEdits.isEmpty) return;

      AppLogger.debug(
          '🔄 Resolving conflicts for recipe $recipeId (${pendingEdits.length} pending edits)');

      // Load current recipe state
      final snapshot =
          await firestore.collection(FirestoreCollections.realtimeRecipes).doc(recipeId).get();

      if (!snapshot.exists) {
        AppLogger.warning(
            'Recipe $recipeId no longer exists during conflict resolution');
        return;
      }

      // Apply conflict resolution strategy (last-write-wins with field-level merging)
      final currentData = snapshot.data()!;
      final resolvedData = mergeConflictingEdits(currentData, pendingEdits);

      // Apply resolved changes
      await firestore
          .collection(FirestoreCollections.realtimeRecipes)
          .doc(recipeId)
          .update(resolvedData);

      // Clear pending edits
      pendingRealtimeEdits[recipeId]?.clear();

      AppLogger.success('✅ Edit conflicts resolved for recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Error resolving edit conflicts: $e');
      // Don't clear pending edits on failure - they'll be retried
    }
  }

  /// Merge conflicting edits using field-level conflict resolution
  static Map<String, dynamic> mergeConflictingEdits(
    Map<String, dynamic> currentData,
    List<Map<String, dynamic>> pendingEdits,
  ) {
    final resolvedData = Map<String, dynamic>.from(currentData);

    // Group edits by field to handle conflicts
    final editsByField = <String, List<Map<String, dynamic>>>{};
    for (final edit in pendingEdits) {
      final field = edit['field'] as String? ?? 'unknown';
      editsByField.putIfAbsent(field, () => []).add(edit);
    }

    AppLogger.debug('Merging edits for ${editsByField.length} fields');

    // Apply field-specific conflict resolution
    for (final entry in editsByField.entries) {
      final field = entry.key;
      final fieldEdits = entry.value;

      switch (field) {
        case 'title':
        case 'description':
        case 'portions':
        case 'timeMinutes':
          // For simple fields, use last edit (last-write-wins)
          _mergeSimpleField(resolvedData, field, fieldEdits);
          break;
        case 'ingredients':
        case 'instructions':
          // For list fields, apply operations in order
          _mergeListField(resolvedData, field, fieldEdits);
          break;
        case 'batch':
          // For batch operations, apply all operations
          _mergeBatchOperations(resolvedData, fieldEdits);
          break;
        default:
          // For unknown fields, use last edit
          _mergeUnknownField(resolvedData, field, fieldEdits);
      }
    }

    // Update metadata
    resolvedData['lastEditedAt'] = FieldValue.serverTimestamp();

    return resolvedData;
  }

  /// Merge simple field edits (last-write-wins)
  static void _mergeSimpleField(
    Map<String, dynamic> resolvedData,
    String field,
    List<Map<String, dynamic>> fieldEdits,
  ) {
    if (fieldEdits.isEmpty) return;

    // Use the last edit for simple fields
    final lastEdit = fieldEdits.last;
    if (lastEdit.containsKey(field)) {
      resolvedData[field] = lastEdit[field];
      resolvedData['editedBy'] = lastEdit['editedBy'];
      resolvedData['editedByDisplayName'] = lastEdit['editedByDisplayName'];

      AppLogger.debug('Applied simple field edit for $field');
    }
  }

  /// Merge list field edits (apply operations in order)
  static void _mergeListField(
    Map<String, dynamic> resolvedData,
    String field,
    List<Map<String, dynamic>> fieldEdits,
  ) {
    if (fieldEdits.isEmpty) return;

    final currentList = resolvedData[field] as List<dynamic>? ?? [];
    final updatedList = applyListOperations(currentList, fieldEdits);

    resolvedData[field] = updatedList;

    // Use the last editor's info
    final lastEdit = fieldEdits.last;
    resolvedData['editedBy'] = lastEdit['editedBy'];
    resolvedData['editedByDisplayName'] = lastEdit['editedByDisplayName'];

    AppLogger.debug('Applied ${fieldEdits.length} list operations for $field');
  }

  /// Merge batch operations
  static void _mergeBatchOperations(
    Map<String, dynamic> resolvedData,
    List<Map<String, dynamic>> batchEdits,
  ) {
    for (final batchEdit in batchEdits) {
      final edits = batchEdit['edits'] as List<dynamic>? ?? [];

      for (final edit in edits) {
        final editMap = edit as Map<String, dynamic>;
        final field = editMap['field'] as String?;

        if (field != null) {
          _mergeSimpleField(resolvedData, field, [editMap]);
        }
      }
    }

    AppLogger.debug('Applied ${batchEdits.length} batch operations');
  }

  /// Merge unknown field edits
  static void _mergeUnknownField(
    Map<String, dynamic> resolvedData,
    String field,
    List<Map<String, dynamic>> fieldEdits,
  ) {
    if (fieldEdits.isEmpty) return;

    final lastEdit = fieldEdits.last;
    if (lastEdit.containsKey(field)) {
      resolvedData[field] = lastEdit[field];
      AppLogger.debug('Applied unknown field edit for $field');
    }
  }

  /// Apply list operations (add, update, remove) to a list field
  static List<dynamic> applyListOperations(
    List<dynamic> currentList,
    List<Map<String, dynamic>> operations,
  ) {
    final resultList = List<dynamic>.from(currentList);

    // Sort operations by timestamp to ensure consistent ordering
    operations.sort((a, b) {
      final aTime = a['editedAt'] as Timestamp?;
      final bTime = b['editedAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    for (final operation in operations) {
      _applyListOperation(resultList, operation);
    }

    return resultList;
  }

  /// Apply single list operation
  static void _applyListOperation(
    List<dynamic> resultList,
    Map<String, dynamic> operation,
  ) {
    final opType = operation['operation'] as String?;
    final index = operation['index'] as int?;

    switch (opType) {
      case 'add_ingredient':
      case 'add_instruction':
        _applyAddOperation(resultList, operation, index);
        break;
      case 'update_ingredient':
      case 'update_instruction':
        _applyUpdateOperation(resultList, operation, index);
        break;
      case 'remove_ingredient':
      case 'remove_instruction':
        _applyRemoveOperation(resultList, index);
        break;
      case 'reorder_ingredient':
      case 'reorder_instruction':
        _applyReorderOperation(resultList, operation);
        break;
      default:
        AppLogger.warning('Unknown list operation: $opType');
    }
  }

  /// Apply add operation to list
  static void _applyAddOperation(
    List<dynamic> resultList,
    Map<String, dynamic> operation,
    int? index,
  ) {
    final item = operation['ingredient'] ?? operation['instruction'];
    if (item != null) {
      if (index != null && index >= 0 && index <= resultList.length) {
        resultList.insert(index, item);
      } else {
        resultList.add(item);
      }
    }
  }

  /// Apply update operation to list
  static void _applyUpdateOperation(
    List<dynamic> resultList,
    Map<String, dynamic> operation,
    int? index,
  ) {
    final item = operation['ingredient'] ?? operation['instruction'];
    if (item != null &&
        index != null &&
        index >= 0 &&
        index < resultList.length) {
      resultList[index] = item;
    }
  }

  /// Apply remove operation to list
  static void _applyRemoveOperation(List<dynamic> resultList, int? index) {
    if (index != null && index >= 0 && index < resultList.length) {
      resultList.removeAt(index);
    }
  }

  /// Apply reorder operation to list
  static void _applyReorderOperation(
    List<dynamic> resultList,
    Map<String, dynamic> operation,
  ) {
    final fromIndex = operation['fromIndex'] as int?;
    final toIndex = operation['toIndex'] as int?;

    if (fromIndex != null &&
        toIndex != null &&
        fromIndex >= 0 &&
        fromIndex < resultList.length &&
        toIndex >= 0 &&
        toIndex < resultList.length) {
      final item = resultList.removeAt(fromIndex);
      resultList.insert(toIndex, item);
    }
  }

  /// Handle edit conflict when Firebase update fails
  static Future<void> _handleEditConflict({
    required String recipeId,
    required Map<String, dynamic> editMetadata,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
    required FirebaseFirestore firestore,
  }) async {
    AppLogger.warning('⚠️ Edit conflict detected for recipe $recipeId');

    // Add to pending edits for later resolution
    pendingRealtimeEdits.putIfAbsent(recipeId, () => []);
    pendingRealtimeEdits[recipeId]!.add(editMetadata);

    // Trigger conflict resolution with longer delay
    conflictResolutionTimers[recipeId] = Timer(
      const Duration(
          milliseconds: 1000), // Longer delay for conflict resolution
      () => resolveEditConflicts(
        firestore: firestore,
        recipeId: recipeId,
        pendingRealtimeEdits: pendingRealtimeEdits,
        conflictResolutionTimers: conflictResolutionTimers,
      ),
    );
  }

  /// Check if edit would cause conflict
  static bool wouldCauseConflict({
    required Map<String, dynamic> currentData,
    required Map<String, dynamic> editData,
    required String field,
  }) {
    // Check if the field was modified recently by another user
    final lastEditedBy = currentData['editedBy'] as String?;
    final editedBy = editData['editedBy'] as String?;

    if (lastEditedBy != null && editedBy != null && lastEditedBy != editedBy) {
      final lastEditTime = currentData['editedAt'] as Timestamp?;
      if (lastEditTime != null) {
        final timeSinceLastEdit =
            DateTime.now().difference(lastEditTime.toDate());
        // Consider edits within 5 seconds as potential conflicts
        return timeSinceLastEdit.inSeconds < 5;
      }
    }

    return false;
  }

  /// Get conflict resolution strategy for field
  static String getConflictResolutionStrategy(String field) {
    switch (field) {
      case 'title':
      case 'description':
      case 'portions':
      case 'timeMinutes':
        return 'last-write-wins';
      case 'ingredients':
      case 'instructions':
        return 'operational-transform';
      default:
        return 'last-write-wins';
    }
  }

  /// Get conflict statistics
  static Map<String, dynamic> getConflictStatistics({
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) {
    final totalPendingEdits = pendingRealtimeEdits.values
        .fold<int>(0, (total, edits) => total + edits.length);

    final activeConflictTimers =
        conflictResolutionTimers.values.where((timer) => timer.isActive).length;

    final recipesWithConflicts = pendingRealtimeEdits.keys
        .where((recipeId) => (pendingRealtimeEdits[recipeId]?.length ?? 0) > 1)
        .length;

    return {
      'total_pending_edits': totalPendingEdits,
      'active_conflict_timers': activeConflictTimers,
      'recipes_with_conflicts': recipesWithConflicts,
      'recipes_with_pending_edits': pendingRealtimeEdits.length,
    };
  }

  /// Clear resolved conflicts
  static void clearResolvedConflicts({
    required String recipeId,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) {
    pendingRealtimeEdits.remove(recipeId);
    conflictResolutionTimers[recipeId]?.cancel();
    conflictResolutionTimers.remove(recipeId);
  }

  /// Force resolve all conflicts for a recipe
  static Future<void> forceResolveConflicts({
    required FirebaseFirestore firestore,
    required String recipeId,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) async {
    AppLogger.info('🔧 Force resolving conflicts for recipe $recipeId');

    // Cancel any existing timer
    conflictResolutionTimers[recipeId]?.cancel();

    // Resolve immediately
    await resolveEditConflicts(
      firestore: firestore,
      recipeId: recipeId,
      pendingRealtimeEdits: pendingRealtimeEdits,
      conflictResolutionTimers: conflictResolutionTimers,
    );
  }
}
