// lib/services/realtime/realtime_recipe_service.dart

import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

// Focused modules
import 'package:butlery/services/realtime/modules/recipe_content_operations.dart';
import 'package:butlery/services/realtime/modules/recipe_participants.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

/// Facade for realtime recipe management delegating to RecipeContentOperations (content) and RecipeParticipants (permissions).
/// Clean API with no complex business logic or direct implementation details.
class RealtimeRecipeService with StreamManagementMixin, ErrorHandlingMixin {
  final RealtimeSyncService _syncService;
  final PermissionService _permissionService;

  // State management
  bool _isProcessing = false;
  RecipeOperationError? _lastError;

  RealtimeRecipeService({
    required RealtimeSyncService syncService,
    required PermissionService permissionService,
  })  : _syncService = syncService,
        _permissionService = permissionService;

  /// Is recipe operation in progress?
  bool get isProcessing => _isProcessing;

  /// Latest recipe operation error
  RecipeOperationError? get lastError => _lastError;

  /// Side-channel stream of synchronization errors from the underlying
  /// RealtimeSyncService. Callers who need global error logging (e.g. a
  /// top-level error banner) can subscribe here instead of reaching through
  /// to the sync service directly. BUT-1112.
  Stream<SyncError> get errorStream => _syncService.errorStream;

  /// Current user display name
  String get _currentUserDisplayName =>
      _permissionService.currentUser?.displayName ??
      AppLocale.current.displayUnknownUser;

  /// Create realtime recipe from existing recipe
  Future<RealtimeRecipe> createRealtimeRecipe({
    required Recipe recipe,
    List<String>? editorUserIds,
    List<String>? viewerUserIds,
  }) async {
    if (!_permissionService.isAuthenticated) {
      throw RecipeOperationError(
        operation: RecipeOperationType.createFromExisting,
        message: AppLocale.current.errorUserNotLoggedIn,
      );
    }
    final userId = _permissionService.currentUserId!;

    _setProcessing(true);
    _clearError();

    try {
      AppLogger.info('🍳 Skapar realtidsrecept från: ${recipe.id}');

      // Create RealtimeRecipe from existing recipe
      final realtimeRecipe = RealtimeRecipe.fromRecipe(
        recipe: recipe,
        ownerId: userId,
        ownerDisplayName: _currentUserDisplayName,
        editorUserIds: editorUserIds,
        viewerUserIds: viewerUserIds,
      );

      // Use RealtimeSyncService for saving (SRP - delegate synchronization)
      await _syncService.updateResource(realtimeRecipe);

      AppLogger.success('✅ Realtidsrecept skapat: ${realtimeRecipe.id}');

      return realtimeRecipe;
    } catch (e) {
      _handleError(
        RecipeOperationType.createFromExisting,
        AppLocale.current.errorCouldNotCreateRealtimeRecipe('$e'),
        originalError: e,
      );
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Watch realtime recipe with live updates.
  ///
  /// The returned stream carries data plus main-stream errors (per BUT-1069
  /// — missing/malformed docs surface as `ConnectionState.error` in a
  /// `StreamBuilder`). For the global error side-channel subscribe to
  /// [errorStream] on this service (which forwards
  /// `RealtimeSyncService.errorStream`). See BUT-1082, BUT-1112.
  Stream<RealtimeRecipe> watchRealtimeRecipe(String resourceId) {
    AppLogger.info('👀 Startar watching av realtidsrecept: $resourceId');

    try {
      return _syncService.watchResource<RealtimeRecipe>(resourceId);
    } catch (e) {
      _handleError(
        RecipeOperationType.createFromExisting, // Generic operation
        AppLocale.current.errorCouldNotWatchRecipe('$e'),
        resourceId: resourceId,
        originalError: e,
      );
      rethrow;
    }
  }

  /// Update basic recipe information
  Future<void> updateBasicInfo({
    required String resourceId,
    String? title,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updateBasicInfo,
      operationName: 'uppdatera grundinfo',
      updateFunction: (recipe) => RecipeContentOperations.updateBasicInfo(
        recipe,
        title: title,
        description: description,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        personalTagIds: personalTagIds,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Add ingredient to recipe
  Future<void> addIngredient({
    required String resourceId,
    required String ingredient,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.addIngredient,
      operationName: 'lägga till ingrediens',
      updateFunction: (recipe) => RecipeContentOperations.addIngredient(
        recipe,
        ingredient: ingredient,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Remove ingredient from recipe
  Future<void> removeIngredient({
    required String resourceId,
    required int index,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.removeIngredient,
      operationName: 'ta bort ingrediens',
      updateFunction: (recipe) => RecipeContentOperations.removeIngredient(
        recipe,
        index: index,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Update all ingredients
  Future<void> updateIngredients({
    required String resourceId,
    required List<String> ingredients,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updateIngredients,
      operationName: 'uppdatera ingredienser',
      updateFunction: (recipe) => RecipeContentOperations.updateIngredients(
        recipe,
        ingredients: ingredients,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Add instruction to recipe
  Future<void> addInstruction({
    required String resourceId,
    required String instruction,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.addInstruction,
      operationName: 'lägga till instruktion',
      updateFunction: (recipe) => RecipeContentOperations.addInstruction(
        recipe,
        instruction: instruction,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Remove instruction from recipe
  Future<void> removeInstruction({
    required String resourceId,
    required int index,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.removeInstruction,
      operationName: 'ta bort instruktion',
      updateFunction: (recipe) => RecipeContentOperations.removeInstruction(
        recipe,
        index: index,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Update all instructions
  Future<void> updateInstructions({
    required String resourceId,
    required List<String> instructions,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updateInstructions,
      operationName: 'uppdatera instruktioner',
      updateFunction: (recipe) => RecipeContentOperations.updateInstructions(
        recipe,
        instructions: instructions,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Add image to recipe
  Future<void> addImage({
    required String resourceId,
    required String imageUrl,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.addImage,
      operationName: 'lägga till bild',
      updateFunction: (recipe) => RecipeContentOperations.addImage(
        recipe,
        imageUrl: imageUrl,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Remove image from recipe
  Future<void> removeImage({
    required String resourceId,
    required int index,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.removeImage,
      operationName: 'ta bort bild',
      updateFunction: (recipe) => RecipeContentOperations.removeImage(
        recipe,
        index: index,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Update all images
  Future<void> updateImages({
    required String resourceId,
    required List<String> imageUrls,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updateImages,
      operationName: 'uppdatera bilder',
      updateFunction: (recipe) => RecipeContentOperations.updateImages(
        recipe,
        imageUrls: imageUrls,
        editedBy: _permissionService.currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Add participant to realtime recipe
  Future<void> addParticipant({
    required String resourceId,
    required String userId,
    required String userDisplayName,
    required ResourcePermission permission,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.addParticipant,
      operationName: 'lägga till deltagare',
      updateFunction: (recipe) => RecipeParticipants.addParticipant(
        recipe,
        userId: userId,
        userDisplayName: userDisplayName,
        permission: permission,
      ),
    );
  }

  /// Remove participant from realtime recipe
  Future<void> removeParticipant({
    required String resourceId,
    required String userId,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.removeParticipant,
      operationName: 'ta bort deltagare',
      updateFunction: (recipe) => RecipeParticipants.removeParticipant(
        recipe,
        userId: userId,
      ),
    );
  }

  /// Update participant permission
  Future<void> updateParticipantPermission({
    required String resourceId,
    required String userId,
    required ResourcePermission newPermission,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updatePermissions,
      operationName: 'uppdatera behörighet',
      updateFunction: (recipe) =>
          RecipeParticipants.updateParticipantPermission(
        recipe,
        userId: userId,
        newPermission: newPermission,
      ),
    );
  }

  /// Create personal copy of realtime recipe
  Recipe createPersonalCopy(RealtimeRecipe realtimeRecipe) {
    if (!_permissionService.isAuthenticated) {
      throw RecipeOperationError(
        operation: RecipeOperationType.createFromExisting,
        message: AppLocale.current.errorUserNotLoggedIn,
        resourceId: realtimeRecipe.id,
      );
    }
    final userId = _permissionService.currentUserId!;

    return RecipeContentOperations.createPersonalCopy(
      realtimeRecipe,
      newOwnerId: userId,
    );
  }

  /// Check if recipe has changed since timestamp
  bool hasRecipeChangedSince(RealtimeRecipe recipe, DateTime timestamp) {
    return RecipeContentOperations.hasRecipeChangedSince(recipe, timestamp);
  }

  /// Get summary of recent changes
  String getRecipeChangesSummary(RealtimeRecipe recipe) {
    return RecipeContentOperations.getRecipeChangesSummary(recipe);
  }

  /// Generic method for performing recipe operations with error handling
  Future<void> _performRecipeOperation({
    required String resourceId,
    required RecipeOperationType operation,
    required String operationName,
    required RealtimeRecipe Function(RealtimeRecipe) updateFunction,
  }) async {
    if (!_permissionService.isAuthenticated) {
      throw RecipeOperationError(
        operation: operation,
        message: AppLocale.current.errorUserNotLoggedIn,
        resourceId: resourceId,
      );
    }

    _setProcessing(true);
    _clearError();

    try {
      AppLogger.info('🔄 $operationName för recept: $resourceId');

      // Get current recipe from cache or Firebase
      final currentRecipe =
          _syncService.getCachedResource<RealtimeRecipe>(resourceId);

      if (currentRecipe == null) {
        throw RecipeOperationError(
          operation: operation,
          message: AppLocale.current.errorRecipeNotFound,
          resourceId: resourceId,
        );
      }

      // Check permission via PermissionService
      if (!_permissionService.canEditRecipe(resourceId)) {
        throw RecipeOperationError(
          operation: operation,
          message: AppLocale.current.errorNoEditPermission,
          resourceId: resourceId,
        );
      }

      // Perform update
      final updatedRecipe = updateFunction(currentRecipe);

      // Use RealtimeSyncService for synchronization (SRP)
      await _syncService.updateResource(updatedRecipe);

      AppLogger.success('✅ $operationName slutförd för: $resourceId');
    } catch (e) {
      _handleError(operation,
          AppLocale.current.errorCouldNotPerformOperation(operationName, '$e'),
          resourceId: resourceId, originalError: e);
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Delete realtime recipe completely
  Future<void> deleteRealtimeRecipe(String resourceId) async {
    if (!_permissionService.isAuthenticated) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeParticipant, // Closest operation
        message: AppLocale.current.errorUserNotLoggedIn,
        resourceId: resourceId,
      );
    }

    AppLogger.info('🗑️ Tar bort realtidsrecept: $resourceId');

    try {
      // Delegate to RealtimeSyncService (SRP)
      await _syncService.deleteResource(
          resourceId, RealtimeResourceType.recipe);

      AppLogger.success('✅ Realtidsrecept borttaget: $resourceId');
    } catch (e) {
      _handleError(
        RecipeOperationType.removeParticipant, // Closest operation
        AppLocale.current.errorCouldNotDeleteRealtimeRecipe('$e'),
        resourceId: resourceId,
        originalError: e,
      );
      rethrow;
    }
  }

  /// Set processing state
  void _setProcessing(bool processing) {
    _isProcessing = processing;
  }

  /// Handle error
  void _handleError(
    RecipeOperationType operation,
    String message, {
    String? resourceId,
    dynamic originalError,
  }) {
    _lastError = RecipeOperationError(
      operation: operation,
      message: message,
      resourceId: resourceId,
      originalError: originalError,
    );

    AppLogger.error('🔥 RecipeOperationError: $message', originalError);
  }

  /// Clear error
  void _clearError() {
    _lastError = null;
  }

  /// Clear error status (public method)
  void clearError() {
    _clearError();
  }

  void dispose() {
    disposeStreamResources();
  }
}
