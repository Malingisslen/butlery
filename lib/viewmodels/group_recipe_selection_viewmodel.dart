// lib/viewmodels/group_recipe_selection_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// ViewModel for selecting and sharing recipes with a group
class GroupRecipeSelectionViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  final FriendCategory targetGroup;
  final List<UserProfile> groupMembers;

  GroupRecipeSelectionViewModel({
    required UnifiedRecipeService recipeService,
    required this.targetGroup,
    required this.groupMembers,
  }) : _recipeService = recipeService;

  // State
  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  final Set<String> _selectedRecipeIds = {};
  final Set<String> _alreadySharedRecipeIds = {};
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isSharing = false;
  String? _error;

  // Getters
  List<Recipe> get filteredRecipes => _filteredRecipes;
  int get filteredCount => _filteredRecipes.length;
  int get totalCount => _allRecipes.length;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isSharing => _isSharing;
  bool get hasError => _error != null;
  String? get error => _error;
  bool get isEmpty => _allRecipes.isEmpty;
  bool get hasSelectedRecipes => _selectedRecipeIds.isNotEmpty;
  int get selectedCount => _selectedRecipeIds.length;

  List<Recipe> get selectedRecipes =>
      _allRecipes.where((r) => _selectedRecipeIds.contains(r.id)).toList();

  /// Load user's recipes
  Future<void> loadRecipes() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('📚 Laddar recept för gruppdelning');

      // Load personal recipes from cached list
      _allRecipes = _recipeService.recipes.toList();

      // Check which recipes are already shared with group members
      await _loadAlreadySharedRecipes();

      _applyFilters();
      _setLoading(false);

      AppLogger.success('✅ ${_allRecipes.length} recept laddade');
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av recept', e);
      _setError('Kunde inte ladda recept. Försök igen.');
      _setLoading(false);
    }
  }

  /// Check which recipes are already shared with any group member
  Future<void> _loadAlreadySharedRecipes() async {
    try {
      final sharedRecipeIds = <String>{};

      for (final recipe in _allRecipes) {
        // Check if recipe is collaborative and has any group member as member
        if (recipe.isCollaborative && recipe.socialData?.memberPermissions != null) {
          final recipeMembers = recipe.socialData!.memberPermissions!.keys.toSet();
          final groupMemberIds = targetGroup.friendUserIds.toSet();

          // If any group member is already a member of this recipe, mark as shared
          if (recipeMembers.intersection(groupMemberIds).isNotEmpty) {
            sharedRecipeIds.add(recipe.id);
          }
        }
      }

      _alreadySharedRecipeIds.addAll(sharedRecipeIds);

      AppLogger.debug('Found ${sharedRecipeIds.length} recipes already shared with group members');
    } catch (e) {
      AppLogger.error('Error loading shared recipes', e);
    }
  }

  /// Toggle recipe selection
  void toggleRecipeSelection(String recipeId) {
    if (_selectedRecipeIds.contains(recipeId)) {
      _selectedRecipeIds.remove(recipeId);
    } else {
      _selectedRecipeIds.add(recipeId);
    }
    notifyListeners();
  }

  /// Check if recipe is selected
  bool isRecipeSelected(String recipeId) => _selectedRecipeIds.contains(recipeId);

  /// Check if recipe is already shared with group
  bool isRecipeAlreadyShared(String recipeId) => _alreadySharedRecipeIds.contains(recipeId);

  /// Clear all selections
  void clearSelections() {
    _selectedRecipeIds.clear();
    notifyListeners();
  }

  /// Clear search
  void clearSearch() {
    setSearchQuery('');
  }

  /// Set search query and filter recipes
  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _applyFilters();
  }

  /// Share selected recipes with all group members
  Future<bool> shareSelectedRecipes() async {
    if (_selectedRecipeIds.isEmpty || _isSharing) return false;

    _setSharing(true);
    _clearError();

    try {
      AppLogger.info('📤 Delar ${_selectedRecipeIds.length} recept med grupp ${targetGroup.name}');

      final recipes = selectedRecipes;
      final memberIds = targetGroup.friendUserIds;

      // Create display names map
      final memberDisplayNames = <String, String>{};
      for (final member in groupMembers) {
        memberDisplayNames[member.uid] = member.displayName;
      }

      for (final recipe in recipes) {
        final success = await _recipeService.social.shareRecipe(
          recipeId: recipe.id,
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
        );

        if (success == null) {
          throw Exception('Kunde inte dela recept: ${recipe.title}');
        }
      }

      // Add shared recipes to already-shared list
      _alreadySharedRecipeIds.addAll(_selectedRecipeIds);
      clearSelections();

      _setSharing(false);
      AppLogger.success('✅ Recept delade med grupp ${targetGroup.name}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Fel vid delning av recept', e);
      _setError('Kunde inte dela recept. Försök igen.');
      _setSharing(false);
      return false;
    }
  }

  /// Apply filters and sorting
  void _applyFilters() {
    var filtered = _allRecipes;

    // Apply text search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((recipe) {
        final titleMatch = recipe.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final descMatch = recipe.description.toLowerCase().contains(_searchQuery.toLowerCase());
        return titleMatch || descMatch;
      }).toList();
    }

    // Sort: unshared first, then alphabetically
    filtered.sort((a, b) {
      final aShared = _alreadySharedRecipeIds.contains(a.id);
      final bShared = _alreadySharedRecipeIds.contains(b.id);

      if (aShared != bShared) {
        return aShared ? 1 : -1; // Unshared first
      }
      return a.title.compareTo(b.title); // Alphabetical
    });

    _filteredRecipes = filtered;
    notifyListeners();
  }

  /// Success message for sharing
  String get successMessage {
    if (_selectedRecipeIds.length == 1) {
      final recipe = selectedRecipes.first;
      return '${recipe.title} delat med ${targetGroup.name}! 🍽️';
    } else {
      return '${_selectedRecipeIds.length} recept delade med ${targetGroup.name}! 🍽️';
    }
  }

  // Private state setters
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSharing(bool sharing) {
    _isSharing = sharing;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
