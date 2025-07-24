/// 🔍 AI INFO BLOCK:
/// Component: Unified Recipe ViewModel - Updated for Phase 5 feature interfaces
/// File: lib/viewmodels/unified_recipe_viewmodel.dart
/// Quick Guide: Main recipe ViewModel using feature interfaces from UnifiedRecipeService
/// Dependencies IN: UnifiedRecipeService with feature interfaces
/// Dependencies OUT: Used by recipe list views and related UI components
/// Data flow: UI -> ViewModel -> Feature Interfaces -> UnifiedRecipeService
/// State management: ChangeNotifier with reactive getters from service
/// Purpose: UI state management for all recipe operations with clean interface separation
/// Common issues: Loading states, error handling, reactive updates
/// Test coverage: ViewModel tests with mocked service interfaces
/// Performance: Reactive getters, efficient state updates
/// Analytics: Recipe view events, user interaction tracking
/// Code smells: None - follows MVVM pattern with clean separation
/// Connected to: Recipe views, UnifiedRecipeService feature interfaces
/// Used in phases: Phase 5 - Service Consolidation (updated for feature interfaces)

// lib/viewmodels/unified_recipe_viewmodel.dart
// ✅ PHASE 5 VERSION: Updated to use feature interfaces

/// 🧠 UNIFIED RECIPE VIEWMODEL
/// Updated for Phase 5: Uses feature interfaces for clean separation
/// Personal operations: service.personal.*
/// Social operations: service.social.*
/// Realtime operations: service.realtime.*

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../services/unified/unified_recipe_service.dart';
import '../services/permission_service.dart';
import '../core/injection.dart';
import '../core/permissions/permission_mixins.dart';
import '../services/unified/types/recipe_types.dart' show RecipeOperationResult;
import '../models/permissions/resource_permission.dart';
import '../models/recipe_unified.dart';

class UnifiedRecipeViewModel extends ChangeNotifier with BasePermissionMixin, RecipePermissionMixin {
  final UnifiedRecipeService _recipeService =
      GetIt.instance<UnifiedRecipeService>();

  // ===== GETTERS - samma API som din befintliga recipe_list_viewmodel =====

  // ✅ FIX: Lägg till allRecipes getter som injection.dart förväntar sig
  List<Recipe> get allRecipes => _recipeService.recipes;

  // Recipes och state
  List<Recipe> get recipes => _recipeService.recipes;
  List<Recipe> get personalRecipes => _recipeService.personalRecipes;
  List<Recipe> get collaborativeRecipes =>
      _recipeService.collaborativeRecipes;


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

  // ===== PERSONAL RECIPE OPERATIONS (Phase 5: Feature Interface) =====

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

    final recipeId = await _recipeService.personal.createRecipe(
      title: name.trim(),
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

  // ===== SOCIAL RECIPE OPERATIONS (Phase 5: Feature Interface) =====

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
    if (name.trim().isEmpty) return false;

    final recipeId = await _recipeService.createCollaborativeRecipe(
      title: name.trim(),
      memberIds: memberIds,
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

    return recipeId != null;
  }

  /// Share a personal recipe with other users
  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    return await _recipeService.social.shareRecipe(
      recipeId: recipeId,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      collaborativeDescription: collaborativeDescription,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  /// Convert collaborative recipe back to personal
  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    return await _recipeService.social.makeRecipePersonal(
      collaborativeRecipeId: collaborativeRecipeId,
    );
  }

  Future<bool> updateRecipe(Recipe recipe) async {
    // Route to appropriate interface based on recipe type
    if (recipe.isPersonal) {
      return await _recipeService.personal.updateRecipe(recipe);
    } else {
      return await _recipeService.updateRecipe(recipe); // Collaborative recipes handled by main service
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    // Route to appropriate interface based on recipe type
    if (recipe.isPersonal) {
      return await _recipeService.personal.deleteRecipe(recipeId);
    } else {
      return await _recipeService.deleteRecipe(recipeId); // Fallback to main service
    }
  }

  // ===== LEGACY COMPATIBILITY METHODS =====

  /// Add unified recipe
  Future<RecipeOperationResult> addRecipe(Recipe recipe) async {
    return await _recipeService.personal.addLegacyRecipe(recipe);
  }

  /// Update unified recipe
  Future<RecipeOperationResult> updateLegacyRecipe(Recipe recipe) async {
    return await _recipeService.personal.updateLegacyRecipe(recipe);
  }

  /// För befintlig kod
  Future<RecipeOperationResult> deleteRecipeById(String id) async {
    return await _recipeService.deleteRecipeById(id);
  }

  /// Get recipe by ID (unified)
  Recipe? getRecipeById(String id) {
    return _recipeService.getRecipeById(id);
  }

  /// Legacy method för befintlig kod
  Future<void> refresh() async {
    await _recipeService.refresh();
  }

  // ===== CONTENT EDITING METHODS (Personal & Collaborative) =====

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
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    // Route to appropriate interface based on recipe type
    if (recipe.isPersonal) {
      return await _recipeService.personal.updateRecipeContent(
        recipeId: recipeId,
        title: name,
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

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _recipeService.personal.addIngredient(recipeId, ingredient);
    } else {
      return await _recipeService.addIngredient(recipeId, ingredient);
    }
  }

  Future<bool> updateIngredient(String recipeId, int index, String newIngredient) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _recipeService.personal.updateIngredient(recipeId, index, newIngredient);
    } else {
      return await _recipeService.updateIngredient(recipeId, index, newIngredient);
    }
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _recipeService.personal.removeIngredient(recipeId, index);
    } else {
      return await _recipeService.removeIngredient(recipeId, index);
    }
  }

  Future<bool> addInstruction(String recipeId, String instruction) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _recipeService.personal.addInstruction(recipeId, instruction);
    } else {
      return await _recipeService.addInstruction(recipeId, instruction);
    }
  }

  Future<bool> updateInstruction(String recipeId, int index, String newInstruction) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _recipeService.personal.updateInstruction(recipeId, index, newInstruction);
    } else {
      return await _recipeService.updateInstruction(recipeId, index, newInstruction);
    }
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _recipeService.personal.removeInstruction(recipeId, index);
    } else {
      return await _recipeService.removeInstruction(recipeId, index);
    }
  }

  Future<bool> markRecipeAsCooked(String recipeId) async {
    final recipe = getUnifiedRecipeById(recipeId);
    if (recipe == null) return false;
    
    if (recipe.isPersonal) {
      return await _recipeService.personal.markAsCooked(recipeId);
    } else {
      return await _recipeService.markRecipeAsCooked(recipeId);
    }
  }

  // ===== SOCIAL MEMBER MANAGEMENT (Phase 5: Feature Interface) =====

  Future<bool> addMemberToRecipe(
      String recipeId, String userId, String userDisplayName, 
      {ResourcePermission permission = ResourcePermission.editor}) async {
    return await _recipeService.addMemberToRecipe(recipeId, userId, permission);
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _recipeService.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(
      String recipeId, String userId, ResourcePermission permission) async {
    return await _recipeService.updateMemberPermission(recipeId, userId, permission);
  }

  /// Get all members of a collaborative recipe
  Map<String, ResourcePermission> getRecipeMembers(String recipeId) {
    final recipe = _recipeService.recipes.where((r) => r.id == recipeId).firstOrNull;
    return recipe?.socialData?.memberPermissions ?? {};
  }

  /// Check if user can invite members to recipe
  bool canInviteMembers(String recipeId) {
    return _recipeService.social.canInviteMembers(recipeId);
  }

  /// Get recipes shared with current user
  List<Recipe> getSharedWithMe() {
    return recipes.where((recipe) => 
      recipe.isShared && 
      recipe.socialData?.ownerId != _recipeService.currentUserId
    ).toList();
  }

  /// Get recipes owned by current user that are shared
  List<Recipe> getSharedByMe() {
    return recipes.where((recipe) => 
      recipe.isShared && 
      recipe.socialData?.ownerId == _recipeService.currentUserId
    ).toList();
  }

  // ===== RECIPE QUERIES & FILTERING =====

  /// Hitta recept by ID (unified version)
  Recipe? getUnifiedRecipeById(String id) {
    return recipes.where((r) => r.id == id).firstOrNull;
  }

  /// Filtrera recept baserat på mealType
  List<Recipe> getRecipesByMealType(String mealType) {
    return recipes.where((r) => r.mealType == mealType).toList();
  }

  /// Filtrera recept baserat på tags
  List<Recipe> getRecipesByTag(String tag) {
    return recipes.where((r) => r.tags?.contains(tag) ?? false).toList();
  }

  /// Sök i recept baserat på namn, ingredienser eller instruktioner
  List<Recipe> searchRecipes(String query) {
    if (query.trim().isEmpty) return recipes;

    final lowercaseQuery = query.toLowerCase();
    return recipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowercaseQuery) ||
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
  List<Recipe> getEditableRecipes() {
    if (currentUserId == null) return [];

    return recipes.where((recipe) {
      if (recipe.isPersonal) return isRecipeOwner(recipe.id);
      return canEditRecipe(recipe.id);
    }).toList();
  }

  /// Få recept som nyligen tillagats
  List<Recipe> getRecentlyCookedRecipes() {
    return recipes.where((recipe) => 
      recipe.lastCookedAt != null &&
      DateTime.now().difference(recipe.lastCookedAt!).inDays < 7
    ).toList();
  }

  /// Gruppera recept efter måltidstyp
  Map<String, List<Recipe>> get recipesByMealType {
    final Map<String, List<Recipe>> grouped = {};

    for (final recipe in recipes) {
      grouped.putIfAbsent(recipe.mealType, () => []).add(recipe);
    }

    // Sortera måltidstyper och recept
    final sortedGrouped = <String, List<Recipe>>{};
    final sortedKeys = grouped.keys.toList()..sort();

    for (final key in sortedKeys) {
      final sortedRecipes = grouped[key]!;
      sortedRecipes.sort((a, b) => a.title.compareTo(b.title));
      sortedGrouped[key] = sortedRecipes;
    }

    return sortedGrouped;
  }

  /// Få alla använda måltidstyper
  List<String> get usedMealTypes {
    final mealTypes = recipes.map<String>((recipe) => recipe.mealType).toSet().toList();
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

  /// Kontrollera om användaren kan hantera medlemmar i specifikt recept
  bool canManageRecipeMembers(String recipeId) {
    return sl<PermissionService>().canInviteToRecipe(recipeId);
  }

  /// Få aktiva editorer för specifikt recept
  List<String> getActiveEditors(String recipeId) {
    return _recipeService.realtime.getActiveEditors(recipeId);
  }

  // ===== REALTIME OPERATIONS (Phase 5: Feature Interface) =====

  /// Watch a recipe for real-time updates
  Stream<Recipe> watchRecipe(String recipeId) {
    // Use the proper real-time watching from RealtimeRecipeOperations
    return _recipeService.realtime.watchRecipe(recipeId);
  }

  /// Watch multiple recipes for real-time updates
  Stream<List<Recipe>> watchMultipleRecipes(List<String> recipeIds) {
    return _recipeService.realtime.watchMultipleRecipes(recipeIds);
  }

  /// Start real-time editing session for recipe
  Future<bool> startRealtimeEditing(String recipeId) async {
    return await _recipeService.realtime.startRealtimeEditing(recipeId);
  }

  /// Stop real-time editing session for recipe
  Future<bool> stopRealtimeEditing(String recipeId) async {
    return await _recipeService.realtime.stopRealtimeEditing(recipeId);
  }

  /// Make real-time edit to recipe
  Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    String? editDescription,
  }) async {
    return await _recipeService.realtime.makeRealtimeEdit(
      recipeId: recipeId,
      changes: changes,
      editDescription: editDescription,
    );
  }

  /// Get real-time connection status
  bool get isRealtimeConnected => _recipeService.realtime.isConnected;

  /// Get real-time connection status stream
  Stream<bool> get realtimeConnectionStream => _recipeService.realtime.connectionStream;

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
