// lib/services/unified/modules/realtime_content_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/unified/modules/realtime_field_operations.dart';
import 'package:butlery/services/unified/modules/realtime_ingredient_operations.dart';
import 'package:butlery/services/unified/modules/realtime_instruction_operations.dart';

/// Facade module for real-time content operations
///
/// This module provides a unified interface to all real-time editing operations
/// by delegating to specialized modules:
/// - RealtimeFieldOperations: Core field updates (title, description, etc.)
/// - RealtimeIngredientOperations: Ingredient CRUD operations
/// - RealtimeInstructionOperations: Instruction CRUD operations
///
/// **SRP Compliance:** This file follows the facade pattern - it delegates
/// to specialized modules rather than implementing functionality directly.

export 'realtime_field_operations.dart';
export 'realtime_ingredient_operations.dart';
export 'realtime_instruction_operations.dart';

/// Facade class providing unified interface for real-time content operations
class RealtimeContentOperations {
  // FIELD OPERATIONS (delegate to RealtimeFieldOperations)

  static Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeFieldOperations.makeRealtimeEdit(
    recipeId: recipeId,
    changes: changes,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  static Future<bool> updateTitleRealtime({
    required String recipeId,
    required String newTitle,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeFieldOperations.updateTitleRealtime(
    recipeId: recipeId,
    newTitle: newTitle,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  static Future<bool> updateDescriptionRealtime({
    required String recipeId,
    required String newDescription,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeFieldOperations.updateDescriptionRealtime(
    recipeId: recipeId,
    newDescription: newDescription,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  static Future<bool> updatePortionsRealtime({
    required String recipeId,
    required int newPortions,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeFieldOperations.updatePortionsRealtime(
    recipeId: recipeId,
    newPortions: newPortions,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  static Future<bool> updateTimeRealtime({
    required String recipeId,
    required int newTimeMinutes,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeFieldOperations.updateTimeRealtime(
    recipeId: recipeId,
    newTimeMinutes: newTimeMinutes,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  static Future<bool> applyBatchEdits({
    required String recipeId,
    required List<Map<String, dynamic>> edits,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeFieldOperations.applyBatchEdits(
    recipeId: recipeId,
    edits: edits,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  // INGREDIENT OPERATIONS (delegate to RealtimeIngredientOperations)

  static Future<bool> addIngredientRealtime({
    required String recipeId,
    required String ingredient,
    required int? index,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeIngredientOperations.addIngredientRealtime(
    recipeId: recipeId,
    ingredient: ingredient,
    index: index,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

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
  }) => RealtimeIngredientOperations.updateIngredientRealtime(
    recipeId: recipeId,
    index: index,
    newIngredient: newIngredient,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  static Future<bool> removeIngredientRealtime({
    required String recipeId,
    required int index,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeIngredientOperations.removeIngredientRealtime(
    recipeId: recipeId,
    index: index,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

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
  }) => RealtimeIngredientOperations.reorderIngredientsRealtime(
    recipeId: recipeId,
    fromIndex: fromIndex,
    toIndex: toIndex,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  // INSTRUCTION OPERATIONS (delegate to RealtimeInstructionOperations)

  static Future<bool> addInstructionRealtime({
    required String recipeId,
    required String instruction,
    required int? index,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeInstructionOperations.addInstructionRealtime(
    recipeId: recipeId,
    instruction: instruction,
    index: index,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

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
  }) => RealtimeInstructionOperations.updateInstructionRealtime(
    recipeId: recipeId,
    index: index,
    newInstruction: newInstruction,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

  static Future<bool> removeInstructionRealtime({
    required String recipeId,
    required int index,
    required String currentUserId,
    required String? currentUserDisplayName,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Future<void> Function(String, Map<String, dynamic>) applyEditWithConflictResolution,
    required void Function(String) setError,
  }) => RealtimeInstructionOperations.removeInstructionRealtime(
    recipeId: recipeId,
    index: index,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );

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
  }) => RealtimeInstructionOperations.reorderInstructionsRealtime(
    recipeId: recipeId,
    fromIndex: fromIndex,
    toIndex: toIndex,
    currentUserId: currentUserId,
    currentUserDisplayName: currentUserDisplayName,
    activeEditingSessions: activeEditingSessions,
    pendingRealtimeEdits: pendingRealtimeEdits,
    applyEditWithConflictResolution: applyEditWithConflictResolution,
    setError: setError,
  );
}
