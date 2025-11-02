// lib/services/unified/modules/realtime_instruction_operations.dart

import 'package:butlery/services/unified/modules/realtime_edit_context.dart';
import 'package:butlery/services/unified/modules/realtime_field_operations.dart';

/// Real-time instruction operations module
///
/// Handles all instruction CRUD operations for real-time recipe editing.
class RealtimeInstructionOperations {

  /// Add instruction in real-time
  static Future<bool> addInstructionRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required String instruction,
    int? index,
  }) async {
    if (instruction.trim().isEmpty) {
      context.setError('Instruktion kan inte vara tom');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'add_instruction',
        'instruction': instruction.trim(),
        'index': index,
        'field': 'instructions',
      },
    );
  }

  /// Update instruction in real-time
  static Future<bool> updateInstructionRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int index,
    required String newInstruction,
  }) async {
    if (newInstruction.trim().isEmpty) {
      context.setError('Instruktion kan inte vara tom');
      return false;
    }
    if (index < 0) {
      context.setError('Ogiltigt instruktions-index');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'update_instruction',
        'index': index,
        'instruction': newInstruction.trim(),
        'field': 'instructions',
      },
    );
  }

  /// Remove instruction in real-time
  static Future<bool> removeInstructionRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int index,
  }) async {
    if (index < 0) {
      context.setError('Ogiltigt instruktions-index');
      return false;
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'remove_instruction',
        'index': index,
        'field': 'instructions',
      },
    );
  }

  /// Reorder instructions in real-time
  static Future<bool> reorderInstructionsRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int fromIndex,
    required int toIndex,
  }) async {
    if (fromIndex < 0 || toIndex < 0) {
      context.setError('Ogiltiga instruktions-index');
      return false;
    }
    if (fromIndex == toIndex) {
      return true; // No change needed
    }
    return await RealtimeFieldOperations.makeRealtimeEdit(
      context: context,
      recipeId: recipeId,
      changes: {
        'operation': 'reorder_instruction',
        'fromIndex': fromIndex,
        'toIndex': toIndex,
        'field': 'instructions',
      },
    );
  }
}
