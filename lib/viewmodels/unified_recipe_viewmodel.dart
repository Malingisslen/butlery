// lib/viewmodels/unified_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/permission_service.dart' as perm;
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/permission_mixins.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/logging_utils.dart';
import 'package:butlery/services/unified/types/recipe_types.dart' show RecipeOperationResult;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';

// Import focused ViewModels
import 'package:butlery/viewmodels/recipe/personal_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/recipe/social_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/recipe/realtime_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';

/// Unified Recipe ViewModel (Facade)
/// 
/// Maintains backward compatibility while delegating to focused ViewModels.
/// This facade provides the same interface as the original monolithic ViewModel
/// while internally using the 4 focused ViewModels for better separation of concerns.
/// 
/// Focused ViewModels:
/// - PersonalRecipeViewModel: Personal recipe operations
/// - SocialRecipeViewModel: Social recipe and collaboration features  
/// - RealtimeRecipeViewModel: Real-time collaborative editing
/// - RecipeQueryViewModel: Querying, filtering, and analytics
class UnifiedRecipeViewModel extends ChangeNotifier with BasePermissionMixin, RecipePermissionMixin, ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService = sl<UnifiedRecipeService>();

  // Focused ViewModels
  late final PersonalRecipeViewModel _personalViewModel;
  late final SocialRecipeViewModel _socialViewModel;
  late final RealtimeRecipeViewModel _realtimeViewModel;
  late final RecipeQueryViewModel _queryViewModel;

  UnifiedRecipeViewModel() {
    // Initialize focused ViewModels
    _personalViewModel = PersonalRecipeViewModel();
    _socialViewModel = SocialRecipeViewModel();
    _realtimeViewModel = RealtimeRecipeViewModel();
    _queryViewModel = RecipeQueryViewModel();

    // Listen to service changes - same pattern as before
    _recipeService.addListener(_onServiceUpdate);
    
    // Listen to focused ViewModel changes
    _personalViewModel.addListener(_onServiceUpdate);
    _socialViewModel.addListener(_onServiceUpdate);
    _realtimeViewModel.addListener(_onServiceUpdate);
    _queryViewModel.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    notifyListeners();
  }

  // ===== GETTERS - same API as original =====

  // ✅ FIX: Add allRecipes getter as injection.dart expects
  List<Recipe> get allRecipes => _recipeService.recipes;

  // Recipes and state
  List<Recipe> get recipes => _recipeService.recipes;
  List<Recipe> get personalRecipes => _recipeService.personalRecipes;
  List<Recipe> get collaborativeRecipes => _recipeService.collaborativeRecipes;

  // Loading states
  bool get isLoading => _recipeService.isLoading;
  bool get isSyncing => _recipeService.isSyncing;
  bool get isInitialized => _recipeService.isInitialized;

  // Error handling
  String? get error => _recipeService.error;
  bool get hasError => _recipeService.hasError;

  // Connection status
  bool get isOnline => !hasError && isInitialized;

  // Recipe existence checks
  bool get hasRecipes => _recipeService.hasRecipes;
  bool get hasPersonalRecipes => personalRecipes.isNotEmpty;
  bool get hasCollaborativeRecipes => collaborativeRecipes.isNotEmpty;

  // User info
  @override
  String? get currentUserId => _recipeService.currentUserId;
  @override
  String? get currentUserDisplayName => _recipeService.currentUserDisplayName;

  // Statistics
  int get totalRecipes => recipes.length;
  int get personalRecipeCount => personalRecipes.length;
  int get collaborativeRecipeCount => collaborativeRecipes.length;

  // ===== INITIALIZATION =====

  Future<void> initialize() async {
    await LoggingUtils.loggedOperation(
      'Initialize Recipe ViewModel',
      () => _recipeService.initialize(),
      level: LogLevel.info,
    );
  }

  // ===== PERSONAL RECIPE OPERATIONS (Delegate to PersonalRecipeViewModel) =====

  Future<bool> createPersonalRecipe({
    required String name,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
  }) async {
    return await _personalViewModel.createPersonalRecipe(
      name: name,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
    );
  }

  // ===== SOCIAL RECIPE OPERATIONS (Delegate to SocialRecipeViewModel) =====

  Future<bool> createCollaborativeRecipe({
    required String name,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    return await _socialViewModel.createCollaborativeRecipe(
      name: name,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      imageUrls: imageUrls,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      rating: rating,
      tags: tags,
      sourceUrl: sourceUrl,
      descriptionCollaborative: descriptionCollaborative,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    return await _socialViewModel.shareRecipe(
      recipeId: recipeId,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      collaborativeDescription: collaborativeDescription,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    return await _socialViewModel.makeRecipePersonal(collaborativeRecipeId);
  }

  // ===== UNIFIED RECIPE MANAGEMENT =====

  Future<bool> updateRecipe(Recipe recipe) async {
    if (recipe.isPersonal) {
      return await _personalViewModel.updatePersonalRecipe(recipe);
    } else {
      return await _recipeService.updateRecipe(recipe);
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;
    
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.deletePersonalRecipe(recipeId);
    } else {
      return await _recipeService.deleteRecipe(recipeId);
    }
  }

  // ===== LEGACY COMPATIBILITY METHODS =====

  Future<RecipeOperationResult> addRecipe(Recipe recipe) async {
    if (recipe.isPersonal) {
      return await _personalViewModel.addLegacyRecipe(recipe);
    } else {
      return RecipeOperationResult.failure('Cannot add non-personal recipe through legacy method');
    }
  }

  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    if (recipe.isPersonal) {
      return await _personalViewModel.updateLegacyRecipe(recipe);
    } else {
      return RecipeOperationResult.failure('Cannot update non-personal recipe through legacy method');
    }
  }

  Future<RecipeOperationResult> deleteRecipeById(String id) async {
    if (ValidationUtils.isNullOrEmpty(id)) {
      return RecipeOperationResult.failure('Invalid recipe ID');
    }

    return await safeExecute(
      () => LoggingUtils.loggedOperation(
        'Delete Recipe by ID',
        () => _recipeService.deleteRecipeById(id),
        metadata: {'recipe_id': id},
      ),
      operationName: 'Delete Recipe by ID',
      defaultValue: RecipeOperationResult.failure('Failed to delete recipe'),
    ) ?? RecipeOperationResult.failure('Failed to delete recipe');
  }

  Future<void> refresh() async {
    await LoggingUtils.loggedOperation(
      'Refresh Recipes',
      () => _recipeService.refresh(),
      level: LogLevel.debug,
    );
  }

  // ===== CONTENT EDITING METHODS =====

  Future<bool> updateRecipeContent({
    required String recipeId,
    String? name,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    List<String>? imageUrls,
    String? mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? tags,
    String? sourceUrl,
  }) async {
    if (ValidationUtils.isNullOrEmpty(recipeId)) return false;

    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;

    if (recipe.isPersonal) {
      return await _personalViewModel.updateRecipeContent(
        recipeId: recipeId,
        name: name,
        description: description,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: tags,
        sourceUrl: sourceUrl,
      );
    } else {
      return await _recipeService.updateRecipeContent(
        recipeId: recipeId,
        title: name,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        imageUrls: imageUrls,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: tags,
        sourceUrl: sourceUrl,
      );
    }
  }

  // ===== INGREDIENT MANAGEMENT =====

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.addIngredient(recipeId, ingredient);
    } else {
      return await _recipeService.addIngredient(recipeId, ingredient);
    }
  }

  Future<bool> updateIngredient(String recipeId, int index, String newIngredient) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.updateIngredient(recipeId, index, newIngredient);
    } else {
      return await _recipeService.updateIngredient(recipeId, index, newIngredient);
    }
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.removeIngredient(recipeId, index);
    } else {
      return await _recipeService.removeIngredient(recipeId, index);
    }
  }

  // ===== INSTRUCTION MANAGEMENT =====

  Future<bool> addInstruction(String recipeId, String instruction) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.addInstruction(recipeId, instruction);
    } else {
      return await _recipeService.addInstruction(recipeId, instruction);
    }
  }

  Future<bool> updateInstruction(String recipeId, int index, String newInstruction) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.updateInstruction(recipeId, index, newInstruction);
    } else {
      return await _recipeService.updateInstruction(recipeId, index, newInstruction);
    }
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.removeInstruction(recipeId, index);
    } else {
      return await _recipeService.removeInstruction(recipeId, index);
    }
  }

  Future<bool> markRecipeAsCooked(String recipeId) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _personalViewModel.markAsCooked(recipeId);
    } else {
      return await _recipeService.markRecipeAsCooked(recipeId);
    }
  }

  // ===== SOCIAL MEMBER MANAGEMENT (Delegate to SocialRecipeViewModel) =====

  Future<bool> addMemberToRecipe(
      String recipeId, String userId, String userDisplayName, 
      {ResourcePermission permission = ResourcePermission.editor}) async {
    return await _socialViewModel.addMemberToRecipe(recipeId, userId, userDisplayName, permission: permission);
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _socialViewModel.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(
      String recipeId, String userId, ResourcePermission permission) async {
    return await _socialViewModel.updateMemberPermission(recipeId, userId, permission);
  }

  Map<String, ResourcePermission> getRecipeMembers(String recipeId) {
    return _socialViewModel.getRecipeMembers(recipeId);
  }

  bool canInviteMembers(String recipeId) {
    return _socialViewModel.canInviteMembers(recipeId);
  }

  List<Recipe> getSharedWithMe() {
    return _socialViewModel.getSharedWithMe();
  }

  List<Recipe> getSharedByMe() {
    return _socialViewModel.getSharedByMe();
  }

  // ===== RECIPE QUERIES & FILTERING (Delegate to RecipeQueryViewModel) =====

  Recipe? getRecipeById(String id) {
    return _queryViewModel.getRecipeById(id);
  }

  Recipe? getUnifiedRecipeById(String id) {
    return _queryViewModel.getRecipeById(id);
  }

  List<Recipe> getRecipesByMealType(String mealType) {
    return _queryViewModel.getRecipesByMealType(mealType);
  }

  List<Recipe> getRecipesByTag(String tag) {
    return _queryViewModel.getRecipesByTag(tag);
  }

  List<Recipe> searchRecipes(String query) {
    return _queryViewModel.searchRecipes(query);
  }

  List<Recipe> getEditableRecipes() {
    return _queryViewModel.getEditableRecipes();
  }

  List<Recipe> getRecentlyCookedRecipes() {
    return _queryViewModel.getRecentlyCookedRecipes();
  }

  Map<String, List<Recipe>> get recipesByMealType {
    return _queryViewModel.recipesByMealType;
  }

  List<String> get usedMealTypes {
    return _queryViewModel.usedMealTypes;
  }

  List<String> get usedTags {
    return _queryViewModel.usedTags;
  }

  // ===== COLLABORATIVE FEATURES =====

  bool canManageRecipeMembers(String recipeId) {
    return sl<perm.PermissionService>().canInviteToRecipe(recipeId);
  }

  List<String> getActiveEditors(String recipeId) {
    return _realtimeViewModel.getActiveEditors(recipeId);
  }

  // ===== REALTIME OPERATIONS (Delegate to RealtimeRecipeViewModel) =====

  Stream<Recipe> watchRecipe(String recipeId) {
    return _realtimeViewModel.watchRecipe(recipeId);
  }

  Stream<List<Recipe>> watchMultipleRecipes(List<String> recipeIds) {
    return _realtimeViewModel.watchMultipleRecipes(recipeIds);
  }

  Future<bool> startRealtimeEditing(String recipeId) async {
    return await _realtimeViewModel.startRealtimeEditing(recipeId);
  }

  Future<bool> stopRealtimeEditing(String recipeId) async {
    return await _realtimeViewModel.stopRealtimeEditing(recipeId);
  }

  Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    String? editDescription,
  }) async {
    return await _realtimeViewModel.makeRealtimeEdit(
      recipeId: recipeId,
      changes: changes,
      editDescription: editDescription,
    );
  }

  bool get isRealtimeConnected => _realtimeViewModel.isRealtimeConnected;
  Stream<bool> get realtimeConnectionStream => _realtimeViewModel.realtimeConnectionStream;

  // ===== ERROR HANDLING =====

  void clearError() {
    _recipeService.clearError();
  }

  // ===== ANALYTICS & INSIGHTS =====

  Map<String, dynamic> get recipeInsights {
    return _queryViewModel.recipeInsights;
  }

  List<MapEntry<String, int>> getMostUsedMealTypes() {
    return _queryViewModel.getMostUsedMealTypes();
  }

  List<MapEntry<String, int>> getMostUsedTags() {
    return _queryViewModel.getMostUsedTags();
  }

  // ===== STATE MANAGEMENT =====

  @override
  void dispose() {
    _recipeService.removeListener(_onServiceUpdate);
    _personalViewModel.removeListener(_onServiceUpdate);
    _socialViewModel.removeListener(_onServiceUpdate);
    _realtimeViewModel.removeListener(_onServiceUpdate);
    _queryViewModel.removeListener(_onServiceUpdate);
    
    _personalViewModel.dispose();
    _socialViewModel.dispose();
    _realtimeViewModel.dispose();
    _queryViewModel.dispose();
    
    super.dispose();
  }

  // ===== DEBUGGING & DEVELOPMENT =====

  Map<String, dynamic> get debugInfo {
    return {
      'recipesCount': recipes.length,
      'personalRecipesCount': personalRecipeCount,
      'collaborativeRecipesCount': collaborativeRecipeCount,
      'isInitialized': isInitialized,
      'isLoading': isLoading,
      'hasError': hasError,
      'error': error,
      'currentUserId': currentUserId,
      'serviceState': {
        'isOnline': isOnline,
        'isSyncing': isSyncing,
      },
      'focusedViewModels': {
        'personal': _personalViewModel.serviceName,
        'social': _socialViewModel.serviceName,
        'realtime': _realtimeViewModel.serviceName,
        'query': _queryViewModel.serviceName,
      },
    };
  }

  void printDebugInfo() {
    debugPrint('=== UNIFIED RECIPE DEBUG INFO ===');
    debugInfo.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('==================================');
  }
}