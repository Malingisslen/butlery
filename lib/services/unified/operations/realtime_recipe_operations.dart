import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_watching_module.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_editing_module.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/collaboration_management_module.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/presence_tracking_module.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_notification_module.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/shared/realtime_diagnostics_helper.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/services/unified/operations/modules/recipe_sharing_manager.dart'
    show CreateCollaborativeRecipeFn, CreatePersonalRecipeFn;
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_presence_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Realtime recipe operations coordinator.
/// Orchestrates real-time collaborative editing via watching, editing, collaboration, presence, and notification modules.

// Export conflict info class for backward compatibility
export 'realtime_recipe/realtime_editing_module.dart' show ConflictInfo;
export 'realtime_recipe/realtime_watching_module.dart' show ConnectionStatus;

class RealtimeRecipeOperations extends BaseService with StreamManagementMixin {
  @override
  String get serviceName => 'RealtimeRecipeOperations';
  final String? Function() _getCurrentUserId;
  final List<Recipe> Function() _getRecipes;
  final RealtimeSyncService? _realtimeSyncService;

  // Focused single-responsibility modules
  late final RealtimeWatchingModule _watchingModule;
  late final RealtimeEditingModule _editingModule;
  late final CollaborationManagementModule _collaborationModule;
  late final PresenceTrackingModule _presenceModule;
  late final RealtimeNotificationModule _notificationModule;

  RealtimeRecipeOperations({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required List<Recipe> Function() getRecipes,
    required NotificationParent notificationParent,
    required UpdateRecipeContentFn updateRecipeContent,
    required CreateCollaborativeRecipeFn createCollaborativeRecipe,
    required CreatePersonalRecipeFn createPersonalRecipe,
    required Future<bool> Function(String) deleteRecipe,
    RealtimeSyncService? realtimeSyncService,
  })  : _getCurrentUserId = getCurrentUserId,
        _getRecipes = getRecipes,
        _realtimeSyncService = realtimeSyncService {
    // Initialize focused modules
    _watchingModule = RealtimeWatchingModule(
      getRecipes: getRecipes,
      realtimeSyncService: realtimeSyncService,
    );
    _editingModule = RealtimeEditingModule(
      getCurrentUserId: getCurrentUserId,
      getCurrentUserDisplayName: getCurrentUserDisplayName,
      getRecipes: getRecipes,
      updateRecipeContent: updateRecipeContent,
      realtimeSyncService: realtimeSyncService,
    );
    _collaborationModule = CollaborationManagementModule(
      getCurrentUserId: getCurrentUserId,
      getRecipes: getRecipes,
      createCollaborativeRecipe: createCollaborativeRecipe,
      createPersonalRecipe: createPersonalRecipe,
      deleteRecipe: deleteRecipe,
      realtimeSyncService: realtimeSyncService,
    );
    _presenceModule = PresenceTrackingModule(
      getCurrentUserId: getCurrentUserId,
      getRecipes: getRecipes,
      realtimeSyncService: realtimeSyncService,
      presenceRepository:
          ServiceLocator.get<FirebaseRecipePresenceRepository>(),
    );
    _notificationModule = RealtimeNotificationModule(notificationParent);

    AppLogger.info(
        'RealtimeRecipeOperations initialized with modular architecture');
  }

  /// Execute operation with notification on success
  Future<bool> _executeWithNotification(
    String recipeId,
    Future<bool> Function() operation,
    Future<void> Function(Recipe) notification, {
    Future<void> Function()? beforeNotification,
  }) async {
    final success = await operation();
    if (success) {
      if (beforeNotification != null) await beforeNotification();
      try {
        final recipe = _getRecipes().firstWhere((r) => r.id == recipeId);
        await notification(recipe);
      } catch (e) {
        // Recipe not found, skip notification
      }
    }
    return success;
  }

  /// Watch a recipe for real-time updates
  Stream<Recipe> watchRecipe(String recipeId) {
    if (ValidationUtils.isNullOrEmpty(recipeId)) {
      throw ArgumentError('Recipe ID cannot be null or empty');
    }
    return _watchingModule.watchRecipe(recipeId);
  }

  /// Watch recipe with automatic retry on connection failure
  Stream<Recipe> watchRecipeWithRetry(
    String recipeId, {
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
  Stream<Map<String, Recipe?>> watchMultipleRecipesIndividually(
      List<String> recipeIds) {
    return _watchingModule.watchMultipleRecipesIndividually(recipeIds);
  }

  /// Get connection status for real-time operations
  bool get isConnected => _watchingModule.isConnected;

  /// Get connection status stream
  Stream<bool> get connectionStream => _watchingModule.connectionStream;

  /// Wait for connection to be established
  Future<bool> waitForConnection(
      {Duration timeout = const Duration(seconds: 10)}) {
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

  /// Start real-time editing session for recipe
  Future<bool> startRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final result = await executeServiceOperation(
      () => _executeWithNotification(
        recipeId,
        () => _editingModule.startRealtimeEditing(recipeId),
        _notificationModule.sendCollaborationJoinedNotification,
        beforeNotification: () => _presenceModule.showPresence(recipeId),
      ),
      operationName: 'Start Realtime Editing',
    );
    return result == true;
  }

  /// Stop real-time editing session for recipe
  Future<bool> stopRealtimeEditing(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    await _presenceModule.hidePresence(recipeId);
    final result = await executeServiceOperation(
      () => _executeWithNotification(
        recipeId,
        () => _editingModule.stopRealtimeEditing(recipeId),
        _notificationModule.sendCollaborationLeftNotification,
      ),
      operationName: 'Stop Realtime Editing',
    );
    return result == true;
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
    return _executeWithNotification(
      recipeId,
      () => _editingModule.makeRealtimeEdit(
        recipeId: recipeId,
        changes: changes,
        editDescription: editDescription,
      ),
      (recipe) => _notificationModule.sendRealtimeEditNotification(
          recipe, changes, editDescription),
    );
  }

  /// Make batch realtime edits
  Future<bool> makeBatchRealtimeEdits({
    required String recipeId,
    required List<Map<String, dynamic>> changeList,
    String? batchDescription,
  }) async {
    return _executeWithNotification(
      recipeId,
      () => _editingModule.makeBatchRealtimeEdits(
        recipeId: recipeId,
        changeList: changeList,
        batchDescription: batchDescription,
      ),
      (recipe) => _notificationModule.sendBatchEditNotification(
          recipe, changeList, batchDescription),
    );
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
    String? localActiveField,
  }) async {
    return _executeWithNotification(
      recipeId,
      () => _editingModule.resolveConflict(
        recipeId: recipeId,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
        resolution: resolution,
        localActiveField: localActiveField,
      ),
      (recipe) {
        final affectedUsers =
            recipe.socialData?.memberPermissions?.keys.toList() ?? [];
        return _notificationModule.sendConflictResolvedNotification(
            recipe, resolution, affectedUsers);
      },
      beforeNotification: () async {
        // Notify the user whose edit was overridden
        try {
          final recipe = _getRecipes().firstWhere((r) => r.id == recipeId);
          final overriddenUserId = resolution == 'local'
              ? remoteVersion.realtimeData?.lastEditedByUserId
              : resolution == 'remote'
                  ? localVersion.realtimeData?.lastEditedByUserId
                  : null;
          if (overriddenUserId != null &&
              overriddenUserId != _getCurrentUserId()) {
            await _notificationModule.sendConflictNotification(
              recipe,
              'Edit conflict resolved using $resolution strategy',
              [overriddenUserId],
            );
          }
        } catch (_) {
          // Recipe lookup failed, skip conflict notification
        }
      },
    );
  }

  /// Auto-resolve conflict using default strategy
  Future<bool> autoResolveConflict({
    required String recipeId,
    required Recipe localVersion,
    required Recipe remoteVersion,
    String strategy = 'merge',
    String? localActiveField,
  }) {
    return _editingModule.autoResolveConflict(
      recipeId: recipeId,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      strategy: strategy,
      localActiveField: localActiveField,
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

  /// Enable collaborative editing for a personal recipe
  Future<bool> enableCollaborativeEditing(
      String recipeId, List<String> memberIds) async {
    return _executeWithNotification(
      recipeId,
      () =>
          _collaborationModule.enableCollaborativeEditing(recipeId, memberIds),
      (recipe) => _notificationModule.sendCollaborationEnabledNotification(
          recipe, memberIds),
    );
  }

  /// Disable collaborative editing and convert back to personal recipe
  Future<bool> disableCollaborativeEditing(String recipeId) async {
    return _executeWithNotification(
      recipeId,
      () => _collaborationModule.disableCollaborativeEditing(recipeId),
      _notificationModule.sendCollaborationDisabledNotification,
    );
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
    return _executeWithNotification(
      recipeId,
      () => _collaborationModule.addCollaborators(recipeId, memberIds),
      (recipe) =>
          _notificationModule.sendMembersAddedNotification(recipe, memberIds),
    );
  }

  /// Remove members from collaborative recipe
  Future<bool> removeCollaborators(
      String recipeId, List<String> memberIds) async {
    return _executeWithNotification(
      recipeId,
      () => _collaborationModule.removeCollaborators(recipeId, memberIds),
      (recipe) =>
          _notificationModule.sendMembersRemovedNotification(recipe, memberIds),
    );
  }

  /// Update member permissions in collaborative recipe
  Future<bool> updateMemberPermissions(
      String recipeId, Map<String, String> memberPermissions) {
    return _collaborationModule.updateMemberPermissions(
        recipeId, memberPermissions);
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
    return _collaborationModule.isWithinCollaborationLimits(
        recipeId, additionalMembers);
  }

  /// Get collaboration status for recipe
  Map<String, dynamic> getCollaborationStatus(String recipeId) {
    return _collaborationModule.getCollaborationStatus(recipeId);
  }

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
      List<String> recipeIds) {
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
      List<String> recipeIds) {
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
      Map<String, bool> recipePresenceMap) {
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

  /// Get active editors for recipe (legacy method)
  List<String> getActiveEditors(String recipeId) {
    try {
      final recipe = _getRecipes().firstWhere((r) => r.id == recipeId);
      if (!recipe.isCollaborative) return [];
    } catch (e) {
      return [];
    }

    // Get active editors from presence module
    final currentUserId = _getCurrentUserId();
    if (currentUserId != null &&
        _presenceModule.isUserPresent(recipeId, currentUserId)) {
      return [currentUserId];
    }

    return [];
  }

  /// Get module status information
  Map<String, dynamic> getModuleStatus() {
    return RealtimeDiagnosticsHelper.getModuleStatus(
      watchingModule: _watchingModule,
      presenceModule: _presenceModule,
      notificationModule: _notificationModule,
    );
  }

  /// Get comprehensive realtime operations status
  Map<String, dynamic> getRealtimeOperationsStatus() {
    return RealtimeDiagnosticsHelper.getRealtimeOperationsStatus(
      hasRealtimeService: _realtimeSyncService != null,
      isConnected: _watchingModule.isConnected,
      moduleStatus: getModuleStatus(),
      currentUserId: _getCurrentUserId(),
    );
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

    // Dispose stream resources
    await disposeStreamResources();
  }
}
