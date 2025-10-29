// lib/services/unified/modules/realtime_instruction_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/unified/modules/realtime_field_operations.dart';

/// Real-time instruction operations module
///
/// Handles all instruction CRUD operations for real-time recipe editing.
class RealtimeInstructionOperations {

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
    return await RealtimeFieldOperations.makeRealtimeEdit(
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
    return await RealtimeFieldOperations.makeRealtimeEdit(
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
    return await RealtimeFieldOperations.makeRealtimeEdit(
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
    return await RealtimeFieldOperations.makeRealtimeEdit(
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
}
