import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';

/// ViewModel for managing personal tags, groups, and automation rules.
///
/// Provides state management and operations for:
/// - CRUD operations on PersonalTag and PersonalTagGroup
/// - CRUD operations on embedded PersonalTagRule
/// - Real-time updates via streams
class PersonalTagViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final PersonalTagService _service;

  // State
  List<PersonalTag> _tags = [];
  List<PersonalTagGroup> _groups = [];
  Map<String, int> _tagUsageCounts = {};
  Map<String, int> _ruleMatchCounts = {};
  bool _isLoading = false;
  bool _isLoadingStats = false;
  bool _isLoadingRuleStats = false;
  String? _error;
  String? _selectedTagId;
  bool _isDisposed = false;

  // Stream subscriptions
  StreamSubscription<PersonalTagsWithGroups>? _tagsWithGroupsSubscription;

  PersonalTagViewModel({PersonalTagService? service})
      : _service = service ?? ServiceLocator.get<PersonalTagService>();

  // Getters
  List<PersonalTag> get tags => List.unmodifiable(_tags);
  List<PersonalTagGroup> get groups => List.unmodifiable(_groups);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get selectedTagId => _selectedTagId;

  PersonalTag? get selectedTag =>
      _selectedTagId != null ? getTagById(_selectedTagId!) : null;

  bool get hasTags => _tags.isNotEmpty;
  bool get hasGroups => _groups.isNotEmpty;
  Map<String, int> get tagUsageCounts => Map.unmodifiable(_tagUsageCounts);
  Map<String, int> get ruleMatchCounts => Map.unmodifiable(_ruleMatchCounts);
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingRuleStats => _isLoadingRuleStats;

  /// Gets all enabled rules across all tags.
  List<PersonalTagRule> get enabledRules {
    final rules = <PersonalTagRule>[];
    for (final tag in _tags) {
      for (final rule in tag.rules) {
        if (rule.isEnabled) {
          rules.add(rule);
        }
      }
    }
    return rules;
  }

  /// Gets all rules from selected tag.
  List<PersonalTagRule> get selectedTagRules {
    final tag = selectedTag;
    return tag?.rules ?? [];
  }

  /// Gets recipe count for a specific tag name.
  int getUsageCount(String tagName) => _tagUsageCounts[tagName] ?? 0;

  /// Gets the number of recipes that would match a specific rule.
  int getRuleMatchCount(String ruleId) => _ruleMatchCounts[ruleId] ?? 0;

  // Tag lookup helpers
  PersonalTag? getTagById(String id) {
    return _tags.where((t) => t.id == id).firstOrNull;
  }

  PersonalTag? getTagByName(String name) {
    final normalizedName = name.toLowerCase().trim();
    return _tags
        .where((t) => t.name.toLowerCase() == normalizedName)
        .firstOrNull;
  }

  PersonalTagGroup? getGroupById(String id) {
    return _groups.where((g) => g.id == id).firstOrNull;
  }

  List<PersonalTag> getTagsForGroup(String? groupId) {
    return _tags.where((t) => t.groupId == groupId).toList();
  }

  List<PersonalTagRule> getRulesForTag(String tagId) {
    final tag = getTagById(tagId);
    return tag?.rules ?? [];
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Retry configuration for initialization failures.
  static const _maxRetryAttempts = 3;
  static const _initialRetryDelay = Duration(seconds: 1);
  int _retryAttempts = 0;

  /// Loads all tags and groups and starts watching for updates.
  /// Automatically retries with exponential backoff on failure.
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      // Load initial data
      _tags = await _service.getAllTags();
      _groups = await _service.getAllGroups();

      // Reset retry counter on success
      _retryAttempts = 0;

      // Start watching for real-time updates
      _watchTagsWithGroups();

      AppLogger.info(
        'PersonalTagViewModel initialized with '
        '${_tags.length} tags, ${_groups.length} groups',
      );
    } catch (e, stack) {
      AppLogger.error('Failed to initialize PersonalTagViewModel', stack);

      // Retry with exponential backoff
      if (_retryAttempts < _maxRetryAttempts) {
        _retryAttempts++;
        final delay = _initialRetryDelay * (1 << (_retryAttempts - 1));
        AppLogger.info(
          'Retrying PersonalTagViewModel init in ${delay.inSeconds}s '
          '(attempt $_retryAttempts/$_maxRetryAttempts)',
        );
        await Future.delayed(delay);
        return initialize();
      }

      _setError('Kunde inte ladda taggar');
    } finally {
      _setLoading(false);
    }
  }

  void _watchTagsWithGroups() {
    _tagsWithGroupsSubscription?.cancel();
    _tagsWithGroupsSubscription = _service.watchTagsWithGroups().listen(
      (data) {
        _tags = data.tagsByGroup.values.expand((t) => t).toList();
        _groups = data.groups;
        _safeNotifyListeners();
      },
      onError: (e) {
        AppLogger.error('Tags/groups stream error: $e');
        _setError('Fel vid uppdatering av taggar');
      },
    );
  }

  /// Selects a tag for rule management.
  void selectTag(String? tagId) {
    _selectedTagId = tagId;
    _safeNotifyListeners();
  }

  // ============================================================
  // TAG CRUD OPERATIONS
  // ============================================================

  /// Creates a new personal tag.
  Future<bool> createTag({
    required String name,
    String? groupId,
  }) async {
    _clearError();

    final result = await safeExecute(
      () async {
        final sortOrder = await _service.getNextTagSortOrder();
        final tag = PersonalTag.create(
          name: name,
          sortOrder: sortOrder,
          groupId: groupId,
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

  /// Deletes a personal tag (including all embedded rules).
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

  /// Moves a tag to a group.
  Future<bool> moveTagToGroup(String tagId, String? groupId) async {
    final result = await safeExecute(
      () async {
        await _service.moveTagToGroup(tagId, groupId);
        return true;
      },
      operationName: 'Move tag to group',
      defaultValue: false,
    );
    return result ?? false;
  }

  // ============================================================
  // GROUP CRUD OPERATIONS
  // ============================================================

  /// Creates a new tag group.
  Future<bool> createGroup({
    required String name,
  }) async {
    _clearError();

    final result = await safeExecute(
      () async {
        final sortOrder = await _service.getNextGroupSortOrder();
        final group = PersonalTagGroup.create(
          name: name,
          sortOrder: sortOrder,
        );

        final created = await _service.createGroup(group);
        if (created != null) {
          AppLogger.success('Created personal tag group: $name');
          return true;
        }
        return false;
      },
      operationName: 'Create personal tag group',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte skapa gruppen');
    }
    return result ?? false;
  }

  /// Updates an existing group.
  Future<bool> updateGroup(PersonalTagGroup group) async {
    _clearError();

    final result = await safeExecute(
      () async {
        await _service.updateGroup(group);
        AppLogger.success('Updated personal tag group: ${group.name}');
        return true;
      },
      operationName: 'Update personal tag group',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte uppdatera gruppen');
    }
    return result ?? false;
  }

  /// Deletes a group (tags become ungrouped).
  Future<bool> deleteGroup(String groupId) async {
    _clearError();

    final group = getGroupById(groupId);
    if (group == null) {
      _setError('Gruppen hittades inte');
      return false;
    }

    final result = await safeExecute(
      () async {
        await _service.deleteGroup(groupId);
        AppLogger.warning('Deleted personal tag group: ${group.name}');
        return true;
      },
      operationName: 'Delete personal tag group',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte ta bort gruppen');
    }
    return result ?? false;
  }

  /// Reorders groups.
  Future<bool> reorderGroups(List<String> groupIds) async {
    final result = await safeExecute(
      () async {
        await _service.reorderGroups(groupIds);
        return true;
      },
      operationName: 'Reorder groups',
      defaultValue: false,
    );
    return result ?? false;
  }

  // ============================================================
  // RULE CRUD OPERATIONS (EMBEDDED IN TAGS)
  // ============================================================

  /// Creates a new automation rule for a tag.
  Future<bool> createRule(String tagId, PersonalTagRule rule) async {
    _clearError();

    final result = await safeExecute(
      () async {
        await _service.addRuleToTag(tagId, rule);
        AppLogger.success('Created rule: ${rule.name}');
        return true;
      },
      operationName: 'Create rule',
      defaultValue: false,
    );

    if (result != true) {
      _setError('Kunde inte skapa regeln');
    }
    return result ?? false;
  }

  /// Updates an existing rule within a tag.
  Future<bool> updateRule(String tagId, PersonalTagRule rule) async {
    _clearError();

    final result = await safeExecute(
      () async {
        await _service.updateRuleInTag(tagId, rule);
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

  /// Deletes a rule from a tag.
  Future<bool> deleteRule(String tagId, String ruleId) async {
    _clearError();

    final result = await safeExecute(
      () async {
        await _service.removeRuleFromTag(tagId, ruleId);
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
  Future<bool> toggleRuleEnabled(String tagId, String ruleId) async {
    final tag = getTagById(tagId);
    final rule = tag?.rules.where((r) => r.id == ruleId).firstOrNull;
    if (rule == null) return false;

    final result = await safeExecute(
      () async {
        await _service.setRuleEnabled(tagId, ruleId, enabled: !rule.isEnabled);
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
  /// #8: Optimized to use single query + local aggregation.
  /// Previously O(n) sequential queries, now O(1) query + O(recipes × tags) aggregation.
  Future<void> loadTagStatistics() async {
    if (_tags.isEmpty) return;

    _isLoadingStats = true;
    _safeNotifyListeners();

    try {
      final recipeRepo = ServiceLocator.get<FirebaseRecipeRepository>();

      // #8: Single query to fetch all recipes
      final recipes = await _getAllUserRecipes(recipeRepo);

      // Build tag lookup map (ID -> name) for efficient mapping
      final tagIdToName = <String, String>{};
      for (final tag in _tags) {
        tagIdToName[tag.id] = tag.name;
      }

      // #8: Local aggregation - O(recipes × avgTagsPerRecipe)
      final idCounts = <String, int>{};
      for (final recipe in recipes) {
        final tagIds = recipe.personalTagIds ?? [];
        for (final tagId in tagIds) {
          idCounts[tagId] = (idCounts[tagId] ?? 0) + 1;
        }
      }

      // Map tag IDs to names for display
      final nameCounts = <String, int>{};
      for (final tag in _tags) {
        nameCounts[tag.name] = idCounts[tag.id] ?? 0;
      }

      _tagUsageCounts = nameCounts;
      AppLogger.info(
        '#8: Loaded usage stats for ${_tags.length} tags from ${recipes.length} recipes',
      );
    } catch (e, stack) {
      AppLogger.error('Failed to load tag statistics', stack);
    } finally {
      _isLoadingStats = false;
      _safeNotifyListeners();
    }
  }

  /// Loads rule effectiveness statistics.
  ///
  /// Calculates how many recipes each rule would match if applied.
  Future<void> loadRuleEffectiveness() async {
    // Collect all rules from all tags
    final allRules = <PersonalTagRule>[];
    for (final tag in _tags) {
      allRules.addAll(tag.rules);
    }

    if (allRules.isEmpty) return;

    _isLoadingRuleStats = true;
    _safeNotifyListeners();

    try {
      final recipeRepo = ServiceLocator.get<FirebaseRecipeRepository>();
      final recipes = await _getAllUserRecipes(recipeRepo);

      if (recipes.isEmpty) {
        _ruleMatchCounts = {};
        return;
      }

      final counts = <String, int>{};

      // For each rule, count how many recipes match
      for (final rule in allRules) {
        int matchCount = 0;
        for (final recipe in recipes) {
          if (rule.evaluate(recipe, null)) {
            matchCount++;
          }
        }
        counts[rule.id] = matchCount;
      }

      _ruleMatchCounts = counts;
      AppLogger.info('Loaded effectiveness stats for ${allRules.length} rules');
    } catch (e, stack) {
      AppLogger.error('Failed to load rule effectiveness', stack);
    } finally {
      _isLoadingRuleStats = false;
      _safeNotifyListeners();
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
        final existingTags = recipe.personalTagIds?.toSet() ?? <String>{};
        final tagsToAdd = newTagNames.difference(existingTags);

        if (tagsToAdd.isEmpty) continue;

        // Update recipe with new tags
        final updatedTags = [...existingTags, ...tagsToAdd];
        final updatedRecipe = recipe.copyWith(personalTagIds: updatedTags);

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
    final snap = await recipeRepo
        .getCollectionForUser(userId)
        .orderBy('core.updatedAt', descending: true)
        .limit(500) // Process max 500 recipes per batch
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
    _safeNotifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _safeNotifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      _safeNotifyListeners();
    }
  }

  /// Clears any error state.
  void clearError() => _clearError();

  @override
  void dispose() {
    _isDisposed = true;
    _tagsWithGroupsSubscription?.cancel();
    super.dispose();
  }

  /// Safely calls notifyListeners only if not disposed.
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
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
