/// 🔍 AI INFO BLOCK:
/// Component: Realtime Recipe Operations - Feature interface for real-time collaborative editing
/// File: lib/services/unified/operations/realtime_recipe_operations.dart
/// Quick Guide: Handles real-time collaborative editing operations and conflict resolution
/// Dependencies IN: UnifiedRecipeService, RealtimeSyncService, RealtimeRecipe models
/// Dependencies OUT: Used by ViewModels for real-time collaborative editing
/// Data flow: ViewModels -> RealtimeRecipeOperations -> RealtimeSyncService -> Firebase
/// State management: Real-time streams with conflict resolution
/// Purpose: Clean coordinator that delegates to focused single-responsibility modules
/// Common issues: Conflict resolution, connection management, permission validation
/// Test coverage: Unit tests for real-time operations and conflict resolution
/// Performance: Real-time updates with optimistic UI updates
/// Analytics: Collaborative editing events, conflict resolution stats
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedRecipeService, RealtimeSyncService, Collaborative ViewModels
/// Used in phases: Phase 5 - Service Consolidation, Phase 9.5 - Large File SRP Refactoring

import 'dart:async';
import '../../../models/recipe_unified.dart';
import '../../../core/utils/logger.dart';
import '../../../core/base/base_service.dart';
import '../../../core/utils/validation_utils.dart';
import '../../../core/utils/logging_utils.dart';
import 'realtime_recipe/realtime_watching_module.dart';
import 'realtime_recipe/realtime_editing_module.dart';
import 'realtime_recipe/collaboration_management_module.dart';
import 'realtime_recipe/presence_tracking_module.dart';
import 'realtime_recipe/realtime_notification_module.dart';

/// Realtime recipe operations feature interface
/// 
/// Clean coordinator that delegates to focused single-responsibility modules:
/// - RealtimeWatchingModule: Stream management for watching recipes
/// - RealtimeEditingModule: Edit operations and conflict resolution
/// - CollaborationManagementModule: Enable/disable collaborative editing
/// - PresenceTrackingModule: User presence tracking and management
/// - RealtimeNotificationModule: Collaboration notifications
/// 
/// This coordinator maintains backward compatibility while providing
/// a clean, modular architecture for real-time collaborative editing.

// Export conflict info class for backward compatibility
export 'realtime_recipe/realtime_editing_module.dart' show ConflictInfo;
export 'realtime_recipe/realtime_watching_module.dart' show ConnectionStatus;

class RealtimeRecipeOperations extends BaseService {
  @override
  String get serviceName => 'RealtimeRecipeOperations';
  final dynamic _parent; // UnifiedRecipeService
  final dynamic _realtimeSyncService; // RealtimeSyncService?

  // Focused single-responsibility modules
  late final RealtimeWatchingModule _watchingModule;
  late final RealtimeEditingModule _editingModule;
  late final CollaborationManagementModule _collaborationModule; 
  late final PresenceTrackingModule _presenceModule;
  late final RealtimeNotificationModule _notificationModule;

  RealtimeRecipeOperations(this._parent, [this._realtimeSyncService]) {
    // Initialize focused modules
    _watchingModule = RealtimeWatchingModule(_parent, _realtimeSyncService);
    _editingModule = RealtimeEditingModule(_parent, _realtimeSyncService);
    _collaborationModule = CollaborationManagementModule(_parent, _realtimeSyncService);
    _presenceModule = PresenceTrackingModule(_parent, _realtimeSyncService);
    _notificationModule = RealtimeNotificationModule(_parent);

    AppLogger.info('RealtimeRecipeOperations initialized with modular architecture');
  }

  // ===== REAL-TIME WATCHING (Delegated to RealtimeWatchingModule) =====

  /// Watch a recipe for real-time updates
  Stream<Recipe> watchRecipe(String recipeId) {
    if (ValidationUtils.isNullOrEmpty(recipeId)) {
      throw ArgumentError('Recipe ID cannot be null or empty');
    }
    return _watchingModule.watchRecipe(recipeId);
  }

  /// Watch recipe with automatic retry on connection failure
  Stream<Recipe> watchRecipeWithRetry(String recipeId, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return _watchingModule.watchRecipeWithRetry(
      recipeId,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
    );
  }

  /// Watch multiple recipes for real-time updates
  Stream<List<Recipe>> watchMultipleRecipes(List<String> recipeIds) {
    if (!ValidationUtils.hasItems(recipeIds)) {
      throw ArgumentError('Recipe IDs list cannot be null or empty');
    }
    return _watchingModule.watchMultipleRecipes(recipeIds);
  }

  /// Watch multiple recipes with individual error handling
  Stream<Map<String, Recipe?>> watchMultipleRecipesIndividually(List<String> recipeIds) {
    return _watchingModule.watchMultipleRecipesIndividually(recipeIds);
  }

  /// Get connection status for real-time operations
  bool get isConnected => _watchingModule.isConnected;

  /// Get connection status stream
  Stream<bool> get connectionStream => _watchingModule.connectionStream;

  /// Wait for connection to be established
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 10)}) {
    return _watchingModule.waitForConnection(timeout: timeout);
  }

  /// Monitor connection status changes
  Stream<ConnectionStatus> monitorConnectionStatus() {
    return _watchingModule.monitorConnectionStatus();
  }

  /// Start watching recipe with callback
  StreamSubscription<Recipe> startWatchingRecipe(
    String recipeId, 
    void Function(Recipe) onRecipeUpdated, {
    void Function(dynamic)? onError,
  }) {
    return _watchingModule.startWatchingRecipe(
      recipeId, 
      onRecipeUpdated,
      onError: onError,
    );
  }

  /// Start watching multiple recipes with callback
  StreamSubscription<List<Recipe>> startWatchingMultipleRecipes(
    List<String> recipeIds,
    void Function(List<Recipe>) onRecipesUpdated, {
    void Function(dynamic)? onError,
  }) {
    return _watchingModule.startWatchingMultipleRecipes(
      recipeIds,
      onRecipesUpdated,
      onError: onError,
    );
  }

  /// Check if recipe watching is available
  bool isWatchingAvailable() {
    return _watchingModule.isWatchingAvailable();
  }

  /// Get watching capabilities
  Map<String, bool> getWatchingCapabilities() {
    return _watchingModule.getWatchingCapabilities();
  }

  // ===== REAL-TIME EDITING (Delegated to RealtimeEditingModule) =====

  /// Start real-time editing session for recipe
  Future<bool> startRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) {
      return false;
    }
    
    return await LoggingUtils.loggedOperation(
      'Start Realtime Editing',
      () async {
        final success = await _editingModule.startRealtimeEditing(recipeId);
        
        if (success) {
          // Show presence and send notification
          await _presenceModule.showPresence(recipeId);
          final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
          if (recipe != null) {
            await _notificationModule.sendCollaborationJoinedNotification(recipe);
          }
        }
        
        return success;
      },
      metadata: {'recipe_id': recipeId},
    ) == true;
  }

  /// Stop real-time editing session for recipe
  Future<bool> stopRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) {
      return false;
    }
    
    return await LoggingUtils.loggedOperation(
      'Stop Realtime Editing',
      () async {
        final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
        
        // Hide presence and send notification before stopping
        await _presenceModule.hidePresence(recipeId);
        if (recipe != null) {
          await _notificationModule.sendCollaborationLeftNotification(recipe);
        }
        
        return await _editingModule.stopRealtimeEditing(recipeId);
      },
      metadata: {'recipe_id': recipeId},
    ) == true;
  }

  /// Check if recipe is in realtime editing mode
  bool isInRealtimeEditingMode(String recipeId) {
    return _editingModule.isInRealtimeEditingMode(recipeId);
  }

  /// Make real-time edit to recipe with conflict resolution
  Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    String? editDescription,
  }) async {
    final success = await _editingModule.makeRealtimeEdit(
      recipeId: recipeId,
      changes: changes,
      editDescription: editDescription,
    );
    
    if (success) {
      // Send notification about the edit
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe != null) {
        await _notificationModule.sendRealtimeEditNotification(
          recipe,
          changes,
          editDescription,
        );
      }
    }
    
    return success;
  }

  /// Make batch realtime edits
  Future<bool> makeBatchRealtimeEdits({
    required String recipeId,
    required List<Map<String, dynamic>> changeList,
    String? batchDescription,
  }) async {
    final success = await _editingModule.makeBatchRealtimeEdits(
      recipeId: recipeId,
      changeList: changeList,
      batchDescription: batchDescription,
    );
    
    if (success) {
      // Send batch notification
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe != null) {
        await _notificationModule.sendBatchEditNotification(
          recipe,
          changeList,
          batchDescription,
        );
      }
    }
    
    return success;
  }

  /// Undo last realtime edit
  Future<bool> undoLastRealtimeEdit(String recipeId) {
    return _editingModule.undoLastRealtimeEdit(recipeId);
  }

  /// Resolve edit conflict manually
  Future<bool> resolveConflict({
    required String recipeId,
    required Recipe localVersion,
    required Recipe remoteVersion,
    required String resolution,
  }) async {
    final success = await _editingModule.resolveConflict(
      recipeId: recipeId,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      resolution: resolution,
    );
    
    if (success) {
      // Send conflict resolved notification
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe != null) {
        final affectedUsers = recipe.socialData?.memberPermissions?.keys.toList() ?? [];
        await _notificationModule.sendConflictResolvedNotification(
          recipe,
          resolution,
          affectedUsers,
        );
      }
    }
    
    return success;
  }

  /// Auto-resolve conflict using default strategy
  Future<bool> autoResolveConflict({
    required String recipeId,
    required Recipe localVersion,
    required Recipe remoteVersion,
    String strategy = 'merge',
  }) {
    return _editingModule.autoResolveConflict(
      recipeId: recipeId,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      strategy: strategy,
    );
  }

  /// Check for pending conflicts
  Future<List<ConflictInfo>> getPendingConflicts(String recipeId) {
    return _editingModule.getPendingConflicts(recipeId);
  }

  /// Validate edit changes before applying
  bool validateEditChanges(String recipeId, Map<String, dynamic> changes) {
    return _editingModule.validateEditChanges(recipeId, changes);
  }

  /// Get edit validation rules
  Map<String, dynamic> getEditValidationRules() {
    return _editingModule.getEditValidationRules();
  }

  /// Get editing session status
  Map<String, dynamic> getEditingStatus(String recipeId) {
    return _editingModule.getEditingStatus(recipeId);
  }

  // ===== COLLABORATION FEATURES (Delegated to CollaborationManagementModule) =====

  /// Enable collaborative editing for a personal recipe
  Future<bool> enableCollaborativeEditing(String recipeId, List<String> memberIds) async {
    final success = await _collaborationModule.enableCollaborativeEditing(recipeId, memberIds);
    
    if (success) {
      // Send notification to members
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe != null) {
        await _notificationModule.sendCollaborationEnabledNotification(recipe, memberIds);
      }
    }
    
    return success;
  }

  /// Disable collaborative editing and convert back to personal recipe
  Future<bool> disableCollaborativeEditing(String recipeId) async {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    
    // Send notification before disabling
    if (recipe != null) {
      await _notificationModule.sendCollaborationDisabledNotification(recipe);
    }
    
    return await _collaborationModule.disableCollaborativeEditing(recipeId);
  }

  /// Check if recipe can be made collaborative
  bool canEnableCollaboration(String recipeId) {
    return _collaborationModule.canEnableCollaboration(recipeId);
  }

  /// Check if recipe collaboration can be disabled
  bool canDisableCollaboration(String recipeId) {
    return _collaborationModule.canDisableCollaboration(recipeId);
  }

  /// Add members to collaborative recipe
  Future<bool> addCollaborators(String recipeId, List<String> memberIds) async {
    final success = await _collaborationModule.addCollaborators(recipeId, memberIds);
    
    if (success) {
      // Send notification about new members
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe != null) {
        await _notificationModule.sendMembersAddedNotification(recipe, memberIds);
      }
    }
    
    return success;
  }

  /// Remove members from collaborative recipe
  Future<bool> removeCollaborators(String recipeId, List<String> memberIds) async {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    
    // Send notification before removing
    if (recipe != null) {
      await _notificationModule.sendMembersRemovedNotification(recipe, memberIds);
    }
    
    return await _collaborationModule.removeCollaborators(recipeId, memberIds);
  }

  /// Update member permissions in collaborative recipe
  Future<bool> updateMemberPermissions(String recipeId, Map<String, String> memberPermissions) {
    return _collaborationModule.updateMemberPermissions(recipeId, memberPermissions);
  }

  /// Transfer ownership of collaborative recipe
  Future<bool> transferOwnership(String recipeId, String newOwnerId) {
    return _collaborationModule.transferOwnership(recipeId, newOwnerId);
  }

  /// Leave collaborative recipe as a member
  Future<bool> leaveCollaboration(String recipeId) {
    return _collaborationModule.leaveCollaboration(recipeId);
  }

  /// Get collaboration details for recipe
  Map<String, dynamic> getCollaborationDetails(String recipeId) {
    return _collaborationModule.getCollaborationDetails(recipeId);
  }

  /// Get collaboration statistics
  Map<String, dynamic> getCollaborationStats(String recipeId) {
    return _collaborationModule.getCollaborationStats(recipeId);
  }

  /// Get collaboration history for recipe
  Future<List<Map<String, dynamic>>> getCollaborationHistory(String recipeId) {
    return _collaborationModule.getCollaborationHistory(recipeId);
  }

  /// Get edit history for recipe (legacy method - delegates to collaboration module)
  Future<List<Map<String, dynamic>>> getEditHistory(String recipeId) {
    return _collaborationModule.getCollaborationHistory(recipeId);
  }

  /// Validate collaboration settings
  Map<String, String> validateCollaborationSettings({
    required List<String> memberIds,
    Map<String, String>? memberPermissions,
  }) {
    return _collaborationModule.validateCollaborationSettings(
      memberIds: memberIds,
      memberPermissions: memberPermissions,
    );
  }

  /// Check collaboration limits
  bool isWithinCollaborationLimits(String recipeId, int additionalMembers) {
    return _collaborationModule.isWithinCollaborationLimits(recipeId, additionalMembers);
  }

  /// Get collaboration status for recipe
  Map<String, dynamic> getCollaborationStatus(String recipeId) {
    return _collaborationModule.getCollaborationStatus(recipeId);
  }

  // ===== PRESENCE FEATURES (Delegated to PresenceTrackingModule) =====

  /// Show user presence in recipe (who's viewing/editing)
  Future<bool> showPresence(String recipeId) {
    return _presenceModule.showPresence(recipeId);
  }

  /// Hide user presence in recipe
  Future<bool> hidePresence(String recipeId) {
    return _presenceModule.hidePresence(recipeId);
  }

  /// Update presence heartbeat (keep user active)
  Future<bool> updatePresenceHeartbeat(String recipeId) {
    return _presenceModule.updatePresenceHeartbeat(recipeId);
  }

  /// Get users currently viewing/editing the recipe
  Future<List<Map<String, dynamic>>> getRecipePresence(String recipeId) {
    return _presenceModule.getRecipePresence(recipeId);
  }

  /// Get presence for multiple recipes
  Future<Map<String, List<Map<String, dynamic>>>> getMultipleRecipePresence(
    List<String> recipeIds
  ) {
    return _presenceModule.getMultipleRecipePresence(recipeIds);
  }

  /// Check if user is present in recipe
  bool isUserPresent(String recipeId, String userId) {
    return _presenceModule.isUserPresent(recipeId, userId);
  }

  /// Get presence count for recipe
  int getPresenceCount(String recipeId) {
    return _presenceModule.getPresenceCount(recipeId);
  }

  /// Stream of presence updates for a recipe
  Stream<List<Map<String, dynamic>>> watchRecipePresence(String recipeId) {
    return _presenceModule.watchRecipePresence(recipeId);
  }

  /// Stream of presence updates for multiple recipes
  Stream<Map<String, List<Map<String, dynamic>>>> watchMultipleRecipePresence(
    List<String> recipeIds
  ) {
    return _presenceModule.watchMultipleRecipePresence(recipeIds);
  }

  /// Stream of presence count for recipe
  Stream<int> watchPresenceCount(String recipeId) {
    return _presenceModule.watchPresenceCount(recipeId);
  }

  /// Start automatic presence tracking for recipe
  StreamSubscription<void>? startAutomaticPresenceTracking(
    String recipeId, {
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) {
    return _presenceModule.startAutomaticPresenceTracking(
      recipeId,
      heartbeatInterval: heartbeatInterval,
    );
  }

  /// Bulk update presence for multiple recipes
  Future<void> updateMultipleRecipePresence(
    Map<String, bool> recipePresenceMap
  ) {
    return _presenceModule.updateMultipleRecipePresence(recipePresenceMap);
  }

  /// Clear all presence for current user
  Future<void> clearAllPresence() {
    return _presenceModule.clearAllPresence();
  }

  /// Get presence statistics
  Map<String, dynamic> getPresenceStatistics() {
    return _presenceModule.getPresenceStatistics();
  }

  /// Get user's presence history
  List<Map<String, dynamic>> getUserPresenceHistory(String userId) {
    return _presenceModule.getUserPresenceHistory(userId);
  }

  // ===== LEGACY METHODS (For backward compatibility) =====

  /// Get active editors for recipe (legacy method)
  List<String> getActiveEditors(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null || !recipe.isCollaborative) return [];

    // Get active editors from presence module
    final currentUserId = _parent.currentUserId;
    if (currentUserId != null && _presenceModule.isUserPresent(recipeId, currentUserId)) {
      return [currentUserId];
    }

    return [];
  }

  // ===== MODULE STATUS AND DIAGNOSTICS =====

  /// Get module status information
  Map<String, dynamic> getModuleStatus() {
    return {
      'watchingModule': {
        'isAvailable': _watchingModule.isWatchingAvailable(),
        'capabilities': _watchingModule.getWatchingCapabilities(),
        'isConnected': _watchingModule.isConnected,
      },
      'editingModule': {
        'isInitialized': true,
      },
      'collaborationModule': {
        'isInitialized': true,
      },
      'presenceModule': {
        'statistics': _presenceModule.getPresenceStatistics(),
      },
      'notificationModule': {
        'isAvailable': _notificationModule.isNotificationAvailable,
        'statistics': _notificationModule.getNotificationStatistics(),
      },
    };
  }

  /// Get comprehensive realtime operations status
  Map<String, dynamic> getRealtimeOperationsStatus() {
    return {
      'hasRealtimeService': _realtimeSyncService != null,
      'isConnected': isConnected,
      'moduleStatus': getModuleStatus(),
      'currentUserId': _parent.currentUserId,
      'architecture': 'modular',
      'version': '2.0', // Refactored version
    };
  }

  /// Dispose resources
  @override
  Future<void> dispose() async {
    safeExecuteSync(
      () {
        _presenceModule.dispose();
        AppLogger.info('RealtimeRecipeOperations disposed successfully');
      },
      operationName: 'Dispose RealtimeRecipeOperations',
    );
  }
}