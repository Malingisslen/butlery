// lib/services/unified/modules/realtime_editor_tracker.dart

import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:clock/clock.dart';
import 'package:get_it/get_it.dart';

/// Focused module for real-time editor tracking
/// This module handles ONLY active editor management:
/// - Editor registration and presence tracking
/// - Active editor queries and status
/// - Editor presence heartbeat management
/// - Collaborative editing indicators
/// ❌ DOES NOT CONTAIN: Session management, content operations, conflict resolution, event handling
class RealtimeEditorTracker {
  /// Register/unregister user as active editor
  static Future<void> registerActiveEditor({
    required String recipeId,
    required bool isActive,
    required String currentUserId,
    required String? currentUserDisplayName,
  }) async {
    try {
      final collaborativeRepo = GetIt.instance<CollaborativeRecipeRepository>();

      if (isActive) {
        await collaborativeRepo.setPresence(recipeId, currentUserId, {
          'displayName': currentUserDisplayName ?? '?',
          'isActive': true,
          'lastSeen': clock.now().toIso8601String(),
        });
        AppLogger.debug('✅ Registered as active editor for recipe $recipeId');
      } else {
        await collaborativeRepo.removePresence(recipeId, currentUserId);
        AppLogger.debug('✅ Unregistered as active editor for recipe $recipeId');
      }
    } catch (e) {
      AppLogger.error('❌ Error registering active editor: $e');
      rethrow;
    }
  }

  /// Update last seen timestamp for active editor
  static Future<void> updateActiveEditorPresence({
    required String recipeId,
    required String currentUserId,
  }) async {
    try {
      final collaborativeRepo = GetIt.instance<CollaborativeRecipeRepository>();
      await collaborativeRepo.updatePresenceHeartbeat(recipeId, currentUserId);
      AppLogger.debug(
          'Updated presence for user $currentUserId in recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Error updating editor presence: $e');
      // Don't rethrow for presence updates - they're not critical
    }
  }

  /// Batch update presence for multiple recipes
  static Future<void> updatePresenceForMultipleRecipes({
    required List<String> recipeIds,
    required String currentUserId,
  }) async {
    try {
      // For now, call individual presence updates
      for (final recipeId in recipeIds) {
        await updateActiveEditorPresence(
          recipeId: recipeId,
          currentUserId: currentUserId,
        );
      }
      AppLogger.debug('Updated presence for ${recipeIds.length} recipes');
    } catch (e) {
      AppLogger.error('❌ Error updating batch presence: $e');
    }
  }

  /// Get active editors for a recipe
  static Future<List<Map<String, dynamic>>> getActiveEditors({
    required String recipeId,
  }) async {
    try {
      final collaborativeRepo = GetIt.instance<CollaborativeRecipeRepository>();
      final editors = await collaborativeRepo.getActiveEditors(recipeId);
      AppLogger.debug(
          'Retrieved ${editors.length} active editors for recipe $recipeId');
      return editors;
    } catch (e) {
      AppLogger.error('❌ Error getting active editors: $e');
      return [];
    }
  }

  /// Get currently active editors (seen within last minute)
  static Future<List<Map<String, dynamic>>> getCurrentlyActiveEditors({
    required String recipeId,
  }) async {
    final allEditors = await getActiveEditors(
      recipeId: recipeId,
    );

    return allEditors
        .where((editor) => editor['isCurrentlyActive'] as bool? ?? false)
        .toList();
  }

  /// Get editor count for recipe
  static Future<int> getActiveEditorCount({
    required String recipeId,
  }) async {
    final activeEditors = await getCurrentlyActiveEditors(
      recipeId: recipeId,
    );

    return activeEditors.length;
  }

  /// Check if specific user is actively editing
  static Future<bool> isUserActivelyEditing({
    required String recipeId,
    required String userId,
  }) async {
    try {
      final collaborativeRepo = GetIt.instance<CollaborativeRecipeRepository>();
      final isActive =
          await collaborativeRepo.isUserActivelyEditing(recipeId, userId);
      AppLogger.debug(
          'User $userId actively editing recipe $recipeId: $isActive');
      return isActive;
    } catch (e) {
      AppLogger.error('❌ Error checking if user is actively editing: $e');
      return false;
    }
  }

  /// Get editor statistics for a recipe
  static Future<Map<String, dynamic>> getEditorStatistics({
    required String recipeId,
  }) async {
    try {
      final editorCount = await getActiveEditorCount(recipeId: recipeId);
      return {
        'activeEditorCount': editorCount,
        'hasActiveEditors': editorCount > 0,
        'lastUpdated': clock.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('❌ Error getting editor statistics: $e');
      return {'activeEditorCount': 0, 'hasActiveEditors': false};
    }
  }

  /// Check if recipe has collaborative activity
  static Future<bool> hasCollaborativeActivity({
    required String recipeId,
  }) async {
    try {
      final editorCount = await getActiveEditorCount(recipeId: recipeId);
      return editorCount > 1; // More than one person editing
    } catch (e) {
      AppLogger.error('❌ Error checking collaborative activity: $e');
      return false;
    }
  }

  /// Clean up inactive editors
  static Future<void> cleanupInactiveEditors({
    required String recipeId,
  }) async {
    try {
      final collaborativeRepo = GetIt.instance<CollaborativeRecipeRepository>();
      await collaborativeRepo.cleanupInactiveEditors(recipeId);
      AppLogger.debug('Cleaned up inactive editors for recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Error cleaning up inactive editors: $e');
    }
  }
}
