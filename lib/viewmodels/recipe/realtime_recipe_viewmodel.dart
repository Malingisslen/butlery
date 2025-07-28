// lib/viewmodels/recipe/realtime_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logging_utils.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Realtime Recipe ViewModel
/// 
/// Handles ONLY real-time collaborative editing operations.
/// This includes real-time sessions, live edits, active editor tracking, and connection management.
class RealtimeRecipeViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService = sl<UnifiedRecipeService>();

  String get serviceName => 'RealtimeRecipeViewModel';

  // ===== GETTERS =====

  String? get currentUserId => _recipeService.currentUserId;
  String? get currentUserDisplayName => _recipeService.currentUserDisplayName;

  bool get isRealtimeConnected => _recipeService.realtime.isConnected;
  Stream<bool> get realtimeConnectionStream => _recipeService.realtime.connectionStream;

  // ===== REALTIME SESSION MANAGEMENT =====

  Future<bool> startRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    return await LoggingUtils.loggedOperation(
      'Start Realtime Editing',
      () => _recipeService.realtime.startRealtimeEditing(recipeId),
      metadata: {'recipe_id': recipeId},
      level: LogLevel.info,
    );
  }

  Future<bool> stopRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    return await LoggingUtils.loggedOperation(
      'Stop Realtime Editing',
      () => _recipeService.realtime.stopRealtimeEditing(recipeId),
      metadata: {'recipe_id': recipeId},
      level: LogLevel.info,
    );
  }

  bool isInRealtimeEditingSession(String recipeId) {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;
    return _recipeService.isInRealtimeEditingSession(recipeId);
  }

  // ===== LIVE EDITING OPERATIONS =====

  Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    String? editDescription,
  }) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || changes.isEmpty) return false;

    return await LoggingUtils.loggedUpdate(
      'Realtime Recipe Edit',
      () => _recipeService.realtime.makeRealtimeEdit(
        recipeId: recipeId,
        changes: changes,
        editDescription: editDescription,
      ),
      itemId: recipeId,
      metadata: {
        'change_keys': changes.keys.toList(),
        'description': editDescription,
      },
    );
  }

  // ===== REALTIME CONTENT OPERATIONS =====

  Future<bool> addIngredientRealtime(String recipeId, String ingredient) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(ingredient)) {
      return false;
    }

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return await LoggingUtils.loggedUpdate(
      'Realtime Recipe Ingredient',
      () => _recipeService.addIngredient(recipeId, ingredient),
      itemId: recipeId,
      metadata: {'ingredient': ingredient, 'operation': 'add'},
    );
  }

  Future<bool> updateIngredientRealtime(String recipeId, int index, String newIngredient) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(newIngredient)) {
      return false;
    }

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return await LoggingUtils.loggedUpdate(
      'Realtime Recipe Ingredient',
      () => _recipeService.updateIngredient(recipeId, index, newIngredient),
      itemId: recipeId,
      metadata: {'index': index, 'ingredient': newIngredient, 'operation': 'update'},
    );
  }

  Future<bool> removeIngredientRealtime(String recipeId, int index) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return await LoggingUtils.loggedDelete(
      'Realtime Recipe Ingredient',
      () => _recipeService.removeIngredient(recipeId, index),
      itemId: recipeId,
      metadata: {'index': index, 'operation': 'remove'},
    );
  }

  Future<bool> addInstructionRealtime(String recipeId, String instruction) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(instruction)) {
      return false;
    }

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return await LoggingUtils.loggedUpdate(
      'Realtime Recipe Instruction',
      () => _recipeService.addInstruction(recipeId, instruction),
      itemId: recipeId,
      metadata: {'instruction': instruction, 'operation': 'add'},
    );
  }

  Future<bool> updateInstructionRealtime(String recipeId, int index, String newInstruction) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(newInstruction)) {
      return false;
    }

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return await LoggingUtils.loggedUpdate(
      'Realtime Recipe Instruction',
      () => _recipeService.updateInstruction(recipeId, index, newInstruction),
      itemId: recipeId,
      metadata: {'index': index, 'instruction': newInstruction, 'operation': 'update'},
    );
  }

  Future<bool> removeInstructionRealtime(String recipeId, int index) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return await LoggingUtils.loggedDelete(
      'Realtime Recipe Instruction',
      () => _recipeService.removeInstruction(recipeId, index),
      itemId: recipeId,
      metadata: {'index': index, 'operation': 'remove'},
    );
  }

  // ===== REALTIME WATCHING =====

  Stream<Recipe> watchRecipe(String recipeId) {
    if (ValidationUtils.isNullOrEmpty(recipeId)) {
      return const Stream.empty();
    }
    
    return _recipeService.realtime.watchRecipe(recipeId);
  }

  Stream<List<Recipe>> watchMultipleRecipes(List<String> recipeIds) {
    if (!ValidationUtils.hasItems(recipeIds)) {
      return Stream.value([]);
    }
    
    return _recipeService.realtime.watchMultipleRecipes(recipeIds);
  }

  // ===== ACTIVE EDITOR TRACKING =====

  List<String> getActiveEditors(String recipeId) {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return [];
    // TODO: Implement when realtime active editor tracking is available
    return [];
  }

  int getActiveEditorCount(String recipeId) {
    return getActiveEditors(recipeId).length;
  }

  bool isUserActivelyEditing(String recipeId, String userId) {
    return getActiveEditors(recipeId).contains(userId);
  }

  bool isCurrentUserActivelyEditing(String recipeId) {
    final currentUser = currentUserId;
    if (currentUser == null) return false;
    return isUserActivelyEditing(recipeId, currentUser);
  }

  // ===== CONNECTION MANAGEMENT =====

  Future<bool> reconnectRealtime() async {
    return await LoggingUtils.loggedOperation(
      'Reconnect Realtime',
      () async {
        // TODO: Implement when realtime reconnect is available
        return true;
      },
      level: LogLevel.info,
    );
  }

  Future<void> disconnectRealtime() async {
    await LoggingUtils.loggedOperation(
      'Disconnect Realtime',
      () async {
        // TODO: Implement when realtime disconnect is available
      },
      level: LogLevel.info,
    );
  }

  // ===== SESSION STATE =====

  Map<String, bool> getActiveRealtimeSessions() {
    // Get all recipes and check which ones are in realtime sessions
    final sessions = <String, bool>{};
    for (final recipe in _recipeService.recipes) {
      sessions[recipe.id] = isInRealtimeEditingSession(recipe.id);
    }
    return sessions;
  }

  List<String> getActiveRealtimeRecipeIds() {
    return getActiveRealtimeSessions()
        .entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  int getActiveSessionCount() {
    return getActiveRealtimeRecipeIds().length;
  }

  // ===== CONFLICT RESOLUTION =====

  Future<bool> resolveEditConflict({
    required String recipeId,
    required Map<String, dynamic> localChanges,
    required Map<String, dynamic> remoteChanges,
    required String resolution, // 'local', 'remote', or 'merge'
  }) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || ValidationUtils.isNullOrEmpty(resolution)) {
      return false;
    }

    return await LoggingUtils.loggedOperation(
      'Resolve Edit Conflict',
      () async {
        // TODO: Implement conflict resolution when realtime operations are available
        return true;
      },
      metadata: {
        'recipe_id': recipeId,
        'resolution': resolution,
        'local_keys': localChanges.keys.toList(),
        'remote_keys': remoteChanges.keys.toList(),
      },
    );
  }

  // ===== REALTIME ANALYTICS =====

  Map<String, dynamic> getRealtimeStats() {
    final activeSessionCount = getActiveSessionCount();
    final totalEditorsCount = getActiveRealtimeRecipeIds()
        .map((recipeId) => getActiveEditorCount(recipeId))
        .fold(0, (sum, count) => sum + count);

    return {
      'isConnected': isRealtimeConnected,
      'activeSessionCount': activeSessionCount,
      'totalActiveEditors': totalEditorsCount,
      'currentUserActiveSessions': getActiveRealtimeRecipeIds()
          .where((recipeId) => isCurrentUserActivelyEditing(recipeId))
          .length,
    };
  }

  Map<String, int> getRealtimeUsageByRecipe() {
    final usage = <String, int>{};
    for (final recipeId in getActiveRealtimeRecipeIds()) {
      usage[recipeId] = getActiveEditorCount(recipeId);
    }
    return usage;
  }
}