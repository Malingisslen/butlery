// lib/services/unified/modules/realtime_field_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';

/// Core real-time field operations module
///
/// Handles recipe field updates (title, description, portions, time) and batch operations.
/// Provides core makeRealtimeEdit method used by ingredient/instruction operations.
class RealtimeFieldOperations {

  /// Make a real-time edit to recipe content (CORE METHOD)
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
