// lib/services/unified/modules/realtime_editor_tracker.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for real-time editor tracking
/// 
/// This module handles ONLY active editor management:
/// - Editor registration and presence tracking
/// - Active editor queries and status
/// - Editor presence heartbeat management
/// - Collaborative editing indicators
/// 
/// ❌ DOES NOT CONTAIN: Session management, content operations, conflict resolution, event handling
class RealtimeEditorTracker {

  // ===== EDITOR REGISTRATION =====

  /// Register/unregister user as active editor
  static Future<void> registerActiveEditor({
    required FirebaseFirestore firestore,
    required String recipeId,
    required bool isActive,
    required String currentUserId,
    required String? currentUserDisplayName,
  }) async {
    try {
      final activeEditorsRef = firestore
          .collection('unified_collaborative_recipes')
          .doc(recipeId);

      if (isActive) {
        await activeEditorsRef.update({
          'activeEditors.$currentUserId': {
            'displayName': currentUserDisplayName ?? 'Okänd användare',
            'startedAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
          }
        });
        
        AppLogger.debug('✅ Registered as active editor for recipe $recipeId');
      } else {
        await activeEditorsRef.update({
          'activeEditors.$currentUserId': FieldValue.delete(),
        });
        
        AppLogger.debug('✅ Unregistered as active editor for recipe $recipeId');
      }
    } catch (e) {
      AppLogger.error('❌ Error registering active editor: $e');
      rethrow;
    }
  }

  /// Update last seen timestamp for active editor
  static Future<void> updateActiveEditorPresence({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String currentUserId,
  }) async {
    try {
      await firestore
          .collection('unified_collaborative_recipes')
          .doc(recipeId)
          .update({
        'activeEditors.$currentUserId.lastSeen': FieldValue.serverTimestamp(),
      });
      
      AppLogger.debug('Updated presence for user $currentUserId in recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Error updating editor presence: $e');
      // Don't rethrow for presence updates - they're not critical
    }
  }

  /// Batch update presence for multiple recipes
  static Future<void> updatePresenceForMultipleRecipes({
    required FirebaseFirestore firestore,
    required List<String> recipeIds,
    required String currentUserId,
  }) async {
    try {
      final batch = firestore.batch();
      
      for (final recipeId in recipeIds) {
        final docRef = firestore
            .collection('unified_collaborative_recipes')
            .doc(recipeId);
            
        batch.update(docRef, {
          'activeEditors.$currentUserId.lastSeen': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      AppLogger.debug('Updated presence for ${recipeIds.length} recipes');
    } catch (e) {
      AppLogger.error('❌ Error updating batch presence: $e');
    }
  }

  // ===== EDITOR QUERIES =====

  /// Get active editors for a recipe
  static Future<List<Map<String, dynamic>>> getActiveEditors({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      final snapshot = await firestore
          .collection('unified_collaborative_recipes')
          .doc(recipeId)
          .get();

      if (!snapshot.exists) {
        AppLogger.warning('Recipe $recipeId not found when getting active editors');
        return [];
      }

      final data = snapshot.data()!;
      final activeEditorsData = data['activeEditors'] as Map<String, dynamic>? ?? {};
      
      final activeEditors = <Map<String, dynamic>>[];
      for (final entry in activeEditorsData.entries) {
        final userId = entry.key;
        final editorData = entry.value as Map<String, dynamic>;
        
        activeEditors.add({
          'userId': userId,
          'displayName': editorData['displayName'] ?? 'Okänd användare',
          'startedAt': editorData['startedAt'],
          'lastSeen': editorData['lastSeen'],
          'isCurrentlyActive': _isEditorCurrentlyActive(editorData['lastSeen']),
        });
      }

      // Sort by most recently active first
      activeEditors.sort((a, b) {
        final aTime = a['lastSeen'] as Timestamp?;
        final bTime = b['lastSeen'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return activeEditors;
    } catch (e) {
      AppLogger.error('❌ Error getting active editors: $e');
      return [];
    }
  }

  /// Get currently active editors (seen within last minute)
  static Future<List<Map<String, dynamic>>> getCurrentlyActiveEditors({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    final allEditors = await getActiveEditors(
      firestore: firestore,
      recipeId: recipeId,
    );

    return allEditors
        .where((editor) => editor['isCurrentlyActive'] as bool? ?? false)
        .toList();
  }

  /// Get editor count for recipe
  static Future<int> getActiveEditorCount({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    final activeEditors = await getCurrentlyActiveEditors(
      firestore: firestore,
      recipeId: recipeId,
    );
    
    return activeEditors.length;
  }

  /// Check if specific user is actively editing
  static Future<bool> isUserActivelyEditing({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String userId,
  }) async {
    try {
      final snapshot = await firestore
          .collection('unified_collaborative_recipes')
          .doc(recipeId)
          .get();

      if (!snapshot.exists) return false;

      final data = snapshot.data()!;
      final activeEditorsData = data['activeEditors'] as Map<String, dynamic>? ?? {};
      final editorData = activeEditorsData[userId] as Map<String, dynamic>?;
      
      if (editorData == null) return false;
      
      return _isEditorCurrentlyActive(editorData['lastSeen']);
    } catch (e) {
      AppLogger.error('❌ Error checking if user is actively editing: $e');
      return false;
    }
  }

  // ===== EDITOR STATUS HELPERS =====

  /// Check if editor is currently active based on last seen timestamp
  static bool _isEditorCurrentlyActive(dynamic lastSeen) {
    if (lastSeen == null) return false;
    
    try {
      final lastSeenTime = (lastSeen as Timestamp).toDate();
      final now = DateTime.now();
      final timeSinceLastSeen = now.difference(lastSeenTime);
      
      // Consider active if seen within last 60 seconds
      return timeSinceLastSeen.inSeconds <= 60;
    } catch (e) {
      return false;
    }
  }

  /// Get editor activity status
  static String getEditorActivityStatus(Map<String, dynamic> editorData) {
    final lastSeen = editorData['lastSeen'] as Timestamp?;
    if (lastSeen == null) return 'unknown';
    
    final lastSeenTime = lastSeen.toDate();
    final now = DateTime.now();
    final timeSinceLastSeen = now.difference(lastSeenTime);
    
    if (timeSinceLastSeen.inSeconds <= 30) {
      return 'actively_editing';
    } else if (timeSinceLastSeen.inSeconds <= 60) {
      return 'recently_active';
    } else if (timeSinceLastSeen.inMinutes <= 5) {
      return 'away';
    } else {
      return 'inactive';
    }
  }

  /// Get editor session duration
  static Duration? getEditorSessionDuration(Map<String, dynamic> editorData) {
    final startedAt = editorData['startedAt'] as Timestamp?;
    final lastSeen = editorData['lastSeen'] as Timestamp?;
    
    if (startedAt == null || lastSeen == null) return null;
    
    return lastSeen.toDate().difference(startedAt.toDate());
  }

  // ===== PRESENCE MANAGEMENT =====

  /// Start presence heartbeat for active editing
  static void startPresenceHeartbeat({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String currentUserId,
    required void Function() onHeartbeatError,
  }) {
    // Note: This would typically use a timer to send periodic heartbeats
    // For now, it's the caller's responsibility to call updateActiveEditorPresence periodically
    AppLogger.debug('Presence heartbeat started for recipe $recipeId');
  }

  /// Stop presence heartbeat
  static void stopPresenceHeartbeat({
    required String recipeId,
    required String currentUserId,
  }) {
    AppLogger.debug('Presence heartbeat stopped for recipe $recipeId');
  }

  // ===== EDITOR CLEANUP =====

  /// Clean up inactive editors
  static Future<int> cleanupInactiveEditors({
    required FirebaseFirestore firestore,
    required String recipeId,
    Duration inactiveThreshold = const Duration(minutes: 10),
  }) async {
    try {
      final allEditors = await getActiveEditors(
        firestore: firestore,
        recipeId: recipeId,
      );

      final now = DateTime.now();
      final inactiveEditors = <String>[];

      for (final editor in allEditors) {
        final lastSeen = editor['lastSeen'] as Timestamp?;
        if (lastSeen != null) {
          final timeSinceLastSeen = now.difference(lastSeen.toDate());
          if (timeSinceLastSeen > inactiveThreshold) {
            inactiveEditors.add(editor['userId'] as String);
          }
        } else {
          // No last seen timestamp - consider inactive
          inactiveEditors.add(editor['userId'] as String);
        }
      }

      // Remove inactive editors
      if (inactiveEditors.isNotEmpty) {
        final batch = firestore.batch();
        final docRef = firestore
            .collection('unified_collaborative_recipes')
            .doc(recipeId);

        for (final userId in inactiveEditors) {
          batch.update(docRef, {
            'activeEditors.$userId': FieldValue.delete(),
          });
        }

        await batch.commit();
        AppLogger.info('🧹 Cleaned up ${inactiveEditors.length} inactive editors from recipe $recipeId');
      }

      return inactiveEditors.length;
    } catch (e) {
      AppLogger.error('❌ Error cleaning up inactive editors: $e');
      return 0;
    }
  }

  /// Remove all editors for a recipe
  static Future<void> removeAllEditorsForRecipe({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      await firestore
          .collection('unified_collaborative_recipes')
          .doc(recipeId)
          .update({
        'activeEditors': FieldValue.delete(),
      });
      
      AppLogger.info('🧹 Removed all editors for recipe $recipeId');
    } catch (e) {
      AppLogger.error('❌ Error removing all editors: $e');
    }
  }

  // ===== EDITOR ANALYTICS =====

  /// Get editor statistics for recipe
  static Future<Map<String, dynamic>> getEditorStatistics({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    try {
      final allEditors = await getActiveEditors(
        firestore: firestore,
        recipeId: recipeId,
      );

      final currentlyActive = allEditors
          .where((editor) => editor['isCurrentlyActive'] as bool? ?? false)
          .length;

      final totalSessions = allEditors.length;
      
      // Calculate average session duration
      final sessionsWithDuration = allEditors
          .map((editor) => getEditorSessionDuration(editor))
          .where((duration) => duration != null)
          .cast<Duration>()
          .toList();

      final averageSessionDuration = sessionsWithDuration.isNotEmpty
          ? Duration(
              seconds: sessionsWithDuration
                  .map((d) => d.inSeconds)
                  .reduce((a, b) => a + b) ~/ sessionsWithDuration.length,
            )
          : Duration.zero;

      // Group by activity status
      final statusCounts = <String, int>{};
      for (final editor in allEditors) {
        final status = getEditorActivityStatus(editor);
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return {
        'total_editors': totalSessions,
        'currently_active': currentlyActive,
        'average_session_duration_minutes': averageSessionDuration.inMinutes,
        'status_breakdown': statusCounts,
        'has_collaborative_activity': currentlyActive > 1,
      };
    } catch (e) {
      AppLogger.error('❌ Error getting editor statistics: $e');
      return {
        'total_editors': 0,
        'currently_active': 0,
        'average_session_duration_minutes': 0,
        'status_breakdown': <String, int>{},
        'has_collaborative_activity': false,
      };
    }
  }

  /// Check if recipe has collaborative editing activity
  static Future<bool> hasCollaborativeActivity({
    required FirebaseFirestore firestore,
    required String recipeId,
  }) async {
    final activeCount = await getActiveEditorCount(
      firestore: firestore,
      recipeId: recipeId,
    );
    
    return activeCount > 1;
  }

  /// Get editor activity summary
  static String getEditorActivitySummary(List<Map<String, dynamic>> editors) {
    if (editors.isEmpty) return 'Inga aktiva redaktörer';
    
    final activeEditors = editors
        .where((editor) => editor['isCurrentlyActive'] as bool? ?? false)
        .toList();
    
    if (activeEditors.isEmpty) {
      return 'Inga aktiva redaktörer just nu';
    } else if (activeEditors.length == 1) {
      final editor = activeEditors.first;
      return '${editor['displayName']} redigerar just nu';
    } else {
      return '${activeEditors.length} personer redigerar just nu';
    }
  }
}