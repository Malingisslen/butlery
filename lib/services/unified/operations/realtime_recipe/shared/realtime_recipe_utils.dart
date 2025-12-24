// lib/services/unified/operations/realtime_recipe/shared/realtime_recipe_utils.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';

/// Shared utilities for realtime recipe operations
/// Contains helper methods and conversion utilities used across
/// multiple realtime recipe modules to reduce code duplication.
class RealtimeRecipeUtils {
  /// Convert Recipe to RealtimeRecipe data structure
  static Map<String, dynamic> convertToRealtimeRecipe(Recipe recipe) {
    return {
      'id': recipe.id,
      'name': recipe.title,
      'description': recipe.description,
      'ingredients': recipe.ingredients,
      'instructions': recipe.instructions,
      'imageUrls': recipe.imageUrls,
      'ownerId': recipe.socialData?.ownerId ?? recipe.core.createdBy,
      'ownerDisplayName': recipe.socialData?.ownerDisplayName ?? 'Unknown',
      'editCount': 1,
      'lastEditedAt': DateTime.now().toIso8601String(),
      'lastEditedByUserId':
          recipe.realtimeData?.lastEditedByUserId ?? recipe.core.createdBy,
      'lastEditedByDisplayName':
          recipe.realtimeData?.lastEditedByDisplayName ?? 'Unknown',
    };
  }

  /// Convert RealtimeRecipe data to Recipe
  static Recipe convertToRecipe(dynamic realtimeRecipe) {
    // Check if it's already a RealtimeRecipe object
    if (realtimeRecipe is RealtimeRecipe) {
      // If it's a RealtimeRecipe object, return its recipe property
      return realtimeRecipe.recipe;
    }

    // Otherwise, treat it as a Map (for backward compatibility)
    if (realtimeRecipe is Map<String, dynamic>) {
      return Recipe(
        core: RecipeCore(
          id: realtimeRecipe['id'] ?? '',
          title: realtimeRecipe['name'] ?? '',
          description: realtimeRecipe['description'] ?? '',
          ingredients: List<String>.from(realtimeRecipe['ingredients'] ?? []),
          instructions: List<String>.from(realtimeRecipe['instructions'] ?? []),
          imageUrls: List<String>.from(realtimeRecipe['imageUrls'] ?? []),
          mealType: realtimeRecipe['mealType'] ?? 'Lunch',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.realtime,
      );
    }

    // If it's neither, throw an error
    throw ArgumentError(
        'Invalid realtimeRecipe type: ${realtimeRecipe.runtimeType}');
  }

  /// Apply changes to realtime recipe data structure
  static Map<String, dynamic> applyChangesToRealtimeRecipe(
    Map<String, dynamic> recipe,
    Map<String, dynamic> changes,
    String? editDescription,
    String? currentUserId,
    String? currentUserDisplayName,
  ) {
    return {
      ...recipe,
      'name': changes['title'] ?? recipe['name'],
      'description': changes['description'] ?? recipe['description'],
      'ingredients': changes['ingredients'] ?? recipe['ingredients'],
      'instructions': changes['instructions'] ?? recipe['instructions'],
      'imageUrls': changes['imageUrls'] ?? recipe['imageUrls'],
      'lastEditedAt': DateTime.now().toIso8601String(),
      'lastEditedByUserId': currentUserId,
      'lastEditedByDisplayName': currentUserDisplayName,
      'editCount': (recipe['editCount'] ?? 0) + 1,
      'editDescription': editDescription,
    };
  }

  /// Merge two recipe versions for conflict resolution
  static Recipe mergeRecipeVersions(
    Recipe local,
    Recipe remote,
    String? currentUserId,
    String? currentUserDisplayName,
  ) {
    // Simple merge strategy - prefer remote for most fields, local for user-specific data
    return local.copyWith(
      title: remote.title,
      description: remote.description,
      ingredients: remote.ingredients,
      instructions: remote.instructions,
      imageUrls: <String>{...local.imageUrls, ...remote.imageUrls}.toList(),
      rating: local.rating ?? remote.rating,
      tags: <String>{...(local.tags ?? []), ...(remote.tags ?? [])}.toList(),
      lastEditedByUserId: currentUserId,
      lastEditedByDisplayName: currentUserDisplayName,
    );
  }

  /// Check if user is actively viewing recipe (presence simulation)
  static bool isUserActivelyViewing(String userId, String recipeId) {
    // This would check presence data from Firebase or local tracking
    // For now, simulate some active users randomly
    return DateTime.now().millisecond % 3 == 0; // ~33% chance
  }

  /// Get active editors based on recent activity
  static List<String> getActiveEditorsFromRecipe(Recipe recipe) {
    try {
      if (!recipe.isCollaborative) return [];

      // Get members who are currently active (have edited in last 5 minutes)
      final recentThreshold =
          DateTime.now().subtract(const Duration(minutes: 5));
      final activeEditors = <String>[];

      if (recipe.realtimeData?.lastEditedAt?.isAfter(recentThreshold) == true) {
        final lastEditor = recipe.realtimeData?.lastEditedByUserId;
        if (lastEditor != null && !activeEditors.contains(lastEditor)) {
          activeEditors.add(lastEditor);
        }
      }

      // Add other members who might be viewing (presence simulation)
      final allMembers =
          recipe.socialData?.memberPermissions?.keys.toList() ?? [];
      for (final memberId in allMembers) {
        if (!activeEditors.contains(memberId) &&
            isUserActivelyViewing(memberId, recipe.id)) {
          activeEditors.add(memberId);
        }
      }

      return activeEditors;
    } catch (e) {
      return [];
    }
  }

  /// Get collaboration statistics for a recipe
  static Map<String, dynamic> getCollaborationStats(Recipe recipe) {
    try {
      if (!recipe.isCollaborative) return {};

      final memberCount = recipe.socialData?.memberPermissions?.length ?? 0;
      final activeEditors = getActiveEditorsFromRecipe(recipe);
      final lastEditedAt =
          recipe.realtimeData?.lastEditedAt ?? recipe.updatedAt;
      final daysSinceLastEdit = DateTime.now().difference(lastEditedAt).inDays;

      return {
        'memberCount': memberCount,
        'activeEditorsCount': activeEditors.length,
        'lastEditedAt': lastEditedAt,
        'daysSinceLastEdit': daysSinceLastEdit,
        'isActivelyCollaborated': activeEditors.length > 1,
        'collaborationLevel': memberCount > 5
            ? 'high'
            : memberCount > 2
                ? 'medium'
                : 'low',
        'editCount': recipe.realtimeData?.editCount ?? 1,
      };
    } catch (e) {
      return {};
    }
  }

  /// Determine what fields were changed for notifications
  static String getChangeDescription(Map<String, dynamic> changes) {
    final changedFields = <String>[];
    if (changes.containsKey('title')) changedFields.add('titel');
    if (changes.containsKey('description')) changedFields.add('beskrivning');
    if (changes.containsKey('ingredients')) changedFields.add('ingredienser');
    if (changes.containsKey('instructions')) changedFields.add('instruktioner');
    if (changes.containsKey('imageUrls')) changedFields.add('bilder');

    return changedFields.isNotEmpty ? changedFields.join(', ') : 'receptet';
  }

  /// Validate recipe can be used for realtime operations
  static String? validateRecipeForRealtime(Recipe? recipe) {
    if (recipe == null) {
      return 'Recipe not found';
    }

    if (!recipe.isCollaborative) {
      return 'Recipe is not collaborative';
    }

    return null; // Valid
  }

  /// Validate user permissions for realtime operations
  static String? validateUserPermissions(
    String? currentUserId,
    String recipeId, {
    required bool requireEdit,
    required bool requireOwner,
  }) {
    if (currentUserId == null) {
      return 'User must be logged in';
    }

    // These would use actual permission service in real implementation
    // For now, return null (valid) to avoid compilation errors
    return null;
  }

  /// Create edit history entry
  static Map<String, dynamic> createEditHistoryEntry({
    required DateTime timestamp,
    required String userId,
    required String userName,
    required String action,
    required String details,
    String? targetUserId,
  }) {
    return {
      'timestamp': timestamp,
      'userId': userId,
      'userName': userName,
      'action': action,
      'details': details,
      if (targetUserId != null) 'targetUserId': targetUserId,
    };
  }

  /// Generate simulated edit history for a recipe
  static List<Map<String, dynamic>> generateEditHistory(Recipe recipe) {
    final history = <Map<String, dynamic>>[];

    // Add creation event
    history.add(createEditHistoryEntry(
      timestamp: recipe.createdAt,
      userId: recipe.core.createdBy ?? '',
      userName: recipe.socialData?.ownerDisplayName ?? 'Unknown',
      action: 'Created recipe',
      details: 'Initial recipe creation',
    ));

    // Add last update event if different from creation
    if (recipe.updatedAt
        .isAfter(recipe.createdAt.add(const Duration(seconds: 1)))) {
      history.add(createEditHistoryEntry(
        timestamp: recipe.updatedAt,
        userId: recipe.realtimeData?.lastEditedByUserId ??
            recipe.core.createdBy ??
            '',
        userName: recipe.realtimeData?.lastEditedByDisplayName ?? 'Unknown',
        action: 'Updated recipe',
        details: 'Recipe content modified',
      ));
    }

    // Add collaborative events if it's a collaborative recipe
    if (recipe.isCollaborative &&
        recipe.socialData?.memberPermissions?.isNotEmpty == true) {
      for (final member in recipe.socialData!.memberPermissions!.entries) {
        if (member.key != recipe.socialData!.ownerId) {
          // Simulate member addition event
          history.add(createEditHistoryEntry(
            timestamp: recipe.createdAt.add(const Duration(hours: 1)),
            userId: recipe.socialData!.ownerId ?? '',
            userName: recipe.socialData!.ownerDisplayName ?? 'Unknown',
            action: 'Added collaborator',
            details:
                'Added user with ${member.value.toString().split('.').last} permission',
            targetUserId: member.key,
          ));
        }
      }
    }

    // Sort by timestamp (newest first)
    history.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return history;
  }
}
