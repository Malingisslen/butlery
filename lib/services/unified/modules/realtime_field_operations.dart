// lib/services/unified/modules/realtime_field_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/modules/realtime_edit_context.dart';

/// Core real-time field operations module
/// Handles recipe field updates (title, description, portions, time) and batch operations.
/// Provides core makeRealtimeEdit method used by ingredient/instruction operations.
class RealtimeFieldOperations {
  /// Make a real-time edit to recipe content (CORE METHOD)
  static Future<bool> makeRealtimeEdit({
    required RealtimeEditContext context,
    required String recipeId,
    required Map<String, dynamic> changes,
  }) async {
    try {
      // Validate session
      if (!context.hasActiveSession(recipeId)) {
        context.setError('Inte i realtidsredigeringsläge');
        return false;
      }
      // Add metadata to changes
      final editMetadata = {
        'editedBy': context.currentUserId,
        'editedByDisplayName': context.currentUserDisplayName,
        'editedAt': FieldValue.serverTimestamp(),
        'editType': 'realtime_edit',
        ...changes,
      };
      // Add to pending edits queue
      context.enqueuePendingEdit(recipeId, editMetadata);
      // Apply edit with conflict resolution
      await context.applyEditWithConflictResolution(recipeId, editMetadata);
      AppLogger.debug('Real-time edit applied to recipe $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not apply real-time edit: $e');
      context.setError('Kunde inte genomföra realtidsändring: $e');
      return false;
    }
  }

  /// Update recipe title in real-time
  static Future<bool> updateTitleRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required String newTitle,
  }) async {
    if (newTitle.trim().isEmpty) {
      context.setError('Titel kan inte vara tom');
      return false;
    }
    return await makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'title': newTitle.trim(),
        'field': 'title',
      },
    );
  }

  /// Update recipe description in real-time
  static Future<bool> updateDescriptionRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required String newDescription,
  }) async {
    return await makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'description': newDescription.trim(),
        'field': 'description',
      },
    );
  }

  /// Update recipe portions in real-time
  static Future<bool> updatePortionsRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int newPortions,
  }) async {
    if (newPortions <= 0) {
      context.setError('Portioner måste vara större än 0');
      return false;
    }
    return await makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'portions': newPortions,
        'field': 'portions',
      },
    );
  }

  /// Update recipe time in real-time
  static Future<bool> updateTimeRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int newTimeMinutes,
  }) async {
    if (newTimeMinutes <= 0) {
      context.setError('Tid måste vara större än 0 minuter');
      return false;
    }
    return await makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'timeMinutes': newTimeMinutes,
        'field': 'timeMinutes',
      },
    );
  }

  /// Apply multiple edits as a batch
  static Future<bool> applyBatchEdits({
    required RealtimeEditContext context,
    required String recipeId,
    required List<Map<String, dynamic>> edits,
  }) async {
    if (edits.isEmpty) return true;
    return await makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'batch_edit',
        'edits': edits,
        'field': 'batch',
      },
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
    return content
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }

  /// Validate index for list operations
  static bool isValidIndex(int index, int listLength,
      {bool allowAppend = false}) {
    if (index < 0) return false;
    if (allowAppend) {
      return index <= listLength; // Allow inserting at end
    } else {
      return index < listLength; // Must be within existing bounds
    }
  }
}
