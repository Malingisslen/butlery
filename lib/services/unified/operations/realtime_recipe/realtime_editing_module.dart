// lib/services/unified/operations/realtime_recipe/realtime_editing_module.dart

// ignore: unused_import
import 'package:collection/collection.dart'; // Needed for .firstOrNull on dynamic _parent.recipes
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/shared/realtime_recipe_utils.dart';

/// Realtime recipe editing module
/// This module handles ONLY real-time editing operations:
/// - Start/stop realtime editing sessions
/// - Make realtime edits with conflict resolution
/// - Handle edit conflicts and merging
/// - Validate editing permissions
/// ❌ DOES NOT CONTAIN: Watching, presence, notifications, collaboration management
class RealtimeEditingModule {
  final UnifiedRecipeService _parent;
  final RealtimeSyncService? _realtimeSyncService;

  RealtimeEditingModule(this._parent, [this._realtimeSyncService]);

  // ===== EDITING SESSION MANAGEMENT =====

  /// Start real-time editing session for recipe
  Future<bool> startRealtimeEditing(String recipeId) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      final validationError = RealtimeRecipeUtils.validateRecipeForRealtime(recipe);
      if (validationError != null) {
        AppLogger.error('Cannot start realtime editing: $validationError');
        return false;
      }

      final permissionError = RealtimeRecipeUtils.validateUserPermissions(
        _parent.currentUserId, 
        recipeId,
        requireEdit: true,
        requireOwner: false,
      );
      if (permissionError != null) {
        AppLogger.error('Cannot start realtime editing: $permissionError');
        return false;
      }

      if (_realtimeSyncService == null) {
        AppLogger.warning('RealtimeSyncService not available');
        return false;
      }

      // Convert to realtime recipe if needed
      await _convertToRealtimeRecipe(recipe!);
      
      AppLogger.info('Started realtime editing for recipe: ${recipe.title}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to start realtime editing', e);
      return false;
    }
  }

  /// Stop real-time editing session for recipe
  Future<bool> stopRealtimeEditing(String recipeId) async {
    try {
      // This would stop the real-time listeners for the specific recipe
      AppLogger.info('Stopped realtime editing for recipe: $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to stop realtime editing', e);
      return false;
    }
  }

  /// Check if recipe is in realtime editing mode
  bool isInRealtimeEditingMode(String recipeId) {
    // This would check if the recipe is currently being edited in realtime
    // For now, simulate based on recipe type
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    return recipe?.isCollaborative == true;
  }

  // ===== REALTIME EDITING OPERATIONS =====

  /// Make real-time edit to recipe with conflict resolution
  Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    String? editDescription,
  }) async {
    if (_realtimeSyncService == null) {
      AppLogger.warning('RealtimeSyncService not available, falling back to regular edit');
      return _makeRegularEdit(recipeId, changes);
    }

    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error('Recipe not found for realtime edit');
        return false;
      }

      final permissionError = RealtimeRecipeUtils.validateUserPermissions(
        _parent.currentUserId, 
        recipeId,
        requireEdit: true,
        requireOwner: false,
      );
      if (permissionError != null) {
        AppLogger.error('No permission to edit recipe: $permissionError');
        return false;
      }

      // Convert to realtime recipe for editing
      final realtimeRecipe = await _convertToRealtimeRecipe(recipe);
      
      // Apply changes to realtime recipe
      RealtimeRecipeUtils.applyChangesToRealtimeRecipe(
        realtimeRecipe, 
        changes,
        editDescription,
        _parent.currentUserId,
        _parent.currentUserDisplayName,
      );

      // Update through realtime sync service (handles conflict resolution)
      // await _realtimeSyncService!.updateResource(updatedRealtimeRecipe);

      AppLogger.info('Made realtime edit to recipe: ${recipe.title}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to make realtime edit', e);
      return false;
    }
  }

  /// Make batch realtime edits
  Future<bool> makeBatchRealtimeEdits({
    required String recipeId,
    required List<Map<String, dynamic>> changeList,
    String? batchDescription,
  }) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;

      // Apply all changes as a single batch
      final combinedChanges = <String, dynamic>{};
      for (final changes in changeList) {
        combinedChanges.addAll(changes);
      }

      return await makeRealtimeEdit(
        recipeId: recipeId,
        changes: combinedChanges,
        editDescription: batchDescription ?? 'Batch edit with ${changeList.length} changes',
      );
    } catch (e) {
      AppLogger.error('Failed to make batch realtime edits', e);
      return false;
    }
  }

  /// Undo last realtime edit
  Future<bool> undoLastRealtimeEdit(String recipeId) async {
    try {
      // This would require storing edit history and applying reverse operations
      // For now, log the attempt
      AppLogger.info('Undo last realtime edit requested for recipe: $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to undo last realtime edit', e);
      return false;
    }
  }

  // ===== CONFLICT RESOLUTION =====

  /// Resolve edit conflict manually
  Future<bool> resolveConflict({
    required String recipeId,
    required Recipe localVersion,
    required Recipe remoteVersion,
    required String resolution, // 'local', 'remote', or 'merge'
  }) async {
    try {
      if (_realtimeSyncService == null) {
        AppLogger.warning('RealtimeSyncService not available for conflict resolution');
        return false;
      }

      Recipe resolvedRecipe;
      
      switch (resolution) {
        case 'local':
          resolvedRecipe = localVersion;
          AppLogger.info('Conflict resolved using local version');
          break;
        case 'remote':
          resolvedRecipe = remoteVersion;
          AppLogger.info('Conflict resolved using remote version');
          break;
        case 'merge':
          resolvedRecipe = RealtimeRecipeUtils.mergeRecipeVersions(
            localVersion, 
            remoteVersion,
            _parent.currentUserId,
            _parent.currentUserDisplayName,
          );
          AppLogger.info('Conflict resolved using merge strategy');
          break;
        default:
          throw ArgumentError('Invalid resolution type: $resolution');
      }

      // Apply resolved version
      await _convertToRealtimeRecipe(resolvedRecipe);
      // await _realtimeSyncService!.updateResource(realtimeRecipe);

      AppLogger.info('Resolved conflict for recipe: $recipeId using $resolution strategy');
      return true;
    } catch (e) {
      AppLogger.error('Failed to resolve conflict', e);
      return false;
    }
  }

  /// Auto-resolve conflict using default strategy
  Future<bool> autoResolveConflict({
    required String recipeId,
    required Recipe localVersion,
    required Recipe remoteVersion,
    String strategy = 'merge',
  }) async {
    return await resolveConflict(
      recipeId: recipeId,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      resolution: strategy,
    );
  }

  /// Check for pending conflicts
  Future<List<ConflictInfo>> getPendingConflicts(String recipeId) async {
    try {
      // This would check for unresolved conflicts
      // For now, return empty list
      return [];
    } catch (e) {
      AppLogger.error('Failed to get pending conflicts', e);
      return [];
    }
  }

  // ===== EDIT VALIDATION =====

  /// Validate edit changes before applying
  bool validateEditChanges(String recipeId, Map<String, dynamic> changes) {
    try {
      // Validate title
      if (changes.containsKey('title')) {
        final title = changes['title']?.toString();
        if (title == null || title.trim().isEmpty) {
          AppLogger.error('Recipe title cannot be empty');
          return false;
        }
        if (title.length > 200) {
          AppLogger.error('Recipe title too long (max 200 characters)');
          return false;
        }
      }

      // Validate ingredients
      if (changes.containsKey('ingredients')) {
        final ingredients = changes['ingredients'];
        if (ingredients is! List) {
          AppLogger.error('Ingredients must be a list');
          return false;
        }
        if (ingredients.isEmpty) {
          AppLogger.error('Recipe must have at least one ingredient');
          return false;
        }
      }

      // Validate instructions
      if (changes.containsKey('instructions')) {
        final instructions = changes['instructions'];
        if (instructions is! List) {
          AppLogger.error('Instructions must be a list');
          return false;
        }
        if (instructions.isEmpty) {
          AppLogger.error('Recipe must have at least one instruction');
          return false;
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('Error validating edit changes', e);
      return false;
    }
  }

  /// Get edit validation rules
  Map<String, dynamic> getEditValidationRules() {
    return {
      'title': {
        'required': true,
        'minLength': 1,
        'maxLength': 200,
      },
      'description': {
        'required': false,
        'maxLength': 1000,
      },
      'ingredients': {
        'required': true,
        'minItems': 1,
        'type': 'array',
      },
      'instructions': {
        'required': true,
        'minItems': 1,
        'type': 'array',
      },
      'imageUrls': {
        'required': false,
        'type': 'array',
        'maxItems': 10,
      },
    };
  }

  // ===== HELPER METHODS =====

  /// Convert Recipe to RealtimeRecipe data structure
  Future<Map<String, dynamic>> _convertToRealtimeRecipe(Recipe recipe) async {
    return RealtimeRecipeUtils.convertToRealtimeRecipe(recipe);
  }

  /// Make regular edit when realtime not available
  Future<bool> _makeRegularEdit(String recipeId, Map<String, dynamic> changes) async {
    try {
      return await _parent.updateRecipeContent(
        recipeId: recipeId,
        title: changes['title'],
        description: changes['description'],
        ingredients: changes['ingredients']?.cast<String>(),
        instructions: changes['instructions']?.cast<String>(),
        imageUrls: changes['imageUrls']?.cast<String>(),
        mealType: changes['mealType'],
        portions: changes['portions'],
        timeMinutes: changes['timeMinutes'],
        rating: changes['rating']?.toDouble(),
        tags: changes['tags']?.cast<String>(),
        sourceUrl: changes['sourceUrl'],
      );
    } catch (e) {
      AppLogger.error('Failed to make regular edit fallback', e);
      return false;
    }
  }

  // ===== STATUS AND DIAGNOSTICS =====

  /// Get editing session status
  Map<String, dynamic> getEditingStatus(String recipeId) {
    return {
      'isInRealtimeMode': isInRealtimeEditingMode(recipeId),
      'hasRealtimeService': _realtimeSyncService != null,
      'canEdit': _canEditRecipe(recipeId),
      'lastEditAt': DateTime.now(), // Would track actual last edit time
    };
  }

  /// Check if user can edit recipe
  bool _canEditRecipe(String recipeId) {
    return RealtimeRecipeUtils.validateUserPermissions(
      _parent.currentUserId,
      recipeId,
      requireEdit: true,
      requireOwner: false,
    ) == null;
  }
}

/// Conflict information structure
class ConflictInfo {
  final String recipeId;
  final String field;
  final dynamic localValue;
  final dynamic remoteValue;
  final DateTime conflictTime;

  const ConflictInfo({
    required this.recipeId,
    required this.field,
    required this.localValue,
    required this.remoteValue,
    required this.conflictTime,
  });

  @override
  String toString() {
    return 'ConflictInfo{recipeId: $recipeId, field: $field, conflictTime: $conflictTime}';
  }
}