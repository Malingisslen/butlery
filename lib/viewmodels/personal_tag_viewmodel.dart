import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// ViewModel for managing personal tags, groups, and automation rules.
///
/// Provides state management and operations for:
/// - CRUD operations on PersonalTag and PersonalTagGroup
/// - CRUD operations on embedded PersonalTagRule
/// - Real-time updates via streams
class PersonalTagViewModel extends ChangeNotifier
    with ErrorHandlingMixin, StateNotifierMixin, AsyncOperationMixin {
  final PersonalTagService _service;

  // State
  List<PersonalTag> _tags = [];
  List<PersonalTagGroup> _groups = [];
  Map<String, int> _tagUsageCounts = {};
  Map<String, int> _ruleMatchCounts = {};
  // Primary isLoading and error provided by StateNotifierMixin
  bool _isLoadingStats = false;
  bool _isLoadingRuleStats = false;
  String? _selectedTagId;
  bool _isDisposed = false;

  // Stream subscriptions
  StreamSubscription<PersonalTagsWithGroups>? _tagsWithGroupsSubscription;

  PersonalTagViewModel({PersonalTagService? service})
      : _service = service ?? ServiceLocator.get<PersonalTagService>();

  // Getters
  List<PersonalTag> get tags => List.unmodifiable(_tags);
  List<PersonalTagGroup> get groups => List.unmodifiable(_groups);
  // isLoading, error, hasError provided by StateNotifierMixin
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

  /// Retry configuration for initialization failures.
  static const _maxRetryAttempts = 3;
  static const _initialRetryDelay = Duration(seconds: 1);
  int _retryAttempts = 0;

  /// Loads all tags and groups and starts watching for updates.
  /// Automatically retries with exponential backoff on failure.
  Future<void> initialize() async {
    setLoading(true);
    clearError();

    try {
      _tags = await _service.getAllTags();
      _groups = await _service.getAllGroups();

      _watchTagsWithGroups();

      _retryAttempts = 0;
      setLoading(false);

      AppLogger.info(
        'PersonalTagViewModel initialized with '
        '${_tags.length} tags, ${_groups.length} groups',
      );
    } catch (e, stack) {
      AppLogger.error('Failed to initialize PersonalTagViewModel', stack);

      if (!isDisposed && _retryAttempts < _maxRetryAttempts) {
        _retryAttempts++;
        final delay = _initialRetryDelay * (1 << (_retryAttempts - 1));
        AppLogger.info(
          'Retrying PersonalTagViewModel init in ${delay.inSeconds}s '
          '(attempt $_retryAttempts/$_maxRetryAttempts)',
        );
        // Loading stays true during retry delay — no flicker
        await Future.delayed(delay);
        if (isDisposed) return;
        return initialize();
      }

      setError(AppLocale.current.errorCouldNotLoadTags);
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
        setError(AppLocale.current.errorTagUpdateFailed);
      },
    );
  }

  /// Selects a tag for rule management.
  void selectTag(String? tagId) {
    _selectedTagId = tagId;
    _safeNotifyListeners();
  }

  /// Creates a new personal tag.
  Future<bool> createTag({
    required String name,
    String? groupId,
  }) async {
    clearError();

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
      setError(AppLocale.current.errorCouldNotCreateTag);
    }
    return result ?? false;
  }

  /// Updates an existing personal tag.
  Future<bool> updateTag(PersonalTag tag) async {
    clearError();

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
      setError(AppLocale.current.errorCouldNotUpdateTag);
    }
    return result ?? false;
  }

  /// Deletes a personal tag (including all embedded rules).
  Future<bool> deleteTag(String tagId) async {
    clearError();

    final tag = getTagById(tagId);
    if (tag == null) {
      setError(AppLocale.current.errorTagNotFound);
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
      setError(AppLocale.current.errorCouldNotDeleteTag);
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

  /// Creates a new tag group.
  Future<bool> createGroup({
    required String name,
  }) async {
    clearError();

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
      setError(AppLocale.current.errorCouldNotCreateGroup);
    }
    return result ?? false;
  }

  /// Updates an existing group.
  Future<bool> updateGroup(PersonalTagGroup group) async {
    clearError();

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
      setError(AppLocale.current.errorCouldNotUpdateGroup);
    }
    return result ?? false;
  }

  /// Deletes a group (tags become ungrouped).
  Future<bool> deleteGroup(String groupId) async {
    clearError();

    final group = getGroupById(groupId);
    if (group == null) {
      setError(AppLocale.current.errorGroupNotFound);
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
      setError(AppLocale.current.errorCouldNotDeleteGroup);
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

  /// Creates a new automation rule for a tag.
  Future<bool> createRule(String tagId, PersonalTagRule rule) async {
    clearError();

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
      setError(AppLocale.current.errorCouldNotCreateRule);
    }
    return result ?? false;
  }

  /// Updates an existing rule within a tag.
  Future<bool> updateRule(String tagId, PersonalTagRule rule) async {
    clearError();

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
      setError(AppLocale.current.errorCouldNotUpdateRule);
    }
    return result ?? false;
  }

  /// Deletes a rule from a tag.
  Future<bool> deleteRule(String tagId, String ruleId) async {
    clearError();

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
      setError(AppLocale.current.errorCouldNotDeleteRule);
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

  /// Loads usage statistics for all tags.
  ///
  /// #8: Optimized to use single query + local aggregation.
  /// Previously O(n) sequential queries, now O(1) query + O(recipes × tags) aggregation.
  Future<void> loadTagStatistics() async {
    if (_tags.isEmpty) return;

    _isLoadingStats = true;
    _safeNotifyListeners();

    try {
      final recipeRepo = ServiceLocator.get<RecipeRepository>();

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
  /// Uses service-level evaluation to get proper ingredient lookup and userId,
  /// ensuring property-based and ownership rules are evaluated correctly.
  Future<void> loadRuleEffectiveness() async {
    final hasRules = _tags.any((tag) => tag.rules.isNotEmpty);
    if (!hasRules) return;

    _isLoadingRuleStats = true;
    _safeNotifyListeners();

    try {
      final recipeRepo = ServiceLocator.get<RecipeRepository>();
      final recipes = await _getAllUserRecipes(recipeRepo);

      if (recipes.isEmpty) {
        _ruleMatchCounts = {};
        return;
      }

      // Use service-level evaluation for proper lookup + userId
      final sourcesMap =
          await _service.evaluateRulesWithSourcesForRecipes(recipes);

      // Build per-rule match counts from the sources map
      // sourcesMap: recipeId → (tagId → [ruleId, ...])
      final counts = <String, int>{};
      for (final tagSourcesMap in sourcesMap.values) {
        // Collect unique ruleIds matched for this recipe
        final matchedRuleIds = <String>{};
        for (final ruleIds in tagSourcesMap.values) {
          matchedRuleIds.addAll(ruleIds);
        }
        for (final ruleId in matchedRuleIds) {
          counts[ruleId] = (counts[ruleId] ?? 0) + 1;
        }
      }

      _ruleMatchCounts = counts;
      AppLogger.info('Loaded effectiveness stats for ${counts.length} rules');
    } catch (e, stack) {
      AppLogger.error('Failed to load rule effectiveness', stack);
    } finally {
      _isLoadingRuleStats = false;
      _safeNotifyListeners();
    }
  }

  /// Applies all enabled rules to existing recipes.
  ///
  /// Returns a result with the number of recipes processed and tags applied.
  Future<BatchApplyResult> applyRulesToExistingRecipes({
    void Function(int completed, int total)? onProgress,
  }) async {
    final recipeRepo = ServiceLocator.get<RecipeRepository>();

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

      // Get current tag version for staleness tracking
      final tagVersion = await _service.getCurrentTagVersion();

      // Evaluate rules with source tracking for all recipes
      final matchingSources =
          await _service.evaluateRulesWithSourcesForRecipes(recipes);
      if (matchingSources.isEmpty) {
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

        final tagSourcesMap = matchingSources[recipe.id];
        if (tagSourcesMap == null || tagSourcesMap.isEmpty) continue;

        // Get matching tag objects for ID and name
        final matchingTagObjects = tagSourcesMap.keys
            .map((id) => getTagById(id))
            .whereType<PersonalTag>()
            .toList();

        if (matchingTagObjects.isEmpty) continue;

        // Merge IDs into personalTagIds (UUIDs for Firestore queries)
        final existingIds = recipe.personalTagIds?.toSet() ?? <String>{};
        final idsToAdd = matchingTagObjects
            .map((t) => t.id)
            .where((id) => !existingIds.contains(id))
            .toSet();

        if (idsToAdd.isEmpty) continue;

        final mergedIds = [...existingIds, ...idsToAdd];

        // Merge into personalTags (rich objects with actual rule source tracking)
        var mergedPersonalTags = recipe.core.personalTags != null
            ? List<RecipePersonalTag>.from(recipe.core.personalTags!)
            : <RecipePersonalTag>[];
        for (final tag in matchingTagObjects) {
          if (idsToAdd.contains(tag.id)) {
            final ruleIds = tagSourcesMap[tag.id] ?? [];
            final sources = ruleIds.map((id) => 'rule-$id').toList();
            final ruleTag = RecipePersonalTag(
              tagId: tag.id,
              name: tag.name,
              sources: sources.isNotEmpty ? sources : ['rule-unknown'],
            );
            mergedPersonalTags = mergedPersonalTags.addOrUpdate(ruleTag);
          }
        }

        final updatedRecipe = recipe.copyWith(
          personalTagIds: mergedIds,
          personalTags: mergedPersonalTags,
          personalTagVersion: tagVersion,
        );

        await recipeRepo.update(updatedRecipe);
        recipesModified++;
        totalTagsApplied += idsToAdd.length;
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

  /// Gets all user recipes using cursor-based pagination.
  /// No hard limit - fetches all recipes in batches of 500.
  Future<List<Recipe>> _getAllUserRecipes(RecipeRepository recipeRepo) async {
    final userId = ServiceLocator.get<PermissionService>().currentUserId;
    if (userId == null) return [];

    return await recipeRepo.fetchAllUserRecipes(userId);
  }

  /// Checks if a tag name already exists.
  Future<bool> tagNameExists(String name, {String? excludeId}) async {
    return await _service.tagNameExists(name, excludeId: excludeId);
  }

  /// Validates tag name synchronously (for form validation).
  String? validateTagName(String? name) {
    return PersonalTag.validateName(name);
  }

  // clearError() provided by StateNotifierMixin

  @override
  void dispose() {
    _isDisposed = true;
    _tagsWithGroupsSubscription?.cancel();
    cancelAllOperations();
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
