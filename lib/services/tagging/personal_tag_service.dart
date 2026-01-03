import 'dart:async';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:rxdart/rxdart.dart';

/// Service for managing user-defined personal tags, groups, and automation rules.
///
/// Provides:
/// - CRUD operations for PersonalTag, PersonalTagGroup, and embedded rules
/// - Rule evaluation engine for automatic tag application
/// - Real-time streams for UI updates
///
/// Rules are now embedded within PersonalTag documents rather than stored
/// in a separate collection.
class PersonalTagService extends BaseService {
  final FirebasePersonalTagRepository _tagRepository;
  final FirebasePersonalTagGroupRepository _groupRepository;
  final IngredientLookupService _lookupService;

  static const String _tagsCacheKey = 'personal_tags';
  static const String _groupsCacheKey = 'personal_groups';

  PersonalTagService({
    required FirebasePersonalTagRepository tagRepository,
    required FirebasePersonalTagGroupRepository groupRepository,
    required IngredientLookupService lookupService,
  })  : _tagRepository = tagRepository,
        _groupRepository = groupRepository,
        _lookupService = lookupService;

  @override
  String get serviceName => 'PersonalTagService';

  // ============================================================
  // TAG CRUD OPERATIONS
  // ============================================================

  /// Creates a new personal tag.
  Future<PersonalTag?> createTag(PersonalTag tag) async {
    return await executeServiceOperation(
      () async {
        final nameValidation = PersonalTag.validateName(tag.name);
        if (nameValidation != null) {
          throw ArgumentError(nameValidation);
        }

        if (await _tagRepository.nameExists(tag.name)) {
          throw ArgumentError('En tagg med namnet "${tag.name}" finns redan');
        }

        // Validate groupId exists if specified
        if (tag.groupId != null) {
          final group = await _groupRepository.read(tag.groupId!);
          if (group == null) {
            throw ArgumentError('Gruppen finns inte');
          }
        }

        await _tagRepository.create(tag);
        clearCache(_tagsCacheKey);
        AppLogger.info('Created personal tag: ${tag.name}');
        return tag;
      },
      operationName: 'Create personal tag',
      requiresAuth: true,
    );
  }

  /// Gets a personal tag by ID.
  Future<PersonalTag?> getTag(String tagId) async {
    return await executeServiceOperation<PersonalTag?>(
      () async => await _tagRepository.read(tagId),
      operationName: 'Get personal tag',
      requiresAuth: true,
    );
  }

  /// Gets all personal tags sorted by sortOrder.
  Future<List<PersonalTag>> getAllTags() async {
    return await getCachedOrExecute(
          _tagsCacheKey,
          () => _tagRepository.getAllSorted(),
          cacheDuration: const Duration(minutes: 5),
        ) ??
        [];
  }

  /// Updates a personal tag.
  Future<void> updateTag(PersonalTag tag) async {
    await executeServiceOperation(
      () async {
        final nameValidation = PersonalTag.validateName(tag.name);
        if (nameValidation != null) {
          throw ArgumentError(nameValidation);
        }

        if (await _tagRepository.nameExists(tag.name, excludeId: tag.id)) {
          throw ArgumentError('En tagg med namnet "${tag.name}" finns redan');
        }

        // Validate groupId exists if specified
        if (tag.groupId != null) {
          final group = await _groupRepository.read(tag.groupId!);
          if (group == null) {
            throw ArgumentError('Gruppen finns inte');
          }
        }

        final updated = tag.copyWith(updatedAt: DateTime.now());
        await _tagRepository.update(updated);
        clearCache(_tagsCacheKey);
        AppLogger.info('Updated personal tag: ${tag.name}');
      },
      operationName: 'Update personal tag',
      requiresAuth: true,
    );
  }

  /// Deletes a personal tag.
  /// Embedded rules are automatically deleted with the tag document.
  Future<void> deleteTag(String tagId) async {
    await executeServiceOperation(
      () async {
        await _tagRepository.delete(tagId);
        clearCache(_tagsCacheKey);
        AppLogger.info('Deleted personal tag: $tagId');
      },
      operationName: 'Delete personal tag',
      requiresAuth: true,
    );
  }

  /// Watches all personal tags with real-time updates.
  Stream<List<PersonalTag>> watchTags() {
    return _tagRepository.watchAllSorted();
  }

  /// Checks if a tag name already exists.
  Future<bool> tagNameExists(String name, {String? excludeId}) async {
    return await executeServiceOperation(
          () => _tagRepository.nameExists(name, excludeId: excludeId),
          operationName: 'Check tag name exists',
          requiresAuth: true,
        ) ??
        false;
  }

  /// Gets the next available sort order value for tags.
  Future<int> getNextTagSortOrder() async {
    return await executeServiceOperation(
          () => _tagRepository.getNextSortOrder(),
          operationName: 'Get next tag sort order',
          requiresAuth: true,
        ) ??
        0;
  }

  /// Reorders tags by updating their sortOrder values.
  Future<void> reorderTags(List<String> tagIds) async {
    await executeServiceOperation(
      () async {
        await _tagRepository.reorder(tagIds);
        clearCache(_tagsCacheKey);
        AppLogger.info('Reordered ${tagIds.length} personal tags');
      },
      operationName: 'Reorder personal tags',
      requiresAuth: true,
    );
  }

  /// Moves a tag to a different group.
  Future<void> moveTagToGroup(String tagId, String? groupId) async {
    await executeServiceOperation(
      () async {
        // Validate groupId exists if specified
        if (groupId != null) {
          final group = await _groupRepository.read(groupId);
          if (group == null) {
            throw ArgumentError('Gruppen finns inte');
          }
        }

        await _tagRepository.moveToGroup(tagId, groupId);
        clearCache(_tagsCacheKey);
        AppLogger.info('Moved tag $tagId to group ${groupId ?? "ungrouped"}');
      },
      operationName: 'Move tag to group',
      requiresAuth: true,
    );
  }

  /// Gets tags by group ID (or ungrouped if null).
  Future<List<PersonalTag>> getTagsByGroup(String? groupId) async {
    return await executeServiceOperation(
          () => _tagRepository.getByGroupId(groupId),
          operationName: 'Get tags by group',
          requiresAuth: true,
        ) ??
        [];
  }

  /// Watches tags by group ID (or ungrouped if null).
  Stream<List<PersonalTag>> watchTagsByGroup(String? groupId) {
    return _tagRepository.watchByGroupId(groupId);
  }

  // ============================================================
  // GROUP CRUD OPERATIONS
  // ============================================================

  /// Creates a new personal tag group.
  Future<PersonalTagGroup?> createGroup(PersonalTagGroup group) async {
    return await executeServiceOperation(
      () async {
        final nameValidation = PersonalTagGroup.validateName(group.name);
        if (nameValidation != null) {
          throw ArgumentError(nameValidation);
        }

        if (await _groupRepository.nameExists(group.name)) {
          throw ArgumentError(
            'En grupp med namnet "${group.name}" finns redan',
          );
        }

        await _groupRepository.create(group);
        clearCache(_groupsCacheKey);
        AppLogger.info('Created personal tag group: ${group.name}');
        return group;
      },
      operationName: 'Create personal tag group',
      requiresAuth: true,
    );
  }

  /// Gets a personal tag group by ID.
  Future<PersonalTagGroup?> getGroup(String groupId) async {
    return await executeServiceOperation<PersonalTagGroup?>(
      () async => await _groupRepository.read(groupId),
      operationName: 'Get personal tag group',
      requiresAuth: true,
    );
  }

  /// Gets all personal tag groups sorted by sortOrder.
  Future<List<PersonalTagGroup>> getAllGroups() async {
    return await getCachedOrExecute(
          _groupsCacheKey,
          () => _groupRepository.getAllSorted(),
          cacheDuration: const Duration(minutes: 5),
        ) ??
        [];
  }

  /// Updates a personal tag group.
  Future<void> updateGroup(PersonalTagGroup group) async {
    await executeServiceOperation(
      () async {
        final nameValidation = PersonalTagGroup.validateName(group.name);
        if (nameValidation != null) {
          throw ArgumentError(nameValidation);
        }

        if (await _groupRepository.nameExists(group.name,
            excludeId: group.id)) {
          throw ArgumentError(
            'En grupp med namnet "${group.name}" finns redan',
          );
        }

        final updated = group.copyWith(updatedAt: DateTime.now());
        await _groupRepository.update(updated);
        clearCache(_groupsCacheKey);
        AppLogger.info('Updated personal tag group: ${group.name}');
      },
      operationName: 'Update personal tag group',
      requiresAuth: true,
    );
  }

  /// Deletes a personal tag group.
  /// Tags in this group will have their groupId cleared (become ungrouped).
  ///
  /// #7: Uses atomic batch operation to ensure data consistency.
  /// Both tag updates and group deletion happen in a single transaction.
  Future<void> deleteGroup(String groupId) async {
    await executeServiceOperation(
      () async {
        // #7: Create single batch for atomic operation
        final batch = _tagRepository.newWriteBatch();

        // Add tag updates to batch (clears groupId from all tags in group)
        final clearedCount =
            await _tagRepository.addClearGroupToBatch(batch, groupId);

        // Add group deletion to same batch
        _groupRepository.addDeleteToBatch(batch, groupId);

        // Commit atomically - either all succeed or all fail
        await batch.commit();

        if (clearedCount > 0) {
          AppLogger.info(
              '#7: Atomically cleared group from $clearedCount tags');
        }

        clearCache(_groupsCacheKey);
        clearCache(_tagsCacheKey); // Tags were modified
        AppLogger.info('Deleted personal tag group: $groupId');
      },
      operationName: 'Delete personal tag group',
      requiresAuth: true,
    );
  }

  /// Watches all personal tag groups with real-time updates.
  Stream<List<PersonalTagGroup>> watchGroups() {
    return _groupRepository.watchAllSorted();
  }

  /// Gets the next available sort order value for groups.
  Future<int> getNextGroupSortOrder() async {
    return await executeServiceOperation(
          () => _groupRepository.getNextSortOrder(),
          operationName: 'Get next group sort order',
          requiresAuth: true,
        ) ??
        0;
  }

  /// Reorders groups by updating their sortOrder values.
  Future<void> reorderGroups(List<String> groupIds) async {
    await executeServiceOperation(
      () async {
        await _groupRepository.reorder(groupIds);
        clearCache(_groupsCacheKey);
        AppLogger.info('Reordered ${groupIds.length} personal tag groups');
      },
      operationName: 'Reorder personal tag groups',
      requiresAuth: true,
    );
  }

  // ============================================================
  // EMBEDDED RULE OPERATIONS
  // ============================================================

  /// Adds a rule to a tag.
  Future<void> addRuleToTag(String tagId, PersonalTagRule rule) async {
    await executeServiceOperation(
      () async {
        final validation = PersonalTagRule.validate(rule, requireTagId: false);
        if (validation != null) {
          throw ArgumentError(validation);
        }

        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError('Taggen finns inte');
        }

        final updatedRules = [...tag.rules, rule];
        final updatedTag = tag.copyWith(rules: updatedRules);
        await _tagRepository.update(updatedTag);
        clearCache(_tagsCacheKey);
        AppLogger.info('Added rule "${rule.name}" to tag "${tag.name}"');
      },
      operationName: 'Add rule to tag',
      requiresAuth: true,
    );
  }

  /// Updates a rule within a tag.
  Future<void> updateRuleInTag(String tagId, PersonalTagRule rule) async {
    await executeServiceOperation(
      () async {
        final validation = PersonalTagRule.validate(rule, requireTagId: false);
        if (validation != null) {
          throw ArgumentError(validation);
        }

        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError('Taggen finns inte');
        }

        final ruleIndex = tag.rules.indexWhere((r) => r.id == rule.id);
        if (ruleIndex == -1) {
          throw ArgumentError('Regeln finns inte');
        }

        final updatedRules = [...tag.rules];
        updatedRules[ruleIndex] = rule.copyWith(updatedAt: DateTime.now());
        final updatedTag = tag.copyWith(rules: updatedRules);
        await _tagRepository.update(updatedTag);
        clearCache(_tagsCacheKey);
        AppLogger.info('Updated rule "${rule.name}" in tag "${tag.name}"');
      },
      operationName: 'Update rule in tag',
      requiresAuth: true,
    );
  }

  /// Removes a rule from a tag.
  Future<void> removeRuleFromTag(String tagId, String ruleId) async {
    await executeServiceOperation(
      () async {
        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError('Taggen finns inte');
        }

        final updatedRules = tag.rules.where((r) => r.id != ruleId).toList();
        final updatedTag = tag.copyWith(rules: updatedRules);
        await _tagRepository.update(updatedTag);
        clearCache(_tagsCacheKey);
        AppLogger.info('Removed rule $ruleId from tag "${tag.name}"');
      },
      operationName: 'Remove rule from tag',
      requiresAuth: true,
    );
  }

  /// Enables or disables a rule within a tag.
  Future<void> setRuleEnabled(
    String tagId,
    String ruleId, {
    required bool enabled,
  }) async {
    await executeServiceOperation(
      () async {
        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError('Taggen finns inte');
        }

        final ruleIndex = tag.rules.indexWhere((r) => r.id == ruleId);
        if (ruleIndex == -1) {
          throw ArgumentError('Regeln finns inte');
        }

        final updatedRules = [...tag.rules];
        updatedRules[ruleIndex] = updatedRules[ruleIndex].copyWith(
          isEnabled: enabled,
          updatedAt: DateTime.now(),
        );
        final updatedTag = tag.copyWith(rules: updatedRules);
        await _tagRepository.update(updatedTag);
        clearCache(_tagsCacheKey);
        AppLogger.info('Set rule $ruleId enabled: $enabled');
      },
      operationName: 'Set rule enabled',
      requiresAuth: true,
    );
  }

  /// Gets all enabled rules from all tags.
  Future<List<TagRulePair>> getEnabledRules() async {
    final tags = await getAllTags();
    final rules = <TagRulePair>[];

    for (final tag in tags) {
      for (final rule in tag.rules) {
        if (rule.isEnabled) {
          rules.add(TagRulePair(tag, rule));
        }
      }
    }

    return rules;
  }

  /// Watches all enabled rules with real-time updates.
  /// Returns pairs of (tag, rule) for context.
  Stream<List<TagRulePair>> watchEnabledRules() {
    return watchTags().map((tags) {
      final rules = <TagRulePair>[];
      for (final tag in tags) {
        for (final rule in tag.rules) {
          if (rule.isEnabled) {
            rules.add(TagRulePair(tag, rule));
          }
        }
      }
      return rules;
    });
  }

  // ============================================================
  // RULE EVALUATION ENGINE
  // ============================================================

  /// Evaluates all enabled rules against a recipe.
  ///
  /// Returns the set of tag IDs that should be applied to the recipe
  /// based on matching rules. Respects exclusive group constraints -
  /// only one tag from each exclusive group will be included.
  Future<Set<String>> evaluateRulesForRecipe(Recipe recipe) async {
    final result = await executeServiceOperation(
      () async {
        final tagRulePairs = await getEnabledRules();
        if (tagRulePairs.isEmpty) return <String>{};

        // CRIT-5: Pass userId to enable user-defined ingredient matching
        final userId = _getCurrentUserId();
        final matchingTags =
            await _evaluateRules(recipe, tagRulePairs, userId: userId);

        // #6: Enforce exclusive group constraints
        return _enforceExclusiveGroups(matchingTags);
      },
      operationName: 'Evaluate rules for recipe',
      requiresAuth: true,
    );
    return result ?? {};
  }

  /// Evaluates rules against multiple recipes.
  ///
  /// Returns a map of recipe ID to matching tag IDs.
  /// Respects exclusive group constraints for each recipe.
  Future<Map<String, Set<String>>> evaluateRulesForRecipes(
    List<Recipe> recipes,
  ) async {
    final result = await executeServiceOperation(
      () async {
        final tagRulePairs = await getEnabledRules();
        if (tagRulePairs.isEmpty || recipes.isEmpty) {
          return <String, Set<String>>{};
        }

        // CRIT-5: Pass userId to enable user-defined ingredient matching
        final userId = _getCurrentUserId();
        final results = <String, Set<String>>{};

        for (final recipe in recipes) {
          final matchingTags = await _evaluateRules(
            recipe,
            tagRulePairs,
            userId: userId,
          );
          if (matchingTags.isNotEmpty) {
            // #6: Enforce exclusive group constraints per recipe
            final filtered = await _enforceExclusiveGroups(matchingTags);
            if (filtered.isNotEmpty) {
              results[recipe.id] = filtered;
            }
          }
        }

        return results;
      },
      operationName: 'Evaluate rules for recipes',
      requiresAuth: true,
    );
    return result ?? {};
  }

  /// Internal method to evaluate rules against a recipe.
  ///
  /// CRIT-5: Accepts userId to enable user-defined ingredient matching.
  /// Without userId, rules with property conditions won't match user-created
  /// ingredients that have custom properties.
  Future<Set<String>> _evaluateRules(
    Recipe recipe,
    List<TagRulePair> tagRulePairs, {
    String? userId,
  }) async {
    final matchingTagIds = <String>{};

    // Check if any rule requires ingredient lookup
    final requiresLookup = tagRulePairs.any((p) => p.rule.requiresLookup);

    IngredientLookupResult? lookup;
    if (requiresLookup) {
      // CRIT-5: Pass userId to find user-defined ingredients with custom properties
      lookup = await _lookupService.lookupFromRaw(
        recipe.ingredients,
        userId: userId,
      );
    }

    for (final pair in tagRulePairs) {
      if (pair.rule.evaluate(recipe, lookup)) {
        matchingTagIds.add(pair.tag.id);
      }
    }

    return matchingTagIds;
  }

  /// Suggests tags for a recipe based on rule evaluation.
  ///
  /// Returns a list of PersonalTag objects that would be applied.
  Future<List<PersonalTag>> suggestTagsForRecipe(Recipe recipe) async {
    final matchingTagIds = await evaluateRulesForRecipe(recipe);
    if (matchingTagIds.isEmpty) return [];

    final tags = await getAllTags();
    return tags.where((tag) => matchingTagIds.contains(tag.id)).toList();
  }

  // ============================================================
  // COMBINED STREAMS FOR UI
  // ============================================================

  /// Watches tags and groups together for hierarchical UI display.
  /// Returns groups with their tags, plus ungrouped tags.
  Stream<PersonalTagsWithGroups> watchTagsWithGroups() {
    return Rx.combineLatest2(
      watchTags(),
      watchGroups(),
      (List<PersonalTag> tags, List<PersonalTagGroup> groups) {
        final tagsByGroup = <String?, List<PersonalTag>>{};

        // Initialize with null key for ungrouped
        tagsByGroup[null] = [];

        // Initialize groups
        for (final group in groups) {
          tagsByGroup[group.id] = [];
        }

        // Assign tags to groups
        for (final tag in tags) {
          final key = tag.groupId;
          if (tagsByGroup.containsKey(key)) {
            tagsByGroup[key]!.add(tag);
          } else {
            // Group was deleted but tag still references it
            tagsByGroup[null]!.add(tag);
          }
        }

        return PersonalTagsWithGroups(
          groups: groups,
          tagsByGroup: tagsByGroup,
          ungroupedTags: tagsByGroup[null] ?? [],
        );
      },
    );
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  /// Gets usage count for each tag based on the provided recipes.
  ///
  /// Returns a map of tag ID to the number of recipes that have that tag.
  /// Tags with zero usage are not included in the result.
  Map<String, int> getTagUsageCounts(List<Recipe> recipes) {
    final counts = <String, int>{};

    for (final recipe in recipes) {
      final tagIds = recipe.personalTagIds ?? [];
      for (final tagId in tagIds) {
        counts[tagId] = (counts[tagId] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Gets tags sorted by usage count (most used first).
  ///
  /// If [limit] is provided, returns only the top N tags.
  Future<List<PersonalTag>> getTagsByUsage(
    List<Recipe> recipes, {
    int? limit,
  }) async {
    final counts = getTagUsageCounts(recipes);
    if (counts.isEmpty) return [];

    final tags = await getAllTags();

    // Sort tags by usage count (descending)
    final sortedTags = tags.toList()
      ..sort((a, b) {
        final countA = counts[a.id] ?? 0;
        final countB = counts[b.id] ?? 0;
        return countB.compareTo(countA);
      });

    if (limit != null && limit < sortedTags.length) {
      return sortedTags.take(limit).toList();
    }

    return sortedTags;
  }

  /// Gets multiple tags by their IDs.
  ///
  /// Useful for resolving recipe.personalTagIds to full PersonalTag objects.
  Future<List<PersonalTag>> getTagsByIds(List<String> tagIds) async {
    if (tagIds.isEmpty) return [];

    return await executeServiceOperation(
          () => _tagRepository.getByIds(tagIds),
          operationName: 'Get tags by IDs',
          requiresAuth: true,
        ) ??
        [];
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  Future<void> onInitialize() async {
    AppLogger.info('PersonalTagService ready');
  }

  @override
  Future<void> onDispose() async {
    clearAllCache();
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  /// CRIT-5: Gets current user ID for ingredient lookup context.
  /// Used to find user-defined ingredients with custom properties during rule evaluation.
  String? _getCurrentUserId() {
    try {
      final authRepository = ServiceLocator.get<auth.AuthRepository>();
      return authRepository.currentUserId;
    } catch (e) {
      AppLogger.error('Failed to get current user ID: $e');
      return null;
    }
  }

  /// #6: Filters matching tags to respect exclusive group constraints.
  ///
  /// When multiple tags from an exclusive group would be applied, only the
  /// first one (by sort order) is kept. Uses cached data from getAllTags()
  /// and getAllGroups() to avoid redundant Firestore queries.
  ///
  /// Non-exclusive groups and ungrouped tags are always included.
  Future<Set<String>> _enforceExclusiveGroups(
      Set<String> matchingTagIds) async {
    if (matchingTagIds.isEmpty) return matchingTagIds;

    // Get cached data (these use getCachedOrExecute with 5 min cache)
    final tags = await getAllTags();
    final groups = await getAllGroups();

    if (tags.isEmpty) return matchingTagIds;

    // Find exclusive group IDs
    final exclusiveGroupIds =
        groups.where((g) => g.isExclusive).map((g) => g.id).toSet();

    if (exclusiveGroupIds.isEmpty) return matchingTagIds;

    // Build tag lookup map
    final tagById = {for (final tag in tags) tag.id: tag};

    final result = <String>{};
    final seenExclusiveGroups = <String>{};
    int skippedCount = 0;

    for (final tagId in matchingTagIds) {
      final tag = tagById[tagId];
      if (tag == null) {
        // Tag not found in cache - include it to be safe
        result.add(tagId);
        continue;
      }

      if (tag.groupId != null && exclusiveGroupIds.contains(tag.groupId)) {
        // Tag is in an exclusive group
        if (!seenExclusiveGroups.contains(tag.groupId)) {
          result.add(tagId);
          seenExclusiveGroups.add(tag.groupId!);
        } else {
          // Skip - already have a tag from this exclusive group
          skippedCount++;
        }
      } else {
        // Non-exclusive or ungrouped - always include
        result.add(tagId);
      }
    }

    if (skippedCount > 0) {
      AppLogger.debug(
        '#6: Exclusive group enforcement skipped $skippedCount tag(s)',
      );
    }

    return result;
  }
}

/// Helper for pairing a tag with one of its rules.
/// Used when evaluating rules across all tags.
class TagRulePair {
  final PersonalTag tag;
  final PersonalTagRule rule;

  TagRulePair(this.tag, this.rule);
}

/// Result of watching tags with groups for hierarchical display.
class PersonalTagsWithGroups {
  final List<PersonalTagGroup> groups;
  final Map<String?, List<PersonalTag>> tagsByGroup;
  final List<PersonalTag> ungroupedTags;

  PersonalTagsWithGroups({
    required this.groups,
    required this.tagsByGroup,
    required this.ungroupedTags,
  });

  /// Gets tags for a specific group (or ungrouped if null).
  List<PersonalTag> getTagsForGroup(String? groupId) {
    return tagsByGroup[groupId] ?? [];
  }

  /// Gets total tag count.
  int get totalTagCount =>
      tagsByGroup.values.fold(0, (sum, tags) => sum + tags.length);
}
