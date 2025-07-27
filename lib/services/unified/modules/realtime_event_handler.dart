// lib/services/unified/modules/realtime_event_handler.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for real-time event handling
/// 
/// This module handles ONLY real-time event processing:
/// - Firebase snapshot change processing
/// - Real-time sync error handling
/// - External edit detection and processing
/// - Real-time notification triggering
/// 
/// ❌ DOES NOT CONTAIN: Session management, content operations, conflict resolution, editor tracking
class RealtimeEventHandler {

  // ===== REAL-TIME CHANGE PROCESSING =====

  /// Handle real-time recipe changes from Firestore
  static void handleRealtimeRecipeChange({
    required DocumentSnapshot snapshot,
    required String? Function() getCurrentUserId,
    required Future<void> Function(Recipe) saveToCache,
    required void Function() notifyListeners,
    required Future<void> Function(String, String?, Map<String, dynamic>) sendRealtimeEditNotification,
  }) {
    try {
      if (!snapshot.exists) {
        AppLogger.debug('Snapshot does not exist for recipe ${snapshot.id}');
        return;
      }

      final recipeId = snapshot.id;
      final data = snapshot.data() as Map<String, dynamic>?;
      
      if (data == null) {
        AppLogger.warning('No data in snapshot for recipe $recipeId');
        return;
      }

      // Check if this change was made by current user
      final editedBy = data['editedBy'] as String?;
      final currentUserId = getCurrentUserId();

      if (editedBy == currentUserId) {
        // This is our own edit, no need to process
        AppLogger.debug('Ignoring own edit for recipe $recipeId');
        return;
      }

      // Process external edit
      AppLogger.debug('Processing external edit for recipe $recipeId by $editedBy');

      // Update local cache
      final recipe = Recipe.fromMap(snapshot.id, snapshot.data()! as Map<String, dynamic>);
      saveToCache(recipe);

      // Notify listeners of the change
      notifyListeners();

      // Send silent notification about the edit
      sendRealtimeEditNotification(recipeId, editedBy, data);
    } catch (e) {
      AppLogger.error('❌ Error handling real-time recipe change: $e');
    }
  }

  /// Process external real-time edit
  static void processExternalEdit({
    required String recipeId,
    required String? editedBy,
    required Map<String, dynamic> data,
    required String? currentUserId,
    required Future<void> Function(Recipe) saveToCache,
    required void Function() notifyListeners,
    required Future<void> Function(String, String?, Map<String, dynamic>) sendRealtimeEditNotification,
  }) {
    try {
      // Validate edit data
      if (!isValidEditData(data)) {
        AppLogger.warning('Invalid edit data received for recipe $recipeId');
        return;
      }

      // Check edit type for appropriate processing
      final editType = data['editType'] as String?;
      AppLogger.debug('Processing external edit of type: $editType for recipe $recipeId');

      // Create recipe from data for caching
      try {
        final recipe = Recipe.fromJson({
          'id': recipeId,
          ...data,
        });
        
        saveToCache(recipe);
      } catch (e) {
        AppLogger.warning('Could not create recipe from edit data: $e');
      }

      // Notify about the change
      notifyListeners();

      // Send notification
      sendRealtimeEditNotification(recipeId, editedBy, data);
    } catch (e) {
      AppLogger.error('❌ Error processing external edit: $e');
    }
  }

  /// Validate edit data structure
  static bool isValidEditData(Map<String, dynamic> data) {
    // Basic validation of edit data
    if (data.isEmpty) return false;
    
    // Check for required fields
    final editedAt = data['editedAt'];
    final editedBy = data['editedBy'];
    
    return editedAt != null && editedBy != null;
  }

  // ===== REAL-TIME ERROR HANDLING =====

  /// Handle real-time synchronization errors
  static void handleRealtimeError({
    required String recipeId,
    required dynamic error,
    required Future<bool> Function(String) stopRealtimeEditing,
    required void Function(String) setError,
  }) {
    AppLogger.error('❌ Real-time sync error for recipe $recipeId: $error');
    
    // Log detailed error information
    _logDetailedError(recipeId, error);
    
    // Stop the problematic session
    stopRealtimeEditing(recipeId);
    
    // Notify user of the error with user-friendly message
    final userMessage = _getUserFriendlyErrorMessage(error);
    setError('Realtidssynkronisering misslyckades: $userMessage');
  }

  /// Handle Firebase permission errors
  static void handlePermissionError({
    required String recipeId,
    required dynamic error,
    required Future<bool> Function(String) stopRealtimeEditing,
    required void Function(String) setError,
  }) {
    AppLogger.error('❌ Permission error for recipe $recipeId: $error');
    
    stopRealtimeEditing(recipeId);
    setError('Du har inte behörighet att redigera detta recept');
  }

  /// Handle network connectivity errors
  static void handleNetworkError({
    required String recipeId,
    required dynamic error,
    required void Function(String) setError,
  }) {
    AppLogger.error('❌ Network error for recipe $recipeId: $error');
    setError('Nätverksfel - kontrollera din internetanslutning');
  }

  /// Log detailed error information for debugging
  static void _logDetailedError(String recipeId, dynamic error) {
    final errorDetails = {
      'recipeId': recipeId,
      'errorType': error.runtimeType.toString(),
      'errorMessage': error.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    AppLogger.error('Detailed real-time error: $errorDetails');
  }

  /// Convert technical error to user-friendly message
  static String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('permission') || errorString.contains('unauthorized')) {
      return 'Behörighet saknas';
    } else if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Nätverksfel';
    } else if (errorString.contains('timeout')) {
      return 'Tidsgräns överskriden';
    } else {
      return 'Tekniskt fel';
    }
  }

  // ===== REAL-TIME NOTIFICATION HANDLING =====

  /// Send silent notification about real-time edit
  static Future<void> sendRealtimeEditNotification({
    required String recipeId,
    required String? editedBy,
    required Map<String, dynamic> data,
  }) async {
    try {
      if (editedBy == null) {
        AppLogger.debug('No editor ID for notification');
        return;
      }

      // Extract edit details for notification
      final editDetails = extractEditDetails(data);
      
      AppLogger.debug('🔔 Real-time edit notification sent for recipe $recipeId by $editedBy: $editDetails');
      
      // Note: Actual notification integration is handled by RealtimeNotificationModule
      // in the RealtimeRecipeModule. This static method is mainly used for logging.
    } catch (e) {
      AppLogger.error('❌ Error sending real-time edit notification: $e');
    }
  }

  /// Extract edit details for notification
  static Map<String, dynamic> extractEditDetails(Map<String, dynamic> data) {
    final editType = data['editType'] as String? ?? 'unknown';
    final field = data['field'] as String? ?? 'unknown';
    final operation = data['operation'] as String?;
    
    return {
      'editType': editType,
      'field': field,
      'operation': operation,
      'editedAt': data['editedAt'],
      'editedByDisplayName': data['editedByDisplayName'],
    };
  }

  /// Check if notification should be sent for edit
  static bool shouldSendNotification({
    required Map<String, dynamic> editData,
    required String? currentUserId,
  }) {
    final editedBy = editData['editedBy'] as String?;
    
    // Don't send notification for own edits
    if (editedBy == currentUserId) return false;
    
    // Don't send for certain edit types
    final editType = editData['editType'] as String?;
    if (editType == 'presence_update') return false;
    
    return true;
  }

  // ===== EVENT STREAM HANDLING =====

  /// Create real-time change listener
  static StreamSubscription<DocumentSnapshot> createRealtimeListener({
    required FirebaseFirestore firestore,
    required String recipeId,
    required void Function(DocumentSnapshot) onRealtimeChange,
    required void Function(String, dynamic) onRealtimeError,
  }) {
    return firestore
        .collection('unified_collaborative_recipes')
        .doc(recipeId)
        .snapshots()
        .listen(
          onRealtimeChange,
          onError: (error) => onRealtimeError(recipeId, error),
        );
  }

  /// Check if snapshot contains valid data
  static bool isValidSnapshot(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return false;
    
    final data = snapshot.data() as Map<String, dynamic>?;
    return data != null && data.isNotEmpty;
  }

  /// Extract recipe ID from snapshot
  static String getRecipeIdFromSnapshot(DocumentSnapshot snapshot) {
    return snapshot.id;
  }

  /// Check if edit should be processed locally
  static bool shouldProcessEdit({
    required Map<String, dynamic> editData,
    required String? currentUserId,
  }) {
    final editedBy = editData['editedBy'] as String?;
    
    // Process edits from other users
    return editedBy != null && editedBy != currentUserId;
  }

  // ===== EVENT FILTERING =====

  /// Filter out own edits from processing
  static bool isOwnEdit({
    required Map<String, dynamic> editData,
    required String? currentUserId,
  }) {
    final editedBy = editData['editedBy'] as String?;
    return editedBy == currentUserId;
  }

  /// Check if edit is recent enough to process
  static bool isRecentEdit(Map<String, dynamic> editData) {
    final editedAt = editData['editedAt'] as Timestamp?;
    if (editedAt == null) return true; // Process if no timestamp
    
    final editTime = editedAt.toDate();
    final now = DateTime.now();
    final timeDifference = now.difference(editTime);
    
    // Process edits from the last 5 minutes
    return timeDifference.inMinutes <= 5;
  }

  /// Get event priority for processing order
  static int getEventPriority(Map<String, dynamic> editData) {
    final editType = editData['editType'] as String? ?? 'unknown';
    
    switch (editType) {
      case 'realtime_edit':
        return 1; // Highest priority
      case 'presence_update':
        return 3; // Lower priority
      case 'metadata_update':
        return 2; // Medium priority
      default:
        return 2; // Default medium priority
    }
  }
}