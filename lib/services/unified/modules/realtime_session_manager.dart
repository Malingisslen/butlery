// lib/services/unified/modules/realtime_session_manager.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for real-time editing session management
/// 
/// This module handles ONLY session lifecycle operations:
/// - Starting and stopping real-time editing sessions
/// - Session state tracking and validation
/// - Firebase stream subscription management
/// - Session cleanup and resource management
/// 
/// ❌ DOES NOT CONTAIN: Content operations, conflict resolution, editor tracking, event handling
class RealtimeSessionManager {

  // ===== SESSION LIFECYCLE MANAGEMENT =====

  /// Start real-time editing session for a recipe
  static Future<bool> startRealtimeEditing({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String currentUserId,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required void Function(DocumentSnapshot) onRealtimeChange,
    required void Function(String, dynamic) onRealtimeError,
    required Future<void> Function(String, bool) registerActiveEditor,
    required void Function(String) setError,
  }) async {
    try {
      // Check if already in editing session
      if (activeEditingSessions.containsKey(recipeId)) {
        AppLogger.debug('Already in editing session for recipe $recipeId');
        return true;
      }

      // Start listening to real-time changes
      // ignore: cancel_subscriptions - stored and cancelled by caller
      final subscription = firestore
          .collection('unified_collaborative_recipes')
          .doc(recipeId)
          .snapshots()
          .listen(
            onRealtimeChange,
            onError: (error) => onRealtimeError(recipeId, error),
          );

      activeEditingSessions[recipeId] = subscription;

      // Register user as active editor
      await registerActiveEditor(recipeId, true);

      AppLogger.success('✅ Started real-time editing for recipe $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not start real-time editing: $e');
      setError('Kunde inte starta realtidsredigering: $e');
      return false;
    }
  }

  /// Stop real-time editing session for a recipe
  static Future<bool> stopRealtimeEditing({
    required String recipeId,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
    required Future<void> Function(String, bool) registerActiveEditor,
  }) async {
    try {
      // Cancel active subscription
      final subscription = activeEditingSessions.remove(recipeId);
      await subscription?.cancel();

      // Clear pending edits for this recipe
      pendingRealtimeEdits.remove(recipeId);

      // Cancel any conflict resolution timers
      conflictResolutionTimers[recipeId]?.cancel();
      conflictResolutionTimers.remove(recipeId);

      // Unregister user as active editor
      await registerActiveEditor(recipeId, false);

      AppLogger.success('✅ Stopped real-time editing for recipe $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not stop real-time editing: $e');
      return false;
    }
  }

  /// Stop all active real-time editing sessions
  static Future<void> stopAllRealtimeSessions({
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
    required Future<void> Function(String, bool) registerActiveEditor,
  }) async {
    try {
      AppLogger.info('🛑 Stopping ${activeEditingSessions.length} active real-time sessions');

      // Stop all sessions
      final futures = activeEditingSessions.keys.toList().map((recipeId) =>
        stopRealtimeEditing(
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
          registerActiveEditor: registerActiveEditor,
        )
      );

      await Future.wait(futures);
      AppLogger.success('✅ All real-time sessions stopped');
    } catch (e) {
      AppLogger.error('❌ Error stopping real-time sessions: $e');
    }
  }

  // ===== SESSION STATE QUERIES =====

  /// Check if currently in real-time editing session
  static bool isInRealtimeEditingSession({
    required String recipeId,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
  }) {
    return activeEditingSessions.containsKey(recipeId);
  }

  /// Get all active editing sessions
  static List<String> getActiveEditingSessions(
    Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
  ) {
    return activeEditingSessions.keys.toList();
  }

  /// Get count of active editing sessions
  static int getActiveSessionCount(
    Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
  ) {
    return activeEditingSessions.length;
  }

  /// Check if any sessions are active
  static bool hasActiveSessions(
    Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
  ) {
    return activeEditingSessions.isNotEmpty;
  }

  // ===== SESSION VALIDATION =====

  /// Validate that user can start real-time editing
  static bool canStartRealtimeEditing({
    required String? currentUserId,
    required String recipeId,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
  }) {
    if (currentUserId == null) {
      AppLogger.warning('Cannot start real-time editing: No current user');
      return false;
    }

    if (activeEditingSessions.containsKey(recipeId)) {
      AppLogger.debug('Already in editing session for recipe $recipeId');
      return true; // Already editing is considered valid
    }

    return true;
  }

  /// Validate session before operations
  static bool validateSessionForOperation({
    required String recipeId,
    required String? currentUserId,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required void Function(String) setError,
  }) {
    if (currentUserId == null) {
      setError('Du måste vara inloggad');
      return false;
    }

    if (!activeEditingSessions.containsKey(recipeId)) {
      setError('Inte i realtidsredigeringsläge');
      return false;
    }

    return true;
  }

  // ===== SESSION HEALTH MONITORING =====

  /// Check health of active sessions
  static Map<String, dynamic> checkSessionHealth(
    Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
  ) {
    final healthReport = <String, dynamic>{
      'total_sessions': activeEditingSessions.length,
      'healthy_sessions': 0,
      'problematic_sessions': <String>[],
    };

    for (final entry in activeEditingSessions.entries) {
      final recipeId = entry.key;
      // ignore: cancel_subscriptions - managed by activeEditingSessions
      final subscription = entry.value;

      // Check if subscription is still active
      try {
        if (subscription.isPaused) {
          healthReport['problematic_sessions'].add('$recipeId (paused)');
        } else {
          healthReport['healthy_sessions']++;
        }
      } catch (e) {
        healthReport['problematic_sessions'].add('$recipeId (error: $e)');
      }
    }

    return healthReport;
  }

  /// Cleanup orphaned sessions
  static Future<void> cleanupOrphanedSessions({
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
    required Future<void> Function(String, bool) registerActiveEditor,
  }) async {
    final orphanedSessions = <String>[];

    for (final entry in activeEditingSessions.entries) {
      final recipeId = entry.key;
      // ignore: cancel_subscriptions - managed by activeEditingSessions
      final subscription = entry.value;

      try {
        // Check if subscription is still valid
        if (subscription.isPaused) {
          orphanedSessions.add(recipeId);
        }
      } catch (e) {
        AppLogger.warning('Orphaned session detected for recipe $recipeId: $e');
        orphanedSessions.add(recipeId);
      }
    }

    // Clean up orphaned sessions
    for (final recipeId in orphanedSessions) {
      await stopRealtimeEditing(
        recipeId: recipeId,
        activeEditingSessions: activeEditingSessions,
        pendingRealtimeEdits: pendingRealtimeEdits,
        conflictResolutionTimers: conflictResolutionTimers,
        registerActiveEditor: registerActiveEditor,
      );
    }

    if (orphanedSessions.isNotEmpty) {
      AppLogger.info('🧹 Cleaned up ${orphanedSessions.length} orphaned sessions');
    }
  }

  // ===== SESSION DIAGNOSTICS =====

  /// Get detailed session information
  static Map<String, dynamic> getSessionDiagnostics({
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) {
    final sessionDetails = <String, dynamic>{};

    for (final recipeId in activeEditingSessions.keys) {
      sessionDetails[recipeId] = {
        'has_subscription': activeEditingSessions.containsKey(recipeId),
        'pending_edits_count': pendingRealtimeEdits[recipeId]?.length ?? 0,
        'has_conflict_timer': conflictResolutionTimers.containsKey(recipeId),
        'conflict_timer_active': conflictResolutionTimers[recipeId]?.isActive ?? false,
      };
    }

    return {
      'active_sessions_count': activeEditingSessions.length,
      'total_pending_edits': pendingRealtimeEdits.values
          .fold<int>(0, (total, edits) => total + edits.length),
      'active_conflict_timers': conflictResolutionTimers.values
          .where((timer) => timer.isActive)
          .length,
      'session_details': sessionDetails,
    };
  }

  /// Get session status summary
  static Map<String, dynamic> getSessionStatus({
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
    required Map<String, Timer> conflictResolutionTimers,
  }) {
    return {
      'activeEditingSessions': activeEditingSessions.length,
      'pendingEdits': pendingRealtimeEdits.length,
      'conflictTimers': conflictResolutionTimers.length,
      'recipeIds': activeEditingSessions.keys.toList(),
    };
  }

  // ===== SESSION RECOVERY =====

  /// Attempt to recover failed session
  static Future<bool> recoverSession({
    required FirebaseFirestore firestore,
    required String recipeId,
    required String currentUserId,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required void Function(DocumentSnapshot) onRealtimeChange,
    required void Function(String, dynamic) onRealtimeError,
    required Future<void> Function(String, bool) registerActiveEditor,
    required void Function(String) setError,
  }) async {
    try {
      AppLogger.info('🔄 Attempting to recover session for recipe $recipeId');

      // First, stop any existing problematic session
      await stopRealtimeEditing(
        recipeId: recipeId,
        activeEditingSessions: activeEditingSessions,
        pendingRealtimeEdits: {},
        conflictResolutionTimers: {},
        registerActiveEditor: registerActiveEditor,
      );

      // Wait a moment for cleanup
      await Future.delayed(const Duration(milliseconds: 500));

      // Restart the session
      final success = await startRealtimeEditing(
        firestore: firestore,
        recipeId: recipeId,
        currentUserId: currentUserId,
        activeEditingSessions: activeEditingSessions,
        onRealtimeChange: onRealtimeChange,
        onRealtimeError: onRealtimeError,
        registerActiveEditor: registerActiveEditor,
        setError: setError,
      );

      if (success) {
        AppLogger.success('✅ Successfully recovered session for recipe $recipeId');
      } else {
        AppLogger.error('❌ Failed to recover session for recipe $recipeId');
      }

      return success;
    } catch (e) {
      AppLogger.error('❌ Error during session recovery: $e');
      return false;
    }
  }

  /// Check if session needs recovery
  static bool needsSessionRecovery({
    required String recipeId,
    required Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions,
    required Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits,
  }) {
    final hasSubscription = activeEditingSessions.containsKey(recipeId);
    final hasPendingEdits = pendingRealtimeEdits[recipeId]?.isNotEmpty ?? false;
    
    // Session needs recovery if it has pending edits but no active subscription
    return hasPendingEdits && !hasSubscription;
  }
}