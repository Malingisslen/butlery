// lib/services/realtime/realtime_recipe_service.dart

import 'package:flutter/foundation.dart';
import '../../models/realtime/realtime_recipe.dart';
import '../../models/realtime/realtime_resource.dart';
import '../../models/recipe.dart';
import '../../models/permissions/resource_permission.dart';
import '../realtime_sync_service.dart';
import '../auth_service.dart';
import '../user_service.dart';
import '../../core/utils/logger.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Realtime Recipe Service - Recipe-specifika operationer
/// File: services/realtime/realtime_recipe_service.dart
/// Quick Guide: SINGLE RESPONSIBILITY - bara recipe business logic för realtidsrecept
/// Dependencies IN: RealtimeSyncService, AuthService, UserService, realtime models
/// Dependencies OUT: RealtimeRecipeViewModel, recipe collaboration views
/// Data flow: Recipe operations → RealtimeRecipe updates → RealtimeSyncService → Firebase
/// State management: ChangeNotifier för recipe-specific events
/// Purpose: SRP - bara recipe operations, delegerar synkronisering till RealtimeSyncService
/// Common issues: Recipe validation, ingredient/instruction formatting, user context
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Efficient recipe operations, cached user info
/// Analytics: Recipe collaboration patterns, edit frequency, feature usage
/// Code smells: ✅ Clean delegation - bara recipe logic, ingen synkronisering
/// Connected to: RealtimeSyncService, Recipe models, collaborative recipe views
/// Used in phases: Fas 2 (Recipe + Gruppstöd) - Recipe-specific real-time operations

/// Typ av recipe-operationer för analytics och logging
enum RecipeOperationType {
  createFromExisting,
  updateBasicInfo,
  addIngredient,
  removeIngredient,
  updateIngredients,
  addInstruction,
  removeInstruction,
  updateInstructions,
  addImage,
  removeImage,
  updateImages,
  addParticipant,
  removeParticipant,
  updatePermissions,
}

/// Recipe-specifika fel
class RecipeOperationError {
  final RecipeOperationType operation;
  final String message;
  final String? resourceId;
  final dynamic originalError;

  RecipeOperationError({
    required this.operation,
    required this.message,
    this.resourceId,
    this.originalError,
  });

  @override
  String toString() => 'RecipeOperationError(${operation.name}): $message';
}

/// RealtimeRecipeService - SINGLE RESPONSIBILITY: Recipe-specifika operationer
///
/// Denna service hanterar BARA:
/// - Recipe business logic för realtidsrecept
/// - Recipe content validation och formatering
/// - Recipe-specifika CRUD operationer
/// - User context för recipe operations
///
/// Den hanterar INTE:
/// - Firebase synkronisering (det gör RealtimeSyncService)
/// - UI logic eller presentation
/// - Generic realtidsoperationer
/// - Permission management (det finns i modellerna)
class RealtimeRecipeService extends ChangeNotifier {
  final RealtimeSyncService _syncService;
  final AuthService _authService;
  final UserService _userService;

  // State för recipe-specifika operationer
  bool _isProcessing = false;
  RecipeOperationError? _lastError;

  RealtimeRecipeService({
    required RealtimeSyncService syncService,
    required AuthService authService,
    required UserService userService,
  })  : _syncService = syncService,
        _authService = authService,
        _userService = userService;

  // ===== GETTERS =====

  /// Pågår recipe operation?
  bool get isProcessing => _isProcessing;

  /// Senaste recipe operation error
  RecipeOperationError? get lastError => _lastError;

  /// Aktuell användare
  String? get _currentUserId => _authService.currentUser?.uid;

  /// Aktuell användarens display name
  String get _currentUserDisplayName =>
      _userService.currentUserProfile?.displayName ?? 'Okänd användare';

  // ===== CORE RECIPE OPERATIONS =====

  /// Skapa realtidsrecept från befintligt recept
  ///
  /// Tar ett vanligt Recipe och gör det till ett RealtimeRecipe som kan delas
  Future<RealtimeRecipe> createRealtimeRecipe({
    required Recipe recipe,
    List<String>? editorUserIds,
    List<String>? viewerUserIds,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw RecipeOperationError(
        operation: RecipeOperationType.createFromExisting,
        message: 'Användare inte inloggad',
      );
    }

    _setProcessing(true);
    _clearError();

    try {
      AppLogger.info('🍳 Skapar realtidsrecept från: ${recipe.title}');

      // Skapa RealtimeRecipe från befintligt recept
      final realtimeRecipe = RealtimeRecipe.fromRecipe(
        recipe: recipe,
        ownerId: userId,
        ownerDisplayName: _currentUserDisplayName,
        editorUserIds: editorUserIds,
        viewerUserIds: viewerUserIds,
      );

      // Använd RealtimeSyncService för att spara (SRP - vi delegerar synkronisering)
      await _syncService.updateResource(realtimeRecipe);

      AppLogger.success('✅ Realtidsrecept skapat: ${realtimeRecipe.id}');

      return realtimeRecipe;
    } catch (e) {
      _handleError(
        RecipeOperationType.createFromExisting,
        'Kunde inte skapa realtidsrecept: $e',
        originalError: e,
      );
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Titta på realtidsrecept med live updates
  ///
  /// Wrapper runt RealtimeSyncService.watchResource för type safety
  Stream<RealtimeRecipe> watchRealtimeRecipe(String resourceId) {
    AppLogger.info('👀 Startar watching av realtidsrecept: $resourceId');

    try {
      return _syncService.watchResource<RealtimeRecipe>(resourceId);
    } catch (e) {
      _handleError(
        RecipeOperationType.createFromExisting, // Generisk operation
        'Kunde inte starta watching av recept: $e',
        resourceId: resourceId,
        originalError: e,
      );
      rethrow;
    }
  }

  // ===== RECIPE CONTENT OPERATIONS =====

  /// Uppdatera grundläggande receptinformation
  Future<void> updateBasicInfo({
    required String resourceId,
    String? title,
    String? description,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updateBasicInfo,
      operationName: 'uppdatera grundinfo',
      updateFunction: (recipe) => recipe.updateBasicInfo(
        title: title,
        description: description,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: tags,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Lägg till ingrediens
  Future<void> addIngredient({
    required String resourceId,
    required String ingredient,
  }) async {
    if (ingredient.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addIngredient,
        message: 'Ingrediens kan inte vara tom',
        resourceId: resourceId,
      );
    }

    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.addIngredient,
      operationName: 'lägga till ingrediens',
      updateFunction: (recipe) => recipe.addIngredient(
        ingredient: ingredient.trim(),
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Ta bort ingrediens
  Future<void> removeIngredient({
    required String resourceId,
    required int index,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.removeIngredient,
      operationName: 'ta bort ingrediens',
      updateFunction: (recipe) {
        if (index < 0 || index >= recipe.ingredientsCount) {
          throw RecipeOperationError(
            operation: RecipeOperationType.removeIngredient,
            message: 'Ogiltigt ingrediensindex: $index',
            resourceId: resourceId,
          );
        }
        return recipe.removeIngredient(
          index: index,
          editedBy: _currentUserId!,
          editedByDisplayName: _currentUserDisplayName,
        );
      },
    );
  }

  /// Uppdatera alla ingredienser
  Future<void> updateIngredients({
    required String resourceId,
    required List<String> ingredients,
  }) async {
    // Validera ingredienser
    final validIngredients =
        ingredients.map((i) => i.trim()).where((i) => i.isNotEmpty).toList();

    if (validIngredients.isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updateIngredients,
        message: 'Minst en ingrediens krävs',
        resourceId: resourceId,
      );
    }

    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updateIngredients,
      operationName: 'uppdatera ingredienser',
      updateFunction: (recipe) => recipe.updateIngredients(
        ingredients: validIngredients,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Lägg till instruktion
  Future<void> addInstruction({
    required String resourceId,
    required String instruction,
  }) async {
    if (instruction.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addInstruction,
        message: 'Instruktion kan inte vara tom',
        resourceId: resourceId,
      );
    }

    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.addInstruction,
      operationName: 'lägga till instruktion',
      updateFunction: (recipe) => recipe.addInstruction(
        instruction: instruction.trim(),
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Ta bort instruktion
  Future<void> removeInstruction({
    required String resourceId,
    required int index,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.removeInstruction,
      operationName: 'ta bort instruktion',
      updateFunction: (recipe) {
        if (index < 0 || index >= recipe.instructionsCount) {
          throw RecipeOperationError(
            operation: RecipeOperationType.removeInstruction,
            message: 'Ogiltigt instruktionsindex: $index',
            resourceId: resourceId,
          );
        }
        return recipe.removeInstruction(
          index: index,
          editedBy: _currentUserId!,
          editedByDisplayName: _currentUserDisplayName,
        );
      },
    );
  }

  /// Uppdatera alla instruktioner
  Future<void> updateInstructions({
    required String resourceId,
    required List<String> instructions,
  }) async {
    // Validera instruktioner
    final validInstructions =
        instructions.map((i) => i.trim()).where((i) => i.isNotEmpty).toList();

    if (validInstructions.isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.updateInstructions,
        message: 'Minst en instruktion krävs',
        resourceId: resourceId,
      );
    }

    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updateInstructions,
      operationName: 'uppdatera instruktioner',
      updateFunction: (recipe) => recipe.updateInstructions(
        instructions: validInstructions,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Lägg till bild
  Future<void> addImage({
    required String resourceId,
    required String imageUrl,
  }) async {
    if (imageUrl.trim().isEmpty) {
      throw RecipeOperationError(
        operation: RecipeOperationType.addImage,
        message: 'Bild-URL kan inte vara tom',
        resourceId: resourceId,
      );
    }

    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.addImage,
      operationName: 'lägga till bild',
      updateFunction: (recipe) => recipe.addImage(
        imageUrl: imageUrl.trim(),
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Ta bort bild
  Future<void> removeImage({
    required String resourceId,
    required int index,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.removeImage,
      operationName: 'ta bort bild',
      updateFunction: (recipe) {
        if (index < 0 || index >= recipe.imageCount) {
          throw RecipeOperationError(
            operation: RecipeOperationType.removeImage,
            message: 'Ogiltigt bildindex: $index',
            resourceId: resourceId,
          );
        }
        return recipe.removeImage(
          index: index,
          editedBy: _currentUserId!,
          editedByDisplayName: _currentUserDisplayName,
        );
      },
    );
  }

  /// Uppdatera alla bilder
  Future<void> updateImages({
    required String resourceId,
    required List<String> imageUrls,
  }) async {
    // Validera bild-URLs
    final validImageUrls = imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();

    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updateImages,
      operationName: 'uppdatera bilder',
      updateFunction: (recipe) => recipe.updateImages(
        imageUrls: validImageUrls,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  // ===== PARTICIPANT MANAGEMENT =====

  /// Lägg till deltagare till realtidsrecept
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
      updateFunction: (recipe) => recipe.addParticipant(
        userId,
        userDisplayName,
        permission,
      ),
    );
  }

  /// Ta bort deltagare från realtidsrecept
  Future<void> removeParticipant({
    required String resourceId,
    required String userId,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.removeParticipant,
      operationName: 'ta bort deltagare',
      updateFunction: (recipe) => recipe.removeParticipant(userId),
    );
  }

  /// Uppdatera deltagares behörighet
  Future<void> updateParticipantPermission({
    required String resourceId,
    required String userId,
    required ResourcePermission newPermission,
  }) async {
    await _performRecipeOperation(
      resourceId: resourceId,
      operation: RecipeOperationType.updatePermissions,
      operationName: 'uppdatera behörighet',
      updateFunction: (recipe) => recipe.updateParticipantPermission(
        userId,
        newPermission,
      ),
    );
  }

  // ===== UTILITY METHODS =====

  /// Skapa personlig kopia av realtidsrecept
  ///
  /// Använder RealtimeRecipe.createPersonalCopy för att skapa en vanlig Recipe
  Recipe createPersonalCopy(RealtimeRecipe realtimeRecipe) {
    final userId = _currentUserId;
    if (userId == null) {
      throw RecipeOperationError(
        operation: RecipeOperationType.createFromExisting,
        message: 'Användare inte inloggad',
        resourceId: realtimeRecipe.id,
      );
    }

    AppLogger.info('📋 Skapar personlig kopia av: ${realtimeRecipe.title}');

    return realtimeRecipe.createPersonalCopy(newOwnerId: userId);
  }

  /// Kontrollera om receptet har ändrats sedan tidpunkt
  bool hasRecipeChangedSince(RealtimeRecipe recipe, DateTime timestamp) {
    return recipe.hasChangedSince(timestamp);
  }

  /// Få sammanfattning av senaste ändringar
  String getRecipeChangesSummary(RealtimeRecipe recipe) {
    return recipe.getChangesSummary();
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Generisk metod för att utföra recipe-operationer med error handling
  Future<void> _performRecipeOperation({
    required String resourceId,
    required RecipeOperationType operation,
    required String operationName,
    required RealtimeRecipe Function(RealtimeRecipe) updateFunction,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw RecipeOperationError(
        operation: operation,
        message: 'Användare inte inloggad',
        resourceId: resourceId,
      );
    }

    _setProcessing(true);
    _clearError();

    try {
      AppLogger.info('🔄 $operationName för recept: $resourceId');

      // Hämta nuvarande recept från cache eller Firebase
      final currentRecipe =
          _syncService.getCachedResource<RealtimeRecipe>(resourceId);

      if (currentRecipe == null) {
        throw RecipeOperationError(
          operation: operation,
          message: 'Receptet hittades inte',
          resourceId: resourceId,
        );
      }

      // Kontrollera behörighet (från modellen, inte business logic här)
      if (!currentRecipe.canUserEdit(userId)) {
        throw RecipeOperationError(
          operation: operation,
          message: 'Ingen redigeringsbehörighet',
          resourceId: resourceId,
        );
      }

      // Utför uppdatering
      final updatedRecipe = updateFunction(currentRecipe);

      // Använd RealtimeSyncService för synkronisering (SRP)
      await _syncService.updateResource(updatedRecipe);

      AppLogger.success('✅ $operationName slutförd för: $resourceId');
    } catch (e) {
      _handleError(operation, 'Kunde inte $operationName: $e',
          resourceId: resourceId, originalError: e);
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Sätt processing state
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  /// Hantera fel
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
    notifyListeners();
  }

  /// Rensa fel
  void _clearError() {
    _lastError = null;
  }

  // ===== PUBLIC UTILITY METHODS =====

  /// Rensa felstatus
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Ta bort realtidsrecept helt
  Future<void> deleteRealtimeRecipe(String resourceId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw RecipeOperationError(
        operation: RecipeOperationType.removeParticipant, // Närmaste operation
        message: 'Användare inte inloggad',
        resourceId: resourceId,
      );
    }

    AppLogger.info('🗑️ Tar bort realtidsrecept: $resourceId');

    try {
      // Delegera till RealtimeSyncService (SRP)
      await _syncService.deleteResource(
          resourceId, RealtimeResourceType.recipe);

      AppLogger.success('✅ Realtidsrecept borttaget: $resourceId');
    } catch (e) {
      _handleError(
        RecipeOperationType.removeParticipant, // Närmaste operation
        'Kunde inte ta bort realtidsrecept: $e',
        resourceId: resourceId,
        originalError: e,
      );
      rethrow;
    }
  }
}
