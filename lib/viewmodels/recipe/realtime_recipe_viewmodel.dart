// lib/viewmodels/recipe/realtime_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Realtime Recipe ViewModel
/// Handles ONLY real-time collaborative editing operations.
/// This includes real-time sessions, live edits, active editor tracking, and connection management.
class RealtimeRecipeViewModel extends ChangeNotifier
    with StreamManagementMixin, ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  bool _disposed = false;

  /// Create RealtimeRecipeViewModel with dependency injection
  RealtimeRecipeViewModel([UnifiedRecipeService? recipeService])
      : _recipeService =
            recipeService ?? ServiceLocator.get<UnifiedRecipeService>();

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) {
      throw FlutterError('RealtimeRecipeViewModel has been disposed');
    }
    super.addListener(listener);
  }

  String get serviceName => 'RealtimeRecipeViewModel';
  String? get currentUserId {
    if (_disposed) {
      throw FlutterError('RealtimeRecipeViewModel has been disposed');
    }
    return _recipeService.currentUserId;
  }

  String? get currentUserDisplayName {
    if (_disposed) {
      throw FlutterError('RealtimeRecipeViewModel has been disposed');
    }
    return _recipeService.currentUserDisplayName;
  }

  bool get isRealtimeConnected {
    if (_disposed) {
      throw FlutterError('RealtimeRecipeViewModel has been disposed');
    }
    return _recipeService.realtime.isConnected;
  }

  Stream<bool> get realtimeConnectionStream {
    if (_disposed) {
      throw FlutterError('RealtimeRecipeViewModel has been disposed');
    }
    return _recipeService.realtime.connectionStream;
  }

  Future<bool> startRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || recipeId.trim().isEmpty) {
      return false;
    }

    final result = await safeExecute(
      () => _recipeService.realtime.startRealtimeEditing(recipeId),
      operationName: 'Start Realtime Editing',
      defaultValue: false,
    );

    if (result == true) {
      AppLogger.info('✅ Started realtime editing: $recipeId');
    }
    return result.orFalse();
  }

  Future<bool> stopRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final result = await safeExecute(
      () => _recipeService.realtime.stopRealtimeEditing(recipeId),
      operationName: 'Stop Realtime Editing',
      defaultValue: false,
    );

    if (result == true) {
      AppLogger.info('✅ Stopped realtime editing: $recipeId');
    }
    return result.orFalse();
  }

  bool isInRealtimeEditingSession(String recipeId) {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;
    return _recipeService.isInRealtimeEditingSession(recipeId);
  }

  Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    String? editDescription,
  }) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || changes.isEmpty) {
      return false;
    }

    return (await safeExecute(
      () => _recipeService.realtime.makeRealtimeEdit(
        recipeId: recipeId,
        changes: changes,
        editDescription: editDescription,
      ),
      operationName: 'Realtime Recipe Edit',
      defaultValue: false,
    ))
        .orFalse();
  }

  Future<bool> addIngredientRealtime(String recipeId, String ingredient) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(ingredient)) {
      return false;
    }

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return (await safeExecute(
      () => _recipeService.addIngredient(recipeId, ingredient),
      operationName: 'Add Ingredient',
      defaultValue: false,
    ))
        .orFalse();
  }

  Future<bool> updateIngredientRealtime(
      String recipeId, int index, String newIngredient) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(newIngredient)) {
      return false;
    }

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return (await safeExecute(
      () => _recipeService.updateIngredient(recipeId, index, newIngredient),
      operationName: 'Update Ingredient',
      defaultValue: false,
    ))
        .orFalse();
  }

  Future<bool> removeIngredientRealtime(String recipeId, int index) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return (await safeExecute(
      () => _recipeService.removeIngredient(recipeId, index),
      operationName: 'Remove Ingredient',
      defaultValue: false,
    ))
        .orFalse();
  }

  Future<bool> addInstructionRealtime(
      String recipeId, String instruction) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(instruction)) {
      return false;
    }

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return (await safeExecute(
      () => _recipeService.addInstruction(recipeId, instruction),
      operationName: 'Add Instruction',
      defaultValue: false,
    ))
        .orFalse();
  }

  Future<bool> updateInstructionRealtime(
      String recipeId, int index, String newInstruction) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(newInstruction)) {
      return false;
    }

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return (await safeExecute(
      () => _recipeService.updateInstruction(recipeId, index, newInstruction),
      operationName: 'Update Instruction',
      defaultValue: false,
    ))
        .orFalse();
  }

  Future<bool> removeInstructionRealtime(String recipeId, int index) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    if (!isInRealtimeEditingSession(recipeId)) {
      return false;
    }

    return (await safeExecute(
      () => _recipeService.removeInstruction(recipeId, index),
      operationName: 'Remove Instruction',
      defaultValue: false,
    ))
        .orFalse();
  }

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

  Future<List<String>> getActiveEditorsAsync(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return [];

    return await safeExecute(
          () async {
            final presence =
                await _recipeService.realtime.getRecipePresence(recipeId);
            return presence.map((p) => p['userId'] as String? ?? '').toList();
          },
          operationName: 'Get Active Editors',
          defaultValue: <String>[],
        ) ??
        [];
  }

  List<String> getActiveEditors(String recipeId) {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return [];

    // Get active editors synchronously from presence tracking
    return _recipeService.realtime.getActiveEditors(recipeId);
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

  Stream<List<String>> watchActiveEditors(String recipeId) {
    if (ValidationUtils.isNullOrEmpty(recipeId)) {
      return Stream.value([]);
    }

    // Watch presence updates and extract user IDs
    return _recipeService.realtime.watchRecipePresence(recipeId).map(
        (presence) =>
            presence.map((p) => p['userId'] as String? ?? '').toList());
  }

  Future<bool> reconnectRealtime() async {
    return (await safeExecute(
      () async {
        // Connection management is handled automatically by the service
        // Force refresh of all active resources
        if (!isRealtimeConnected) {
          // Wait for connection to be re-established
          await Future.delayed(const Duration(seconds: 1));
          notifyListeners();
        }
        return isRealtimeConnected;
      },
      operationName: 'Reconnect Realtime',
      defaultValue: false,
    ))
        .orFalse();
  }

  Future<void> disconnectRealtime() async {
    await safeExecute(
      () async {
        // Clear all presence when disconnecting
        await _recipeService.realtime.clearAllPresence();
        notifyListeners();
      },
      operationName: 'Disconnect Realtime',
    );
  }

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

  Future<bool> resolveEditConflict({
    required String recipeId,
    required Map<String, dynamic> localChanges,
    required Map<String, dynamic> remoteChanges,
    required String resolution, // 'local', 'remote', or 'merge'
  }) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) ||
        ValidationUtils.isNullOrEmpty(resolution)) {
      return false;
    }

    return (await safeExecute(
      () async {
        // Get current recipe
        final recipe = _recipeService.recipes.firstWhere(
          (r) => r.id == recipeId,
          orElse: () => throw Exception('Recipe not found'),
        );

        // Apply resolution strategy
        Recipe resolvedRecipe;
        switch (resolution) {
          case 'local':
            // Apply local changes to current recipe
            resolvedRecipe = _applyChangesToRecipe(recipe, localChanges);
            break;
          case 'remote':
            // Apply remote changes to current recipe
            resolvedRecipe = _applyChangesToRecipe(recipe, remoteChanges);
            break;
          case 'merge':
            // Merge both changes (remote first, then local to give local priority)
            final mergedRecipe = _applyChangesToRecipe(recipe, remoteChanges);
            resolvedRecipe = _applyChangesToRecipe(mergedRecipe, localChanges);
            break;
          default:
            throw ArgumentError('Invalid resolution type: $resolution');
        }

        // Save resolved recipe through conflict resolution
        return await _recipeService.realtime.resolveConflict(
          recipeId: recipeId,
          localVersion: resolution == 'local' ? resolvedRecipe : recipe,
          remoteVersion: resolution == 'remote' ? resolvedRecipe : recipe,
          resolution: resolution,
        );
      },
      operationName: 'Resolve Edit Conflict',
      defaultValue: false,
    ))
        .orFalse();
  }

  Recipe _applyChangesToRecipe(Recipe recipe, Map<String, dynamic> changes) {
    // Create a new RecipeCore with updated values
    final updatedCore = RecipeCore(
      id: recipe.id,
      title: changes['title'] as String? ?? recipe.title,
      description: changes['description'] as String? ?? recipe.description,
      ingredients: changes['ingredients']?.cast<String>() ?? recipe.ingredients,
      instructions:
          changes['instructions']?.cast<String>() ?? recipe.instructions,
      portions: changes['portions'] as int? ?? recipe.portions,
      timeMinutes: changes['timeMinutes'] as int? ?? recipe.timeMinutes,
      rating: changes['rating']?.toDouble() ?? recipe.rating,
      personalTagIds: changes['tags']?.cast<String>() ?? recipe.personalTagIds,
      imageUrls: changes['imageUrls']?.cast<String>() ?? recipe.imageUrls,
      mealType: changes['mealType'] as String? ?? recipe.mealType,
      sourceUrl: changes['sourceUrl'] as String? ?? recipe.sourceUrl,
      createdAt: recipe.createdAt,
      updatedAt: DateTime.now(),
      createdBy: recipe.createdBy,
      isPublic: recipe.isPublic,
      lastCookedAt: recipe.lastCookedAt,
    );

    // Create new Recipe with updated core
    return Recipe(
      core: updatedCore,
      type: recipe.type,
      socialData: recipe.socialData,
    );
  }

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

  @override
  void dispose() {
    _disposed = true;
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}
