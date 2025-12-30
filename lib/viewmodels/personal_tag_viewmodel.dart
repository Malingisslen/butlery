import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';

/// ViewModel for managing personal tags and automation rules.
///
/// Provides state management and operations for:
/// - CRUD operations on PersonalTag
/// - CRUD operations on PersonalTagRule
/// - Real-time updates via streams
class PersonalTagViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final PersonalTagService _service;

  // State
  List<PersonalTag> _tags = [];
  List<PersonalTagRule> _rules = [];
  Map<String, int> _tagUsageCounts = {};
  bool _isLoading = false;
  bool _isLoadingStats = false;
  String? _error;
  String? _selectedTagId;

  // Stream subscriptions
  StreamSubscription<List<PersonalTag>>? _tagsSubscription;
  StreamSubscription<List<PersonalTagRule>>? _rulesSubscription;

  PersonalTagViewModel({PersonalTagService? service})
      : _service = service ?? ServiceLocator.get<PersonalTagService>();

  // Getters
  List<PersonalTag> get tags => List.unmodifiable(_tags);
  List<PersonalTagRule> get rules => List.unmodifiable(_rules);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get selectedTagId => _selectedTagId;

  PersonalTag? get selectedTag =>
      _selectedTagId != null ? getTagById(_selectedTagId!) : null;

  bool get hasTags => _tags.isNotEmpty;
  bool get hasRules => _rules.isNotEmpty;
  Map<String, int> get tagUsageCounts => Map.unmodifiable(_tagUsageCounts);
  bool get isLoadingStats => _isLoadingStats;

  /// Gets recipe count for a specific tag name.
  int getUsageCount(String tagName) => _tagUsageCounts[tagName] ?? 0;

  // Tag lookup helpers
  PersonalTag? getTagById(String id) {
    return _tags.where((t) => t.id == id).firstOrNull;
  }

  PersonalTag? getTagByName(String name) {
    final normalizedName = name.toLowerCase().trim();
    return _tags.where((t) => t.name.toLowerCase() == normalizedName).firstOrNull;
  }

  List<PersonalTagRule> getRulesForTag(String tagId) {
    return _rules.where((r) => r.tagId == tagId).toList();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Loads all tags and starts watching for updates.
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      // Load initial data
      _tags = await _service.getAllTags();

      // Start watching for real-time updates
      _watchTags();

      AppLogger.info('PersonalTagViewModel initialized with ${_tags.length} tags');
    } catch (e, stack) {
      AppLogger.error('Failed to initialize PersonalTagViewModel', stack);
      _setError('Kunde inte ladda taggar');
    } finally {
      _setLoading(false);
    }
  }

  void _watchTags() {
    _tagsSubscription?.cancel();
    _tagsSubscription = _service.watchTags().listen(
      (tags) {
        _tags = tags;
        notifyListeners();
      },
      onError: (e) {
        AppLogger.error('Tag stream error: $e');
        _setError('Fel vid uppdatering av taggar');
      },
    );
  }

  /// Watches rules for a specific tag.
  void watchRulesForTag(String tagId) {
    _rulesSubscription?.cancel();
    _selectedTagId = tagId;

    _rulesSubscription = _service.watchRulesForTag(tagId).listen(
      (rules) {
        _rules = rules;
        notifyListeners();
      },
      onError: (e) {
        AppLogger.error('Rule stream error: $e');
      },
    );
  }

  /// Watches all rules for management UI.
  void watchAllRules() {
    _rulesSubscription?.cancel();
    _selectedTagId = null;

    _rulesSubscription = _service.watchAllRules().listen(
      (rules) {
        _rules = rules;
        notifyListeners();
      },
      onError: (e) {
        AppLogger.error('Rule stream error: $e');
      },
    );
  }

  /// Stops watching rules (when leaving rule management view).
  void stopWatchingRules() {
    _rulesSubscription?.cancel();
    _rulesSubscription = null;
    _rules = [];
    _selectedTagId = null;
    notifyListeners();
  }

  // ============================================================
  // TAG CRUD OPERATIONS
  // ============================================================

  /// Creates a new personal tag.
  Future<bool> createTag({
    required String name,
    String? color,
    String? icon,
  }) async {
    _clearError();

    final result = await safeExecute(
      () async {
        final sortOrder = await _service.getNextSortOrder();
        final tag = PersonalTag.create(
          name: name,
          color: color,
          icon: icon,
          sortOrder: sortOrder,
        );

        final created = await _service.createTag(tag);
        if (created != null) {
          AppLogger.success('Created personal tag: $name');
          return true;
        }
        return false;
      },
      operationName: 'Create personal tag',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte skapa taggen');
    }
    return result ?? false;
  }

  /// Updates an existing personal tag.
  Future<bool> updateTag(PersonalTag tag) async {
    _clearError();

    final result = await safeExecute(
      () async {
        await _service.updateTag(tag);
        AppLogger.success('Updated personal tag: ${tag.name}');
        return true;
      },
      operationName: 'Update personal tag',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte uppdatera taggen');
    }
    return result ?? false;
  }

  /// Deletes a personal tag and all its rules.
  Future<bool> deleteTag(String tagId) async {
    _clearError();

    final tag = getTagById(tagId);
    if (tag == null) {
      _setError('Taggen hittades inte');
      return false;
    }

    final result = await safeExecute(
      () async {
        await _service.deleteTag(tagId);
        AppLogger.warning('Deleted personal tag: ${tag.name}');
        return true;
      },
      operationName: 'Delete personal tag',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte ta bort taggen');
    }
    return result ?? false;
  }

  /// Reorders tags.
  Future<bool> reorderTags(List<String> tagIds) async {
    final result = await safeExecute(
      () async {
        await _service.reorderTags(tagIds);
        return true;
      },
      operationName: 'Reorder tags',
      defaultValue: false,
    );
    return result ?? false;
  }

  // ============================================================
  // RULE CRUD OPERATIONS
  // ============================================================

  /// Creates a new automation rule.
  Future<bool> createRule(PersonalTagRule rule) async {
    _clearError();

    final result = await safeExecute(
      () async {
        final created = await _service.createRule(rule);
        if (created != null) {
          AppLogger.success('Created rule: ${rule.name}');
          return true;
        }
        return false;
      },
      operationName: 'Create rule',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte skapa regeln');
    }
    return result ?? false;
  }

  /// Updates an existing rule.
  Future<bool> updateRule(PersonalTagRule rule) async {
    _clearError();

    final result = await safeExecute(
      () async {
        await _service.updateRule(rule);
        AppLogger.success('Updated rule: ${rule.name}');
        return true;
      },
      operationName: 'Update rule',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte uppdatera regeln');
    }
    return result ?? false;
  }

  /// Deletes a rule.
  Future<bool> deleteRule(String ruleId) async {
    _clearError();

    final result = await safeExecute(
      () async {
        await _service.deleteRule(ruleId);
        AppLogger.warning('Deleted rule: $ruleId');
        return true;
      },
      operationName: 'Delete rule',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte ta bort regeln');
    }
    return result ?? false;
  }

  /// Toggles rule enabled state.
  Future<bool> toggleRuleEnabled(String ruleId) async {
    final rule = _rules.where((r) => r.id == ruleId).firstOrNull;
    if (rule == null) return false;

    final result = await safeExecute(
      () async {
        await _service.setRuleEnabled(ruleId, enabled: !rule.isEnabled);
        return true;
      },
      operationName: 'Toggle rule enabled',
      defaultValue: false,
    );
    return result ?? false;
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  /// Loads usage statistics for all tags.
  ///
  /// Queries the recipe repository to count how many recipes use each tag.
  Future<void> loadTagStatistics() async {
    if (_tags.isEmpty) return;

    _isLoadingStats = true;
    notifyListeners();

    try {
      final recipeRepo = ServiceLocator.get<FirebaseRecipeRepository>();
      final counts = <String, int>{};

      // Query count for each tag name
      for (final tag in _tags) {
        final count = await recipeRepo.countRecipesWithPersonalTag(tag.name);
        counts[tag.name] = count;
      }

      _tagUsageCounts = counts;
      AppLogger.info('Loaded usage stats for ${_tags.length} tags');
    } catch (e, stack) {
      AppLogger.error('Failed to load tag statistics', stack);
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  // ============================================================
  // BATCH OPERATIONS
  // ============================================================

  /// Applies all enabled rules to existing recipes.
  ///
  /// Returns a result with the number of recipes processed and tags applied.
  Future<BatchApplyResult> applyRulesToExistingRecipes({
    void Function(int completed, int total)? onProgress,
  }) async {
    final recipeRepo = ServiceLocator.get<FirebaseRecipeRepository>();

    try {
      // Get all user recipes
      final recipes = await _getAllUserRecipes(recipeRepo);
      if (recipes.isEmpty) {
        return const BatchApplyResult(
          recipesProcessed: 0,
          recipesModified: 0,
          tagsApplied: 0,
        );
      }

      // Evaluate rules for all recipes
      final matchingTags = await _service.evaluateRulesForRecipes(recipes);
      if (matchingTags.isEmpty) {
        onProgress?.call(recipes.length, recipes.length);
        return BatchApplyResult(
          recipesProcessed: recipes.length,
          recipesModified: 0,
          tagsApplied: 0,
        );
      }

      // Apply tags to recipes
      int recipesModified = 0;
      int totalTagsApplied = 0;
      int processed = 0;

      for (final recipe in recipes) {
        processed++;
        onProgress?.call(processed, recipes.length);

        final newTagIds = matchingTags[recipe.id];
        if (newTagIds == null || newTagIds.isEmpty) continue;

        // Convert tag IDs to names
        final newTagNames = newTagIds
            .map((id) => getTagById(id)?.name)
            .whereType<String>()
            .toSet();

        if (newTagNames.isEmpty) continue;

        // Merge with existing tags
        final existingTags = recipe.personalTags?.toSet() ?? <String>{};
        final tagsToAdd = newTagNames.difference(existingTags);

        if (tagsToAdd.isEmpty) continue;

        // Update recipe with new tags
        final updatedTags = [...existingTags, ...tagsToAdd];
        final updatedRecipe = recipe.copyWith(personalTags: updatedTags);

        await recipeRepo.update(updatedRecipe);
        recipesModified++;
        totalTagsApplied += tagsToAdd.length;
      }

      AppLogger.success(
        'Batch apply: $recipesModified recipes modified, '
        '$totalTagsApplied tags applied',
      );

      // Refresh statistics after batch apply
      await loadTagStatistics();

      return BatchApplyResult(
        recipesProcessed: recipes.length,
        recipesModified: recipesModified,
        tagsApplied: totalTagsApplied,
      );
    } catch (e, stack) {
      AppLogger.error('Failed to batch apply rules', stack);
      rethrow;
    }
  }

  /// Gets all user recipes from the repository.
  Future<List<Recipe>> _getAllUserRecipes(
    FirebaseRecipeRepository recipeRepo,
  ) async {
    // Use the repository's getAll method which is inherited from base
    final userId = recipeRepo.currentUserId;
    if (userId == null) return [];

    // Get recipes ordered by update date, limited for performance
    final snap = await recipeRepo.getCollectionForUser(userId)
        .orderBy('core.updatedAt', descending: true)
        .limit(500)  // Process max 500 recipes per batch
        .get();

    return snap.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
  }

  // ============================================================
  // VALIDATION HELPERS
  // ============================================================

  /// Checks if a tag name already exists.
  Future<bool> tagNameExists(String name, {String? excludeId}) async {
    return await _service.tagNameExists(name, excludeId: excludeId);
  }

  /// Validates tag name synchronously (for form validation).
  String? validateTagName(String? name) {
    return PersonalTag.validateName(name);
  }

  // ============================================================
  // STATE MANAGEMENT
  // ============================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Clears any error state.
  void clearError() => _clearError();

  @override
  void dispose() {
    _tagsSubscription?.cancel();
    _rulesSubscription?.cancel();
    super.dispose();
  }
}

/// Result of a batch apply operation.
class BatchApplyResult {
  /// Number of recipes that were processed.
  final int recipesProcessed;

  /// Number of recipes that had new tags applied.
  final int recipesModified;

  /// Total number of tag applications (one recipe can have multiple tags).
  final int tagsApplied;

  const BatchApplyResult({
    required this.recipesProcessed,
    required this.recipesModified,
    required this.tagsApplied,
  });

  /// Returns true if any recipes were modified.
  bool get hasChanges => recipesModified > 0;
}
