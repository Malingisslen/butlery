// lib/viewmodels/unified_recipe_viewmodel.dart
// ✅ FINAL VERSION: Med alla fixes och allRecipes getter

/// 🧠 UNIFIED RECIPE VIEWMODEL
/// Ersätter recipe_list_viewmodel.dart med alla features
/// Kopplar samman UI med UnifiedRecipeService

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../services/unified/unified_recipe_service.dart';
import '../models/unified/unified_recipe.dart';
import '../models/recipe.dart'; // För backwards compatibility

class UnifiedRecipeViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService =
      GetIt.instance<UnifiedRecipeService>();

  // ===== GETTERS - samma API som din befintliga recipe_list_viewmodel =====

  // ✅ FIX: Lägg till allRecipes getter som injection.dart förväntar sig
  List<UnifiedRecipe> get allRecipes => _recipeService.recipes;

  // Recipes och state
  List<UnifiedRecipe> get recipes => _recipeService.recipes;
  List<UnifiedRecipe> get personalRecipes => _recipeService.personalRecipes;
  List<UnifiedRecipe> get collaborativeRecipes =>
      _recipeService.collaborativeRecipes;

  // Legacy compatibility
  List<Recipe> get legacyRecipes => _recipeService.legacyRecipes;

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
  String? get currentUserId => _recipeService.currentUserId;
  String? get currentUserDisplayName => _recipeService.currentUserDisplayName;

  // Statistics
  int get totalRecipes => recipes.length;
  int get personalRecipeCount => personalRecipes.length;
  int get collaborativeRecipeCount => collaborativeRecipes.length;

  UnifiedRecipeViewModel() {
    // Lyssna på service changes - samma pattern som innan
    _recipeService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    notifyListeners();
  }

  // ===== INITIALIZATION =====

  Future<void> initialize() async {
    try {
      await _recipeService.initialize();
    } catch (e) {
      debugPrint('Fel vid ViewModel initialisering: $e');
    }
  }

  // ===== RECIPE MANAGEMENT - samma metoder som din befintliga ViewModel =====

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
    if (name.trim().isEmpty) return false;

    final recipeId = await _recipeService.createPersonalRecipe(
      name: name.trim(),
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

    return recipeId != null;
  }

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
    String?
        descriptionCollaborative, // ✅ FIX: Ändrat från description_collaborative
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    if (name.trim().isEmpty) return false;

    final recipeId = await _recipeService.createCollaborativeRecipe(
      name: name.trim(),
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
      descriptionCollaborative:
          descriptionCollaborative, // ✅ FIX: Ändrat från description_collaborative
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );

    return recipeId != null;
  }

  Future<bool> updateRecipe(UnifiedRecipe recipe) async {
    return await _recipeService.updateRecipe(recipe);
  }

  Future<bool> deleteRecipe(String recipeId) async {
    return await _recipeService.deleteRecipe(recipeId);
  }

  // ===== LEGACY COMPATIBILITY METHODS =====

  /// För befintlig kod som använder Recipe model
  Future<RecipeOperationResult> addRecipe(Recipe legacyRecipe) async {
    return await _recipeService.addRecipe(legacyRecipe);
  }

  /// För befintlig kod som använder Recipe model
  Future<RecipeOperationResult> updateLegacyRecipe(Recipe legacyRecipe) async {
    return await _recipeService.updateLegacyRecipe(legacyRecipe);
  }

  /// För befintlig kod
  Future<RecipeOperationResult> deleteRecipeById(String id) async {
    return await _recipeService.deleteRecipeById(id);
  }

  /// Legacy getter för befintlig kod
  Recipe? getRecipeById(String id) {
    return _recipeService.getRecipeById(id);
  }

  /// Legacy method för befintlig kod
  Future<void> refresh() async {
    await _recipeService.refresh();
  }

  // ===== COLLABORATIVE EDITING METHODS =====

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
    return await _recipeService.updateRecipeContent(
      recipeId: recipeId,
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

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    return await _recipeService.addIngredient(recipeId, ingredient);
  }

  Future<bool> updateIngredient(
      String recipeId, int index, String newIngredient) async {
    return await _recipeService.updateIngredient(
        recipeId, index, newIngredient);
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    return await _recipeService.removeIngredient(recipeId, index);
  }

  Future<bool> addInstruction(String recipeId, String instruction) async {
    return await _recipeService.addInstruction(recipeId, instruction);
  }

  Future<bool> updateInstruction(
      String recipeId, int index, String newInstruction) async {
    return await _recipeService.updateInstruction(
        recipeId, index, newInstruction);
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    return await _recipeService.removeInstruction(recipeId, index);
  }

  Future<bool> markRecipeAsCooked(String recipeId) async {
    return await _recipeService.markRecipeAsCooked(recipeId);
  }

  // ===== COLLABORATIVE MEMBER MANAGEMENT =====

  Future<bool> addMemberToRecipe(
      String recipeId, String userId, RecipePermission permission) async {
    return await _recipeService.addMemberToRecipe(recipeId, userId, permission);
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _recipeService.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(
      String recipeId, String userId, RecipePermission permission) async {
    return await _recipeService.updateMemberPermission(
        recipeId, userId, permission);
  }

  // ===== RECIPE QUERIES & FILTERING =====

  /// Hitta recept by ID (unified version)
  UnifiedRecipe? getUnifiedRecipeById(String id) {
    return recipes.where((r) => r.id == id).firstOrNull;
  }

  /// Filtrera recept baserat på mealType
  List<UnifiedRecipe> getRecipesByMealType(String mealType) {
    return recipes.where((r) => r.mealType == mealType).toList();
  }

  /// Filtrera recept baserat på tags
  List<UnifiedRecipe> getRecipesByTag(String tag) {
    return recipes.where((r) => r.tags?.contains(tag) ?? false).toList();
  }

  /// Sök i recept baserat på namn, ingredienser eller instruktioner
  List<UnifiedRecipe> searchRecipes(String query) {
    if (query.trim().isEmpty) return recipes;

    final lowercaseQuery = query.toLowerCase();
    return recipes.where((recipe) {
      return recipe.name.toLowerCase().contains(lowercaseQuery) ||
          recipe.description.toLowerCase().contains(lowercaseQuery) ||
          recipe.ingredients.any((ingredient) =>
              ingredient.toLowerCase().contains(lowercaseQuery)) ||
          recipe.instructions.any((instruction) =>
              instruction.toLowerCase().contains(lowercaseQuery)) ||
          (recipe.tags
                  ?.any((tag) => tag.toLowerCase().contains(lowercaseQuery)) ??
              false);
    }).toList();
  }

  /// Få recept som användaren kan redigera
  List<UnifiedRecipe> getEditableRecipes() {
    if (currentUserId == null) return [];

    return recipes.where((recipe) {
      if (recipe.isPersonal) return recipe.ownerId == currentUserId;
      return recipe.canBeEditedBy(currentUserId!);
    }).toList();
  }

  /// Få recept som nyligen tillagats
  List<UnifiedRecipe> getRecentlyCookedRecipes() {
    return recipes.where((recipe) => recipe.wasCookedRecently).toList();
  }

  /// Gruppera recept efter måltidstyp
  Map<String, List<UnifiedRecipe>> get recipesByMealType {
    final Map<String, List<UnifiedRecipe>> grouped = {};

    for (final recipe in recipes) {
      grouped.putIfAbsent(recipe.mealType, () => []).add(recipe);
    }

    // Sortera måltidstyper och recept
    final sortedGrouped = <String, List<UnifiedRecipe>>{};
    final sortedKeys = grouped.keys.toList()..sort();

    for (final key in sortedKeys) {
      final sortedRecipes = grouped[key]!;
      sortedRecipes.sort((a, b) => a.name.compareTo(b.name));
      sortedGrouped[key] = sortedRecipes;
    }

    return sortedGrouped;
  }

  /// Få alla använda måltidstyper
  List<String> get usedMealTypes {
    final mealTypes = recipes.map((recipe) => recipe.mealType).toSet().toList();
    mealTypes.sort();
    return mealTypes;
  }

  /// Få alla använda tags
  List<String> get usedTags {
    final allTags = <String>{};
    for (final recipe in recipes) {
      if (recipe.tags != null) {
        allTags.addAll(recipe.tags!);
      }
    }
    final tagsList = allTags.toList();
    tagsList.sort();
    return tagsList;
  }

  // ===== COLLABORATIVE FEATURES =====

  /// Kontrollera om användaren kan redigera specifikt recept
  bool canEditRecipe(String recipeId) {
    if (currentUserId == null) return false;

    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;

    return recipe.canBeEditedBy(currentUserId!);
  }

  /// Kontrollera om användaren kan hantera medlemmar i specifikt recept
  bool canManageRecipeMembers(String recipeId) {
    if (currentUserId == null) return false;

    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;

    return recipe.canManageMembersBy(currentUserId!);
  }

  /// Få medlemmar i specifikt recept
  List<String> getRecipeMembers(String recipeId) {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null || recipe.isPersonal) return [];

    return recipe.allMemberIds;
  }

  /// Få aktiva editorer för specifikt recept
  List<String> getActiveEditors(String recipeId) {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null || recipe.isPersonal) return [];

    return recipe.currentActiveEditors;
  }

  // ===== ERROR HANDLING =====

  void clearError() {
    _recipeService.clearError();
  }

  // ===== ANALYTICS & INSIGHTS =====

  /// Få recipe insights för UI
  Map<String, dynamic> get recipeInsights {
    return {
      'totalRecipes': totalRecipes,
      'personalRecipes': personalRecipeCount,
      'collaborativeRecipes': collaborativeRecipeCount,
      'mealTypes': usedMealTypes.length,
      'tags': usedTags.length,
      'recentlyCookedCount': getRecentlyCookedRecipes().length,
      'editableCount': getEditableRecipes().length,
      'hasCollaborativeFeatures': hasCollaborativeRecipes,
    };
  }

  /// Få mest använda måltidstyper
  List<MapEntry<String, int>> getMostUsedMealTypes() {
    final mealTypeCounts = <String, int>{};

    for (final recipe in recipes) {
      mealTypeCounts[recipe.mealType] =
          (mealTypeCounts[recipe.mealType] ?? 0) + 1;
    }

    final sortedEntries = mealTypeCounts.entries.toList();
    sortedEntries.sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries;
  }

  /// Få mest använda tags
  List<MapEntry<String, int>> getMostUsedTags() {
    final tagCounts = <String, int>{};

    for (final recipe in recipes) {
      if (recipe.tags != null) {
        for (final tag in recipe.tags!) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }

    final sortedEntries = tagCounts.entries.toList();
    sortedEntries.sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries;
  }

  // ===== STATE MANAGEMENT =====

  @override
  void dispose() {
    _recipeService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  // ===== DEBUGGING & DEVELOPMENT =====

  /// Debug info för utveckling
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
