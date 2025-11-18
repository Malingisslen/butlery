// lib/services/unified/modules/realtime_edit_context.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Context object bundling all dependencies required for real-time editing operations.
/// This class eliminates parameter duplication across 28+ real-time editing methods by
/// encapsulating the 6 common dependencies (user info, session state, callbacks) into
/// a single reusable context object. This improves API consistency and reduces the risk
/// of forgetting to update dependencies when refactoring.
/// **Benefits:**
/// - Reduces method signatures from 8-10 parameters to 2-3 parameters
/// - Ensures consistent dependency passing across all realtime operations
/// - Simplifies testing by allowing mock context injection
/// - Makes future dependency additions non-breaking (add to context, not all methods)
/// **Usage Example:**
/// ```dart
/// final context = RealtimeEditContext(
///   currentUserId: userId,
///   currentUserDisplayName: displayName,
///   activeEditingSessions: sessions,
///   pendingRealtimeEdits: pendingEdits,
///   applyEditWithConflictResolution: applyEdit,
///   setError: setError,
/// );
/// await RealtimeFieldOperations.updateTitleRealtime(
///   context: context,
///   recipeId: recipeId,
///   newTitle: newTitle,
/// );
/// ```
class RealtimeEditContext {
  /// Current user ID performing the edit operation.
  /// Used for edit metadata, permission checks, and collaborative editing tracking.
  final String currentUserId;

  /// Display name of the current user for UI attribution.
  /// Shown in collaborative editing indicators and edit history to identify who made changes.
  final String? currentUserDisplayName;

  /// Active realtime editing sessions mapped by recipe/menu ID.
  /// Tracks which resources are currently in realtime editing mode with active Firebase listeners.
  /// Used to validate that edit operations are only performed during active sessions.
  final Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions;

  /// Queue of pending realtime edits mapped by recipe/menu ID.
  /// Stores edits awaiting application with conflict resolution. Used for optimistic updates
  /// and coordinating multiple simultaneous editors on the same resource.
  final Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits;

  /// Callback to apply edits with automatic conflict resolution.
  /// Implements the core edit application logic including:
  /// - Detecting concurrent edits from other users
  /// - Merging changes using conflict resolution strategies
  /// - Updating Firebase with resolved state
  /// - Handling optimistic update rollback on failure
  final Future<void> Function(String recipeId, Map<String, dynamic> edit)
      applyEditWithConflictResolution;

  /// Callback to set error messages for user display.
  /// Reports validation failures, permission errors, and operation failures to the UI layer
  /// for user notification. Examples: "Inte i realtidsredigeringsläge", "Titel kan inte vara tom"
  final void Function(String errorMessage) setError;

  /// Creates a new realtime edit context with all required dependencies.
  /// All parameters are required to ensure complete context initialization.
  /// This constructor is typically called once per ViewModel or editing session
  /// and the context is reused across multiple edit operations.
  const RealtimeEditContext({
    required this.currentUserId,
    required this.currentUserDisplayName,
    required this.activeEditingSessions,
    required this.pendingRealtimeEdits,
    required this.applyEditWithConflictResolution,
    required this.setError,
  });

  /// Validates that a realtime editing session is active for the given resource.
  /// Returns true if the resource has an active editing session, false otherwise.
  /// This is used by operations to ensure edits are only performed during active sessions.
  bool hasActiveSession(String resourceId) {
    return activeEditingSessions.containsKey(resourceId);
  }

  /// Gets the pending edits queue for a specific resource.
  /// Returns the list of pending edits, or an empty list if none exist.
  /// Useful for inspection and debugging of the edit queue state.
  List<Map<String, dynamic>> getPendingEdits(String resourceId) {
    return pendingRealtimeEdits[resourceId] ?? [];
  }

  /// Adds an edit to the pending edits queue for a resource.
  /// This is called internally by operations before applying edits.
  void enqueuePendingEdit(String resourceId, Map<String, dynamic> edit) {
    pendingRealtimeEdits.putIfAbsent(resourceId, () => []);
    pendingRealtimeEdits[resourceId]!.add(edit);
  }
}
