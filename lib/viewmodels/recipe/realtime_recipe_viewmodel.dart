// lib/viewmodels/recipe/realtime_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logging_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Realtime Recipe ViewModel
/// 
/// Handles ONLY real-time collaborative editing operations.
/// This includes real-time sessions, live edits, active editor tracking, and connection management.
class RealtimeRecipeViewModel extends ChangeNotifier with StreamManagementMixin, ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  bool _disposed = false;

  /// Create RealtimeRecipeViewModel with dependency injection
  RealtimeRecipeViewModel([UnifiedRecipeService? recipeService]) 
      : _recipeService = recipeService ?? ServiceLocator.get<UnifiedRecipeService>();

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) throw FlutterError('RealtimeRecipeViewModel has been disposed');
    super.addListener(listener);
  }

  String get serviceName => 'RealtimeRecipeViewModel';

  // ===== GETTERS =====

  String? get currentUserId {
    if (_disposed) throw FlutterError('RealtimeRecipeViewModel has been disposed');
    return _recipeService.currentUserId;
  }
  
  String? get currentUserDisplayName {
    if (_disposed) throw FlutterError('RealtimeRecipeViewModel has been disposed');
    return _recipeService.currentUserDisplayName;
  }

  bool get isRealtimeConnected {
    if (_disposed) throw FlutterError('RealtimeRecipeViewModel has been disposed');
    return _recipeService.realtime.isConnected;
  }
  
  Stream<bool> get realtimeConnectionStream {
    if (_disposed) throw FlutterError('RealtimeRecipeViewModel has been disposed');
    return _recipeService.realtime.connectionStream;
  }

  // ===== REALTIME SESSION MANAGEMENT =====

  Future<bool> startRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId) || recipeId.trim().isEmpty) return false;

    try {
      return await LoggingUtils.loggedOperation(
        'Start Realtime Editing',
        () => _recipeService.realtime.startRealtimeEditing(recipeId),
        metadata: {'recipe_id': recipeId},
        level: LogLevel.info,
      );
    } catch (e) {
      // Handle exceptions gracefully - return false on any error
      return false;
    }
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

  Future<List<String>> getActiveEditorsAsync(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return [];
    
    return await LoggingUtils.loggedOperation(
      'Get Active Editors',
      () async {
        final presence = await _recipeService.realtime.getRecipePresence(recipeId);
        return presence.map((p) => p['userId'] as String? ?? '').toList();
      },
      metadata: {'recipe_id': recipeId},
    );
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
    return _recipeService.realtime.watchRecipePresence(recipeId)
        .map((presence) => presence.map((p) => p['userId'] as String? ?? '').toList());
  }

  // ===== CONNECTION MANAGEMENT =====

  Future<bool> reconnectRealtime() async {
    return await LoggingUtils.loggedOperation(
      'Reconnect Realtime',
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
      level: LogLevel.info,
    );
  }

  Future<void> disconnectRealtime() async {
    await LoggingUtils.loggedOperation(
      'Disconnect Realtime',
      () async {
        // Clear all presence when disconnecting
        await _recipeService.realtime.clearAllPresence();
        notifyListeners();
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
      metadata: {
        'recipe_id': recipeId,
        'resolution': resolution,
        'local_keys': localChanges.keys.toList(),
        'remote_keys': remoteChanges.keys.toList(),
      },
    );
  }
  
  Recipe _applyChangesToRecipe(Recipe recipe, Map<String, dynamic> changes) {
    // Create a new RecipeCore with updated values
    final updatedCore = RecipeCore(
      id: recipe.id,
      title: changes['title'] as String? ?? recipe.title,
      description: changes['description'] as String? ?? recipe.description,
      ingredients: changes['ingredients']?.cast<String>() ?? recipe.ingredients,
      instructions: changes['instructions']?.cast<String>() ?? recipe.instructions,
      portions: changes['portions'] as int? ?? recipe.portions,
      timeMinutes: changes['timeMinutes'] as int? ?? recipe.timeMinutes,
      rating: changes['rating']?.toDouble() ?? recipe.rating,
      tags: changes['tags']?.cast<String>() ?? recipe.tags,
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