// lib/viewmodels/recipe/recipe_query_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/services/analytics_service.dart';

/// Recipe Query ViewModel
/// Handles ONLY recipe querying, filtering, searching, and analytics operations.
/// This includes search functionality, filtering by various criteria, and providing insights.
/// Performance optimizations:
/// - Debounced search (300ms) to prevent excessive filtering
/// - Result caching to avoid redundant computations
/// - Cache invalidation on filter changes
class RecipeQueryViewModel extends ChangeNotifier
    with
        ErrorHandlingMixin,
        StreamManagementMixin,
        StateNotifierMixin,
        AsyncOperationMixin {
  final UnifiedRecipeService _recipeService =
      ServiceLocator.get<UnifiedRecipeService>();
  late final AnalyticsService? _analyticsService =
      ServiceLocator.tryGet<AnalyticsService>();

  String get serviceName => 'RecipeQueryViewModel';

  // Current filter state
  String _searchQuery = '';
  String? _selectedMealType;
  String? _selectedTag;
  RecipeType? _selectedType;

  // Performance optimization: Cache filtered results
  List<Recipe>? _cachedFilteredRecipes;
  String _lastSearchQuery = '';
  String? _lastMealType;
  String? _lastTag;
  RecipeType? _lastType;
  List<Recipe> get allRecipes => _recipeService.recipes;
  List<Recipe> get personalRecipes => _recipeService.personalRecipes;
  List<Recipe> get collaborativeRecipes => _recipeService.collaborativeRecipes;

  bool get hasRecipes => _recipeService.hasRecipes;
  bool get hasPersonalRecipes => personalRecipes.isNotEmpty;
  bool get hasCollaborativeRecipes => collaborativeRecipes.isNotEmpty;

  String? get currentUserId => _recipeService.currentUserId;

  // Filter state getters
  String get searchQuery => _searchQuery;
  String? get selectedMealType => _selectedMealType;
  String? get selectedTag => _selectedTag;
  RecipeType? get selectedType => _selectedType;
  Recipe? getRecipeById(String id) {
    if (ValidationUtils.isNullOrEmpty(id)) return null;
    return allRecipes.where((r) => r.id == id).firstOrNull;
  }

  List<Recipe> getRecipesByMealType(String mealType) {
    if (ValidationUtils.isNullOrEmpty(mealType)) return [];
    return allRecipes.where((r) => r.mealType == mealType).toList();
  }

  List<Recipe> getRecipesByTag(String tag) {
    if (ValidationUtils.isNullOrEmpty(tag)) return [];
    return allRecipes
        .where((r) => (r.personalTagIds?.contains(tag)).orFalse())
        .toList();
  }

  List<Recipe> getRecipesByType(RecipeType type) {
    return allRecipes.where((r) => r.type == type).toList();
  }

  List<Recipe> searchRecipes(String query) {
    if (query.trim().isEmpty) return allRecipes;

    final lowercaseQuery = query.toLowerCase();
    return allRecipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowercaseQuery) ||
          recipe.description.toLowerCase().contains(lowercaseQuery) ||
          recipe.ingredients.any((ingredient) =>
              ingredient.toLowerCase().contains(lowercaseQuery)) ||
          recipe.instructions.any((instruction) =>
              instruction.toLowerCase().contains(lowercaseQuery)) ||
          (recipe.core.personalTags
                  ?.any((t) => t.name.toLowerCase().contains(lowercaseQuery)))
              .orFalse();
    }).toList();
  }

  /// Update search query with debouncing (300ms)
  /// Prevents excessive filtering during typing
  Future<void> updateSearchQuery(String query) async {
    await executeDebounced(
      'recipeSearch',
      () async {
        _searchQuery = query;
        _invalidateCache();
        notifyListeners();

        if (query.trim().isNotEmpty) {
          _analyticsService?.recipe.logRecipeSearchPerformed(
            searchQuery: query,
            resultsCount: filteredRecipes.length,
            filtersApplied: hasActiveFilters ? _activeFilterNames : null,
          );
        }
      },
      const Duration(milliseconds: 300),
    );
  }

  List<String> get _activeFilterNames {
    final filters = <String>[];
    if (_selectedMealType != null) filters.add('mealType');
    if (_selectedTag != null) filters.add('tag');
    if (_selectedType != null) filters.add('type');
    return filters;
  }

  void clearSearch() {
    _searchQuery = '';
    _invalidateCache();
    notifyListeners();
  }

  /// Invalidate the filtered results cache
  void _invalidateCache() {
    _cachedFilteredRecipes = null;
  }

  /// Get filtered recipes with caching to prevent redundant computations
  List<Recipe> get filteredRecipes {
    // Check if cache is valid
    if (_cachedFilteredRecipes != null &&
        _lastSearchQuery == _searchQuery &&
        _lastMealType == _selectedMealType &&
        _lastTag == _selectedTag &&
        _lastType == _selectedType) {
      return _cachedFilteredRecipes!;
    }

    // Cache is invalid, recompute filtered results
    List<Recipe> recipes = allRecipes;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      recipes = searchRecipes(_searchQuery);
    }

    // Apply meal type filter
    if (_selectedMealType != null) {
      recipes = recipes.where((r) => r.mealType == _selectedMealType).toList();
    }

    // Apply tag filter
    if (_selectedTag != null) {
      recipes = recipes
          .where((r) => (r.personalTagIds?.contains(_selectedTag)).orFalse())
          .toList();
    }

    // Apply type filter
    if (_selectedType != null) {
      recipes = recipes.where((r) => r.type == _selectedType).toList();
    }

    // Update cache
    _cachedFilteredRecipes = recipes;
    _lastSearchQuery = _searchQuery;
    _lastMealType = _selectedMealType;
    _lastTag = _selectedTag;
    _lastType = _selectedType;

    return recipes;
  }

  void setMealTypeFilter(String? mealType) {
    _selectedMealType = mealType;
    _invalidateCache();
    notifyListeners();
  }

  @Deprecated('Use RecipeListViewModel.togglePersonalTagFilter instead')
  void setTagFilter(String? tag) {
    _selectedTag = tag;
    _invalidateCache();
    notifyListeners();
  }

  void setTypeFilter(RecipeType? type) {
    _selectedType = type;
    _invalidateCache();
    notifyListeners();
  }

  void clearFilters() {
    _selectedMealType = null;
    _selectedTag = null;
    _selectedType = null;
    _invalidateCache();
    notifyListeners();
  }

  void clearAllFiltersAndSearch() {
    _searchQuery = '';
    _invalidateCache();
    clearFilters();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedMealType != null ||
      _selectedTag != null ||
      _selectedType != null;
  List<Recipe> getEditableRecipes() {
    if (currentUserId == null) return [];

    return allRecipes.where((recipe) {
      if (recipe.isPersonal) {
        return recipe.createdBy == currentUserId;
      } else {
        // Check if user has edit permissions for collaborative recipe
        final permissions = recipe.socialData?.memberPermissions;
        if (permissions == null) return false;

        final userPermission = permissions[currentUserId];
        return userPermission == ResourcePermission.admin ||
            userPermission == ResourcePermission.editor;
      }
    }).toList();
  }

  List<Recipe> getRecentlyCookedRecipes({int daysBack = 7}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
    return allRecipes
        .where((recipe) =>
            recipe.lastCookedAt != null &&
            recipe.lastCookedAt!.isAfter(cutoffDate))
        .toList();
  }

  List<Recipe> getRecentlyCreatedRecipes({int daysBack = 7}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
    return allRecipes
        .where((recipe) => recipe.createdAt.isAfter(cutoffDate))
        .toList();
  }

  List<Recipe> getRecentlyEditedRecipes({int daysBack = 7}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
    return allRecipes
        .where((recipe) => recipe.updatedAt.isAfter(cutoffDate))
        .toList();
  }

  List<Recipe> getFavoriteRecipes() {
    // For now, consider recipes with rating >= 4.5 as favorites
    // In the future, this would be based on user-specific favorite flags
    return allRecipes
        .where((recipe) => recipe.rating != null && recipe.rating! >= 4.5)
        .toList()
      ..sort((a, b) => (b.rating).orZero().compareTo((a.rating).orZero()));
  }

  List<Recipe> getHighRatedRecipes({double minRating = 4.0}) {
    return allRecipes
        .where((recipe) => recipe.rating != null && recipe.rating! >= minRating)
        .toList();
  }

  List<Recipe> getRecipesWithImages() {
    return allRecipes.where((recipe) => recipe.imageUrls.isNotEmpty).toList();
  }

  List<Recipe> getRecipesWithoutImages() {
    return allRecipes.where((recipe) => recipe.imageUrls.isEmpty).toList();
  }

  List<Recipe> getSharedWithMe() {
    if (currentUserId == null) return [];

    return collaborativeRecipes
        .where((recipe) =>
            recipe.isShared && recipe.socialData?.ownerId != currentUserId)
        .toList();
  }

  List<Recipe> getSharedByMe() {
    if (currentUserId == null) return [];

    return collaborativeRecipes
        .where((recipe) =>
            recipe.isShared && recipe.socialData?.ownerId == currentUserId)
        .toList();
  }

  List<Recipe> getRecipesWithCollaborator(String userId) {
    if (ValidationUtils.isNullOrEmpty(userId)) return [];

    return collaborativeRecipes
        .where((recipe) =>
            (recipe.socialData?.memberPermissions?.containsKey(userId))
                .orFalse())
        .toList();
  }

  Map<String, List<Recipe>> get recipesByMealType {
    final Map<String, List<Recipe>> grouped = {};

    for (final recipe in filteredRecipes) {
      grouped.putIfAbsent(recipe.mealType, () => []).add(recipe);
    }

    // Sort meal types and recipes
    final sortedGrouped = <String, List<Recipe>>{};
    final sortedKeys = grouped.keys.toList()..sort();

    for (final key in sortedKeys) {
      final sortedRecipes = grouped[key]!;
      sortedRecipes.sort((a, b) => a.title.compareTo(b.title));
      sortedGrouped[key] = sortedRecipes;
    }

    return sortedGrouped;
  }

  Map<String, List<Recipe>> get recipesByTag {
    final Map<String, List<Recipe>> grouped = {};

    for (final recipe in filteredRecipes) {
      if (recipe.core.personalTags != null) {
        for (final pt in recipe.core.personalTags!) {
          grouped.putIfAbsent(pt.name, () => []).add(recipe);
        }
      }
    }

    // Sort tags and recipes
    final sortedGrouped = <String, List<Recipe>>{};
    final sortedKeys = grouped.keys.toList()..sort();

    for (final key in sortedKeys) {
      final sortedRecipes = grouped[key]!;
      sortedRecipes.sort((a, b) => a.title.compareTo(b.title));
      sortedGrouped[key] = sortedRecipes;
    }

    return sortedGrouped;
  }

  Map<RecipeType, List<Recipe>> get recipesByType {
    final Map<RecipeType, List<Recipe>> grouped = {};

    for (final recipe in filteredRecipes) {
      grouped.putIfAbsent(recipe.type, () => []).add(recipe);
    }

    return grouped;
  }

  List<String> get usedMealTypes {
    final mealTypes =
        allRecipes.map<String>((recipe) => recipe.mealType).toSet().toList();
    mealTypes.sort();
    return mealTypes;
  }

  List<String> get usedTags {
    final allTags = <String>{};
    for (final recipe in allRecipes) {
      if (recipe.core.personalTags != null) {
        allTags.addAll(recipe.core.personalTags!.map((t) => t.name));
      }
    }
    final tagsList = allTags.toList();
    tagsList.sort();
    return tagsList;
  }

  List<RecipeType> get usedTypes {
    return allRecipes.map((recipe) => recipe.type).toSet().toList();
  }

  Map<String, dynamic> get recipeInsights {
    return {
      'totalRecipes': allRecipes.length,
      'personalRecipes': personalRecipes.length,
      'collaborativeRecipes': collaborativeRecipes.length,
      'filteredRecipes': filteredRecipes.length,
      'mealTypes': usedMealTypes.length,
      'tags': usedTags.length,
      'recentlyCookedCount': getRecentlyCookedRecipes().length,
      'editableCount': getEditableRecipes().length,
      'favoriteCount': getFavoriteRecipes().length,
      'withImagesCount': getRecipesWithImages().length,
      'highRatedCount': getHighRatedRecipes().length,
      'hasCollaborativeFeatures': hasCollaborativeRecipes,
      'hasActiveFilters': hasActiveFilters,
    };
  }

  List<MapEntry<String, int>> getMostUsedMealTypes() {
    final mealTypeCounts = <String, int>{};

    for (final recipe in allRecipes) {
      mealTypeCounts[recipe.mealType] =
          (mealTypeCounts[recipe.mealType]).orZero() + 1;
    }

    final sortedEntries = mealTypeCounts.entries.toList();
    sortedEntries.sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries;
  }

  List<MapEntry<String, int>> getMostUsedTags() {
    final tagCounts = <String, int>{};

    for (final recipe in allRecipes) {
      if (recipe.core.personalTags != null) {
        for (final pt in recipe.core.personalTags!) {
          tagCounts[pt.name] = (tagCounts[pt.name]).orZero() + 1;
        }
      }
    }

    final sortedEntries = tagCounts.entries.toList();
    sortedEntries.sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries;
  }

  Map<String, double> getAverageRatingsByMealType() {
    final mealTypeRatings = <String, List<double>>{};

    for (final recipe in allRecipes) {
      if (recipe.rating != null) {
        mealTypeRatings
            .putIfAbsent(recipe.mealType, () => [])
            .add(recipe.rating!);
      }
    }

    final averages = <String, double>{};
    mealTypeRatings.forEach((mealType, ratings) {
      averages[mealType] =
          ratings.reduce((a, b) => a + b) / ratings.length.toDouble();
    });

    return averages;
  }

  Map<String, int> getCookingFrequencyByMealType() {
    final cookingCounts = <String, int>{};

    for (final recipe in allRecipes) {
      if (recipe.lastCookedAt != null) {
        cookingCounts[recipe.mealType] =
            (cookingCounts[recipe.mealType]).orZero() + 1;
      }
    }

    return cookingCounts;
  }

  @override
  void dispose() {
    // Cancel all timers and debounced operations
    cancelAllOperations(); // From AsyncOperationMixin
    // Cancel all stream subscriptions
    disposeStreamResources(); // From StreamManagementMixin
    // Dispose of resources
    super.dispose();
  }
}
