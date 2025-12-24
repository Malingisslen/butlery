// lib/services/unified/modules/realtime_content_operations.dart

import 'package:butlery/services/unified/modules/realtime_edit_context.dart';
import 'package:butlery/services/unified/modules/realtime_field_operations.dart';
import 'package:butlery/services/unified/modules/realtime_ingredient_operations.dart';
import 'package:butlery/services/unified/modules/realtime_instruction_operations.dart';

/// Facade module for real-time content operations
/// This module provides a unified interface to all real-time editing operations
/// by delegating to specialized modules:
/// - RealtimeFieldOperations: Core field updates (title, description, etc.)
/// - RealtimeIngredientOperations: Ingredient CRUD operations
/// - RealtimeInstructionOperations: Instruction CRUD operations
/// **SRP Compliance:** This file follows the facade pattern - it delegates
/// to specialized modules rather than implementing functionality directly.

export 'realtime_edit_context.dart';
export 'realtime_field_operations.dart';
export 'realtime_ingredient_operations.dart';
export 'realtime_instruction_operations.dart';

/// Facade class providing unified interface for real-time content operations
class RealtimeContentOperations {
  // FIELD OPERATIONS (delegate to RealtimeFieldOperations)

  static Future<bool> makeRealtimeEdit({
    required RealtimeEditContext context,
    required String recipeId,
    required Map<String, dynamic> changes,
  }) =>
      RealtimeFieldOperations.makeRealtimeEdit(
        context: context,
        recipeId: recipeId,
        changes: changes,
      );

  static Future<bool> updateTitleRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required String newTitle,
  }) =>
      RealtimeFieldOperations.updateTitleRealtime(
        context: context,
        recipeId: recipeId,
        newTitle: newTitle,
      );

  static Future<bool> updateDescriptionRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required String newDescription,
  }) =>
      RealtimeFieldOperations.updateDescriptionRealtime(
        context: context,
        recipeId: recipeId,
        newDescription: newDescription,
      );

  static Future<bool> updatePortionsRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int newPortions,
  }) =>
      RealtimeFieldOperations.updatePortionsRealtime(
        context: context,
        recipeId: recipeId,
        newPortions: newPortions,
      );

  static Future<bool> updateTimeRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int newTimeMinutes,
  }) =>
      RealtimeFieldOperations.updateTimeRealtime(
        context: context,
        recipeId: recipeId,
        newTimeMinutes: newTimeMinutes,
      );

  static Future<bool> applyBatchEdits({
    required RealtimeEditContext context,
    required String recipeId,
    required List<Map<String, dynamic>> edits,
  }) =>
      RealtimeFieldOperations.applyBatchEdits(
        context: context,
        recipeId: recipeId,
        edits: edits,
      );

  // INGREDIENT OPERATIONS (delegate to RealtimeIngredientOperations)

  static Future<bool> addIngredientRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required String ingredient,
    required int? index,
  }) =>
      RealtimeIngredientOperations.addIngredientRealtime(
        context: context,
        recipeId: recipeId,
        ingredient: ingredient,
        index: index,
      );

  static Future<bool> updateIngredientRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int index,
    required String newIngredient,
  }) =>
      RealtimeIngredientOperations.updateIngredientRealtime(
        context: context,
        recipeId: recipeId,
        index: index,
        newIngredient: newIngredient,
      );

  static Future<bool> removeIngredientRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int index,
  }) =>
      RealtimeIngredientOperations.removeIngredientRealtime(
        context: context,
        recipeId: recipeId,
        index: index,
      );

  static Future<bool> reorderIngredientsRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int fromIndex,
    required int toIndex,
  }) =>
      RealtimeIngredientOperations.reorderIngredientsRealtime(
        context: context,
        recipeId: recipeId,
        fromIndex: fromIndex,
        toIndex: toIndex,
      );

  // INSTRUCTION OPERATIONS (delegate to RealtimeInstructionOperations)

  static Future<bool> addInstructionRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required String instruction,
    required int? index,
  }) =>
      RealtimeInstructionOperations.addInstructionRealtime(
        context: context,
        recipeId: recipeId,
        instruction: instruction,
        index: index,
      );

  static Future<bool> updateInstructionRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int index,
    required String newInstruction,
  }) =>
      RealtimeInstructionOperations.updateInstructionRealtime(
        context: context,
        recipeId: recipeId,
        index: index,
        newInstruction: newInstruction,
      );

  static Future<bool> removeInstructionRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int index,
  }) =>
      RealtimeInstructionOperations.removeInstructionRealtime(
        context: context,
        recipeId: recipeId,
        index: index,
      );

  static Future<bool> reorderInstructionsRealtime({
    required RealtimeEditContext context,
    required String recipeId,
    required int fromIndex,
    required int toIndex,
  }) =>
      RealtimeInstructionOperations.reorderInstructionsRealtime(
        context: context,
        recipeId: recipeId,
        fromIndex: fromIndex,
        toIndex: toIndex,
      );
}
