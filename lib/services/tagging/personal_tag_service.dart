import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/services/tagging/personal_tag_crud_service.dart';
import 'package:butlery/services/tagging/personal_tag_rule_evaluator.dart';
import 'package:butlery/services/tagging/personal_tag_types.dart';
import 'package:rxdart/rxdart.dart';

// Re-export types so callers importing PersonalTagService get TagRulePair etc.
export 'package:butlery/services/tagging/personal_tag_types.dart';

/// Facade for managing user-defined personal tags, groups, and automation rules.
///
/// Delegates to two focused sub-services:
/// - [PersonalTagCrudService] -- tag/group/rule CRUD and cascade operations
/// - [PersonalTagRuleEvaluator] -- rule evaluation engine
///
/// The public API is unchanged from the pre-refactor monolithic service.
/// Callers interact only with PersonalTagService.
class PersonalTagService extends BaseService {
  final PersonalTagCrudService _crud;
  final PersonalTagRuleEvaluator _evaluator;

  PersonalTagService({
    required PersonalTagCrudService crudService,
    required PersonalTagRuleEvaluator ruleEvaluator,
    required FirebasePersonalTagRepository tagRepository,
    required FirebasePersonalTagGroupRepository groupRepository,
  })  : _crud = crudService,
        _evaluator = ruleEvaluator;

  @override
  String get serviceName => 'PersonalTagService';

  // -- Tag CRUD (delegated) --

  Future<PersonalTag?> createTag(PersonalTag tag) => _crud.createTag(tag);

  Future<PersonalTag?> getTag(String tagId) => _crud.getTag(tagId);

  Future<List<PersonalTag>> getAllTags() => _crud.getAllTags();

  Future<void> updateTag(PersonalTag tag) => _crud.updateTag(tag);

  Future<void> deleteTag(String tagId) => _crud.deleteTag(tagId);

  /// BUT-994: bulk-delete N tags. Chunks at 100 per batch (Firestore 500-op
  /// safety margin). Returns total tags deleted. Per-recipe cascade is
  /// atomic per chunk — either every removal in a chunk lands or none.
  Future<int> bulkDeleteTags(List<String> tagIds) =>
      _crud.bulkDeleteTags(tagIds);

  Stream<List<PersonalTag>> watchTags() => _crud.watchTags();

  /// BUT-1055: fires once per tag-set mutation. Consumers use this + an
  /// on-demand [getAllTags] instead of an always-on Firestore snapshot
  /// listener (see [AutoPersonalTagDisplay]).
  Stream<void> get tagsMutated => _crud.tagsMutated;

  Future<bool> tagNameExists(String name, {String? excludeId}) =>
      _crud.tagNameExists(name, excludeId: excludeId);

  Future<int> getNextTagSortOrder() => _crud.getNextTagSortOrder();

  Future<void> reorderTags(List<String> tagIds) => _crud.reorderTags(tagIds);

  Future<void> moveTagToGroup(String tagId, String? groupId) =>
      _crud.moveTagToGroup(tagId, groupId);

  Future<List<PersonalTag>> getTagsByGroup(String? groupId) =>
      _crud.getTagsByGroup(groupId);

  Stream<List<PersonalTag>> watchTagsByGroup(String? groupId) =>
      _crud.watchTagsByGroup(groupId);

  Future<List<PersonalTag>> getTagsByIds(List<String> tagIds) =>
      _crud.getTagsByIds(tagIds);

  // -- Group CRUD (delegated) --

  Future<PersonalTagGroup?> createGroup(PersonalTagGroup group) =>
      _crud.createGroup(group);

  Future<PersonalTagGroup?> getGroup(String groupId) => _crud.getGroup(groupId);

  Future<List<PersonalTagGroup>> getAllGroups() => _crud.getAllGroups();

  Future<void> updateGroup(PersonalTagGroup group) => _crud.updateGroup(group);

  Future<void> deleteGroup(String groupId) => _crud.deleteGroup(groupId);

  Stream<List<PersonalTagGroup>> watchGroups() => _crud.watchGroups();

  Future<int> getNextGroupSortOrder() => _crud.getNextGroupSortOrder();

  Future<void> reorderGroups(List<String> groupIds) =>
      _crud.reorderGroups(groupIds);

  // -- Rule CRUD (delegated) --

  Future<void> addRuleToTag(String tagId, PersonalTagRule rule) =>
      _crud.addRuleToTag(tagId, rule);

  Future<void> updateRuleInTag(String tagId, PersonalTagRule rule) =>
      _crud.updateRuleInTag(tagId, rule);

  Future<void> removeRuleFromTag(String tagId, String ruleId) =>
      _crud.removeRuleFromTag(tagId, ruleId);

  Future<void> setRuleEnabled(
    String tagId,
    String ruleId, {
    required bool enabled,
  }) =>
      _crud.setRuleEnabled(tagId, ruleId, enabled: enabled);

  // -- Rule queries --

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

  // -- Rule evaluation (delegated to evaluator) --

  Future<Set<String>> evaluateRulesForRecipe(Recipe recipe) async {
    final tagRulePairs = await getEnabledRules();
    if (tagRulePairs.isEmpty) return {};

    final allTags = await getAllTags();
    final allGroups = await getAllGroups();
    return _evaluator.evaluateRulesForRecipe(
        recipe, tagRulePairs, allTags, allGroups);
  }

  Future<Map<String, Set<String>>> evaluateRulesForRecipes(
    List<Recipe> recipes,
  ) async {
    final tagRulePairs = await getEnabledRules();
    if (tagRulePairs.isEmpty || recipes.isEmpty) return {};

    final allTags = await getAllTags();
    final allGroups = await getAllGroups();
    return _evaluator.evaluateRulesForRecipes(
        recipes, tagRulePairs, allTags, allGroups);
  }

  Future<Map<String, List<String>>> evaluateRulesWithSources(
    Recipe recipe,
  ) async {
    final tagRulePairs = await getEnabledRules();
    if (tagRulePairs.isEmpty) return {};

    final allTags = await getAllTags();
    final allGroups = await getAllGroups();
    return _evaluator.evaluateRulesWithSources(
        recipe, tagRulePairs, allTags, allGroups);
  }

  Future<Map<String, Map<String, List<String>>>>
      evaluateRulesWithSourcesForRecipes(List<Recipe> recipes) async {
    final tagRulePairs = await getEnabledRules();
    if (tagRulePairs.isEmpty || recipes.isEmpty) return {};

    final allTags = await getAllTags();
    final allGroups = await getAllGroups();
    return _evaluator.evaluateRulesWithSourcesForRecipes(
        recipes, tagRulePairs, allTags, allGroups);
  }

  Future<List<PersonalTag>> suggestTagsForRecipe(Recipe recipe) async {
    final tagRulePairs = await getEnabledRules();
    if (tagRulePairs.isEmpty) return [];

    final allTags = await getAllTags();
    final allGroups = await getAllGroups();
    return _evaluator.suggestTagsForRecipe(
        recipe, tagRulePairs, allTags, allGroups);
  }

  // -- Orchestration methods (remain in facade) --

  /// Watches tags and groups together for hierarchical UI display.
  Stream<PersonalTagsWithGroups> watchTagsWithGroups() {
    return Rx.combineLatest2(
      watchTags(),
      watchGroups(),
      (List<PersonalTag> tags, List<PersonalTagGroup> groups) {
        final tagsByGroup = <String?, List<PersonalTag>>{};

        tagsByGroup[null] = [];

        for (final group in groups) {
          tagsByGroup[group.id] = [];
        }

        for (final tag in tags) {
          final key = tag.groupId;
          if (tagsByGroup.containsKey(key)) {
            tagsByGroup[key]!.add(tag);
          } else {
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

  /// Gets the current tag version as epoch milliseconds (max updatedAt
  /// across all tags). BUT-998: no per-call memoization needed — the
  /// underlying `getAllTags()` is itself cached via `getCachedOrExecute`
  /// (5-min TTL, invalidated on every CRUD mutation), so this reduces to
  /// a small in-memory reduce on the cached list.
  Future<int> getCurrentTagVersion() async {
    final tags = await getAllTags();
    if (tags.isEmpty) return 0;
    return tags
        .map((t) => t.updatedAt.millisecondsSinceEpoch)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Checks if a recipe has stale personal tags.
  Future<bool> isRecipeStale(Recipe recipe) async {
    final recipeVersion = recipe.core.personalTagVersion;
    if (recipeVersion == null) return true;

    final currentVersion = await getCurrentTagVersion();
    return currentVersion > recipeVersion;
  }

  /// Gets usage count for each tag based on the provided recipes.
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
  Future<List<PersonalTag>> getTagsByUsage(
    List<Recipe> recipes, {
    int? limit,
  }) async {
    final counts = getTagUsageCounts(recipes);
    if (counts.isEmpty) return [];

    final tags = await getAllTags();

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

  // -- Lifecycle --

  @override
  Future<void> onInitialize() async {
    AppLogger.info('PersonalTagService ready');
  }

  /// BUT-998: clears the in-memory tag/group cache (e.g. on logout). The
  /// snapshot-based cache-invalidation listener that lived here pre-BUT-998
  /// was redundant — every CRUD path already calls `_crud.clearCache(...)`
  /// at the write site, so the live listener was double work.
  void resetForLogout() {
    _crud.clearAllCache();
  }

  @override
  Future<void> onDispose() async {
    resetForLogout();
  }
}
