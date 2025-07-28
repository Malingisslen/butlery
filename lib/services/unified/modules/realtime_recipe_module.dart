// lib/services/unified/modules/realtime_recipe_module.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/models/recipe_unified.dart';

// Import focused modules
import 'package:butlery/services/unified/modules/realtime_session_manager.dart';
import 'package:butlery/services/unified/modules/realtime_content_operations.dart';
import 'package:butlery/services/unified/modules/realtime_conflict_resolver.dart';
import 'package:butlery/services/unified/modules/realtime_editor_tracker.dart';
import 'package:butlery/services/unified/modules/realtime_event_handler.dart';
import 'package:butlery/services/unified/modules/realtime_cache_manager.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_notification_module.dart';

/// Real-time recipe operations module (Refactored with Facade Pattern)
/// 
/// This is a clean facade that delegates to focused modules:
/// - RealtimeSessionManager: Session lifecycle management
/// - RealtimeContentOperations: Content editing operations
/// - RealtimeConflictResolver: Conflict resolution strategies
/// - RealtimeEditorTracker: Active editor management
/// - RealtimeEventHandler: Real-time event processing
/// - RealtimeCacheManager: Cache and cleanup operations
/// 
/// ✅ SINGLE RESPONSIBILITY: Orchestrates real-time collaboration through focused modules
class RealtimeRecipeModule {
  final FirebaseFirestore _firestore;
  final JsonCacheHelper _cacheHelper;
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String) _setError;
  final void Function() _notifyListeners;
  final Future<Recipe?> Function(String) _getRecipe;

  /// Active editing sessions by recipe ID
  final Map<String, StreamSubscription<DocumentSnapshot>> _activeEditingSessions = {};
  
  /// Pending real-time edits waiting for sync
  final Map<String, List<Map<String, dynamic>>> _pendingRealtimeEdits = {};
  
  /// Edit conflict resolution queue
  final Map<String, Timer> _conflictResolutionTimers = {};

  /// Notification module for real-time edit notifications
  late final RealtimeNotificationModule _notificationModule;

  RealtimeRecipeModule({
    required FirebaseFirestore firestore,
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
  })  : _firestore = firestore,
        _cacheHelper = cacheHelper,
        _getCurrentUserId = getCurrentUserId,
        _getCurrentUserDisplayName = getCurrentUserDisplayName,
        _setError = setError,
        _notifyListeners = notifyListeners,
        _getRecipe = getRecipe {
    // Initialize notification module with a mock parent interface
    _notificationModule = RealtimeNotificationModule(_ParentInterface(
      firestore: _firestore,
      getCurrentUserId: _getCurrentUserId,
      getCurrentUserDisplayName: _getCurrentUserDisplayName,
    ));
  }

  // ===== REAL-TIME EDITING SESSION MANAGEMENT =====

  /// Start real-time editing session for a recipe
  Future<bool> startRealtimeEditing(String recipeId) async {
    return await RealtimeSessionManager.startRealtimeEditing(
      firestore: _firestore,
      recipeId: recipeId,
      currentUserId: _getCurrentUserId() ?? '',
      activeEditingSessions: _activeEditingSessions,
      onRealtimeChange: _handleRealtimeRecipeChange,
      onRealtimeError: _handleRealtimeError,
      registerActiveEditor: _registerActiveEditor,
      setError: _setError,
    );
  }

  /// Stop real-time editing session for a recipe
  Future<bool> stopRealtimeEditing(String recipeId) async {
    return await RealtimeSessionManager.stopRealtimeEditing(
      recipeId: recipeId,
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
      registerActiveEditor: _registerActiveEditor,
    );
  }

  /// Check if currently in real-time editing session
  bool isInRealtimeEditingSession(String recipeId) {
    return RealtimeSessionManager.isInRealtimeEditingSession(
      recipeId: recipeId,
      activeEditingSessions: _activeEditingSessions,
    );
  }

  /// Get all active editing sessions
  List<String> get activeEditingSessions {
    return RealtimeSessionManager.getActiveEditingSessions(_activeEditingSessions);
  }

  // ===== REAL-TIME CONTENT OPERATIONS =====

  /// Make a real-time edit to recipe content
  Future<bool> makeRealtimeEdit(String recipeId, Map<String, dynamic> changes) async {
    return await RealtimeContentOperations.makeRealtimeEdit(
      recipeId: recipeId,
      changes: changes,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  /// Update recipe title in real-time
  Future<bool> updateTitleRealtime(String recipeId, String newTitle) async {
    return await RealtimeContentOperations.updateTitleRealtime(
      recipeId: recipeId,
      newTitle: newTitle,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  /// Update recipe description in real-time
  Future<bool> updateDescriptionRealtime(String recipeId, String newDescription) async {
    return await RealtimeContentOperations.updateDescriptionRealtime(
      recipeId: recipeId,
      newDescription: newDescription,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  /// Add ingredient in real-time
  Future<bool> addIngredientRealtime(String recipeId, String ingredient, int? index) async {
    return await RealtimeContentOperations.addIngredientRealtime(
      recipeId: recipeId,
      ingredient: ingredient,
      index: index,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  /// Update ingredient in real-time
  Future<bool> updateIngredientRealtime(String recipeId, int index, String newIngredient) async {
    return await RealtimeContentOperations.updateIngredientRealtime(
      recipeId: recipeId,
      index: index,
      newIngredient: newIngredient,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  /// Remove ingredient in real-time
  Future<bool> removeIngredientRealtime(String recipeId, int index) async {
    return await RealtimeContentOperations.removeIngredientRealtime(
      recipeId: recipeId,
      index: index,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  /// Add instruction in real-time
  Future<bool> addInstructionRealtime(String recipeId, String instruction, int? index) async {
    return await RealtimeContentOperations.addInstructionRealtime(
      recipeId: recipeId,
      instruction: instruction,
      index: index,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  /// Update instruction in real-time
  Future<bool> updateInstructionRealtime(String recipeId, int index, String newInstruction) async {
    return await RealtimeContentOperations.updateInstructionRealtime(
      recipeId: recipeId,
      index: index,
      newInstruction: newInstruction,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  /// Remove instruction in real-time
  Future<bool> removeInstructionRealtime(String recipeId, int index) async {
    return await RealtimeContentOperations.removeInstructionRealtime(
      recipeId: recipeId,
      index: index,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      applyEditWithConflictResolution: _applyRealtimeEditWithConflictResolution,
      setError: _setError,
    );
  }

  // ===== ACTIVE EDITOR MANAGEMENT =====

  /// Register/unregister user as active editor
  Future<void> _registerActiveEditor(String recipeId, bool isActive) async {
    await RealtimeEditorTracker.registerActiveEditor(
      recipeId: recipeId,
      isActive: isActive,
      currentUserId: _getCurrentUserId() ?? '',
      currentUserDisplayName: _getCurrentUserDisplayName(),
    );
  }

  /// Update last seen timestamp for active editor
  Future<void> updateActiveEditorPresence(String recipeId) async {
    await RealtimeEditorTracker.updateActiveEditorPresence(
      recipeId: recipeId,
      currentUserId: _getCurrentUserId() ?? '',
    );
  }

  /// Get active editors for a recipe
  Future<List<Map<String, dynamic>>> getActiveEditors(String recipeId) async {
    return await RealtimeEditorTracker.getActiveEditors(
      recipeId: recipeId,
    );
  }

  // ===== CONFLICT RESOLUTION =====

  /// Apply real-time edit with conflict resolution
  Future<void> _applyRealtimeEditWithConflictResolution(
      String recipeId, Map<String, dynamic> editMetadata) async {
    await RealtimeConflictResolver.applyEditWithConflictResolution(
      firestore: _firestore,
      recipeId: recipeId,
      editMetadata: editMetadata,
      conflictResolutionTimers: _conflictResolutionTimers,
      pendingRealtimeEdits: _pendingRealtimeEdits,
    );
  }

  // ===== REAL-TIME EVENT HANDLING =====

  /// Handle real-time recipe changes from Firestore
  void _handleRealtimeRecipeChange(DocumentSnapshot snapshot) {
    RealtimeEventHandler.handleRealtimeRecipeChange(
      snapshot: snapshot,
      getCurrentUserId: _getCurrentUserId,
      saveToCache: (recipe) => RealtimeCacheManager.saveToCache(
        recipe: recipe,
        cacheHelper: _cacheHelper,
      ),
      notifyListeners: _notifyListeners,
      sendRealtimeEditNotification: _sendRealtimeEditNotification,
    );
  }

  /// Handle real-time synchronization errors
  void _handleRealtimeError(String recipeId, dynamic error) {
    RealtimeEventHandler.handleRealtimeError(
      recipeId: recipeId,
      error: error,
      stopRealtimeEditing: stopRealtimeEditing,
      setError: _setError,
    );
  }

  /// Send silent notification about real-time edit
  Future<void> _sendRealtimeEditNotification(
      String recipeId, String? editedBy, Map<String, dynamic> data) async {
    try {
      // Get the full recipe data for collaborative check and member notifications
      final recipe = await _getRecipe(recipeId);
      if (recipe != null && recipe.isCollaborative) {
        // Use the notification module to send proper notifications
        await _notificationModule.sendRealtimeEditNotification(
          recipe,
          data,
          RealtimeEventHandler.extractEditDetails(data)['editType'] as String?,
        );
      }
    } catch (e) {
      // Fallback to the static method if there are issues
      await RealtimeEventHandler.sendRealtimeEditNotification(
        recipeId: recipeId,
        editedBy: editedBy,
        data: data,
      );
    }
  }

  // ===== CLEANUP =====

  /// Dispose of all real-time resources
  Future<void> dispose() async {
    await RealtimeCacheManager.dispose(
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
      stopRealtimeEditing: stopRealtimeEditing,
    );
  }

  // ===== STATUS AND DIAGNOSTICS =====

  /// Get real-time editing status for debugging
  Map<String, dynamic> getRealtimeStatus() {
    return RealtimeSessionManager.getSessionStatus(
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
    );
  }

  /// Check if there are pending edits for a recipe
  bool hasPendingEdits(String recipeId) {
    return _pendingRealtimeEdits[recipeId]?.isNotEmpty ?? false;
  }

  /// Get count of pending edits for a recipe
  int getPendingEditsCount(String recipeId) {
    return _pendingRealtimeEdits[recipeId]?.length ?? 0;
  }

  // ===== ADDITIONAL DELEGATION METHODS =====

  /// Get editor statistics for recipe
  Future<Map<String, dynamic>> getEditorStatistics(String recipeId) async {
    return await RealtimeEditorTracker.getEditorStatistics(
      recipeId: recipeId,
    );
  }

  /// Check if recipe has collaborative editing activity
  Future<bool> hasCollaborativeActivity(String recipeId) async {
    return await RealtimeEditorTracker.hasCollaborativeActivity(
      recipeId: recipeId,
    );
  }

  /// Cleanup inactive editors
  Future<void> cleanupInactiveEditors(String recipeId) async {
    await RealtimeEditorTracker.cleanupInactiveEditors(
      recipeId: recipeId,
    );
  }

  /// Get conflict statistics
  Map<String, dynamic> getConflictStatistics() {
    return RealtimeConflictResolver.getConflictStatistics(
      pendingRealtimeEdits: _pendingRealtimeEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
    );
  }

  /// Force resolve conflicts for a recipe
  Future<void> forceResolveConflicts(String recipeId) async {
    await RealtimeConflictResolver.forceResolveConflicts(
      firestore: _firestore,
      recipeId: recipeId,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
    );
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryUsage() {
    return RealtimeCacheManager.getMemoryUsage(
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
    );
  }

  /// Cleanup excess memory when thresholds are exceeded
  Future<void> cleanupExcessMemory() async {
    await RealtimeCacheManager.cleanupExcessMemory(
      activeEditingSessions: _activeEditingSessions,
      pendingRealtimeEdits: _pendingRealtimeEdits,
      conflictResolutionTimers: _conflictResolutionTimers,
    );
  }
}

/// Mock parent interface for RealtimeNotificationModule
class _ParentInterface {
  final FirebaseFirestore firestore;
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;

  _ParentInterface({
    required this.firestore,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
  })  : _getCurrentUserId = getCurrentUserId,
        _getCurrentUserDisplayName = getCurrentUserDisplayName;

  String? get currentUserId => _getCurrentUserId();
  String? get currentUserDisplayName => _getCurrentUserDisplayName();
}