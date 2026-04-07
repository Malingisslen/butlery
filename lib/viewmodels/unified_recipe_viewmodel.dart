/// Streamlined unified recipe ViewModel providing essential recipe management operations.
/// Serves as a facade coordinating specialized ViewModels for recipe operations while
/// maintaining the 500-line file size limit. For advanced operations, access focused
/// ViewModels directly.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/types/recipe_types.dart'
    show RecipeOperationResult;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_insights.dart';

// Import focused ViewModels
import 'package:butlery/viewmodels/recipe/personal_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/recipe/realtime_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Streamlined unified recipe ViewModel facade for essential recipe operations.
class UnifiedRecipeViewModel extends ChangeNotifier with StreamManagementMixin {
  StreamSubscription? _recipeServiceSubscription;
  final UnifiedRecipeService _recipeService =
      ServiceLocator.get<UnifiedRecipeService>();

  /// Personal recipe operations ViewModel
  late final PersonalRecipeViewModel _personalViewModel;

  /// Social recipe operations ViewModel
  late final SocialRecipeViewModel _socialViewModel;

  /// Real-time editing ViewModel
  late final RealtimeRecipeViewModel _realtimeViewModel;

  /// Recipe querying and analytics ViewModel
  late final RecipeQueryViewModel _queryViewModel;

  UnifiedRecipeViewModel() {
    // Initialize focused ViewModels
    _personalViewModel = PersonalRecipeViewModel();
    _socialViewModel = SocialRecipeViewModel(
      friendsService: ServiceLocator.get(),
      recipeService: ServiceLocator.get(),
      userService: ServiceLocator.get(),
    );
    _realtimeViewModel = RealtimeRecipeViewModel();
    _queryViewModel = RecipeQueryViewModel();

    // Set up state synchronization
    _recipeServiceSubscription =
        _recipeService.stateStream.listen((_) => _onServiceUpdate());
    _personalViewModel.addListener(_onServiceUpdate);
    _socialViewModel.addListener(_onServiceUpdate);
    _realtimeViewModel.addListener(_onServiceUpdate);
    _queryViewModel.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    notifyListeners();
  }

  /// Access to personal recipe operations
  PersonalRecipeViewModel get personal => _personalViewModel;

  /// Access to social recipe operations
  SocialRecipeViewModel get social => _socialViewModel;

  /// Access to real-time editing operations
  RealtimeRecipeViewModel get realtime => _realtimeViewModel;

  /// Access to recipe querying operations
  RecipeQueryViewModel get query => _queryViewModel;
  List<Recipe> get allRecipes => _recipeService.recipes;
  List<Recipe> get recipes => _recipeService.recipes;
  List<Recipe> get personalRecipes => _recipeService.personalRecipes;
  List<Recipe> get collaborativeRecipes => _recipeService.collaborativeRecipes;

  bool get isLoading => _recipeService.isLoading;
  bool get isSyncing => _recipeService.isSyncing;
  bool get isInitialized => _recipeService.isInitialized;
  String? get error => _recipeService.error;
  bool get hasError => _recipeService.hasError;
  bool get isOnline => !hasError && isInitialized;

  bool get hasRecipes => _recipeService.hasRecipes;
  bool get hasPersonalRecipes => personalRecipes.isNotEmpty;
  bool get hasCollaborativeRecipes => collaborativeRecipes.isNotEmpty;

  String? get currentUserId => _recipeService.currentUserId;
  String? get currentUserDisplayName => _recipeService.currentUserDisplayName;

  int get totalRecipes => recipes.length;
  int get personalRecipeCount => personalRecipes.length;
  int get collaborativeRecipeCount => collaborativeRecipes.length;

  /// Initialize the unified recipe system
  Future<void> initialize() async {
    await _recipeService.initialize();
  }

  /// Create a personal recipe
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
    List<String>? personalTagIds,
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
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
    );
  }

  /// Create a collaborative recipe
  Future<bool> createCollaborativeRecipe({
    required String name,
    required List<String> memberIds,
    Map<String, String> memberDisplayNames = const {},
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
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
      personalTagIds: personalTagIds,
      sourceUrl: sourceUrl,
    );
  }

  /// Update a recipe
  Future<bool> updateRecipe(Recipe recipe) async {
    if (recipe.isPersonal) {
      return await _personalViewModel.updatePersonalRecipe(recipe);
    } else {
      return await _recipeService.updateRecipe(recipe);
    }
  }

  /// Delete a recipe
  Future<bool> deleteRecipe(String recipeId) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;

    if (recipe.isPersonal) {
      return await _personalViewModel.deletePersonalRecipe(recipeId);
    } else {
      return await _recipeService.deleteRecipe(recipeId);
    }
  }

  /// Share a recipe with other users
  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    Map<String, String> memberDisplayNames = const {},
  }) async {
    return await _socialViewModel.shareRecipe(
      recipeId: recipeId,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
    );
  }

  /// Convert collaborative recipe to personal
  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    return await _socialViewModel.makeRecipePersonal(collaborativeRecipeId);
  }

  Future<RecipeOperationResult> addRecipe(Recipe recipe) async {
    return await _personalViewModel.addLegacyRecipe(recipe);
  }

  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    return await _personalViewModel.updateLegacyRecipe(recipe);
  }

  Future<RecipeOperationResult> deleteRecipeById(String id) async {
    try {
      final success = await _recipeService.deleteRecipe(id);
      return success
          ? RecipeOperationResult.success('Recipe deleted successfully')
          : RecipeOperationResult.failure('Failed to delete recipe');
    } catch (e) {
      return RecipeOperationResult.failure('$e');
    }
  }

  /// Refresh all recipe data
  Future<void> refresh() async {
    await _recipeService.refresh();
  }

  /// Get recipe by ID from unified collection
  Recipe? getUnifiedRecipeById(String id) {
    return _recipeService.getRecipeById(id);
  }

  /// Get recipes by meal type
  List<Recipe> getRecipesByMealType(String mealType) {
    return _queryViewModel.getRecipesByMealType(mealType);
  }

  /// Get all used meal types
  List<String> get usedMealTypes {
    return _queryViewModel.usedMealTypes;
  }

  /// Get all used tags
  List<String> get usedTags {
    return _queryViewModel.usedTags;
  }

  /// Clear error state
  void clearError() {
    _recipeService.clearError();
  }

  /// Get recipe insights and statistics
  RecipeInsights get recipeInsights {
    return _queryViewModel.recipeInsights;
  }

  /// Check if real-time editing is connected
  bool get isRealtimeConnected => _realtimeViewModel.isRealtimeConnected;

  /// Stream for real-time connection status
  Stream<bool> get realtimeConnectionStream =>
      _realtimeViewModel.realtimeConnectionStream;

  @override
  void dispose() {
    // Clean up listeners
    _recipeServiceSubscription?.cancel();
    _personalViewModel.removeListener(_onServiceUpdate);
    _socialViewModel.removeListener(_onServiceUpdate);
    _realtimeViewModel.removeListener(_onServiceUpdate);
    _queryViewModel.removeListener(_onServiceUpdate);

    // Dispose focused ViewModels
    _personalViewModel.dispose();
    _socialViewModel.dispose();
    _realtimeViewModel.dispose();
    _queryViewModel.dispose();

    // Clean up streams
    disposeStreamResources();
    super.dispose();
  }
}
