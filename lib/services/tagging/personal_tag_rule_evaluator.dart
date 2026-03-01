import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/personal_tag_types.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Evaluates personal tag rules against recipes and enforces group constraints.
///
/// Extracted from PersonalTagService. Handles all rule evaluation logic:
/// - Single and batch recipe evaluation
/// - Source tracking (which rules matched each tag)
/// - Exclusive group enforcement
/// - Ingredient lookup delegation for property-based conditions
class PersonalTagRuleEvaluator extends BaseService {
  final IngredientLookupService _lookupService;

  PersonalTagRuleEvaluator({
    required IngredientLookupService lookupService,
  }) : _lookupService = lookupService;

  @override
  String get serviceName => 'PersonalTagRuleEvaluator';

  /// Evaluates all enabled rules against a single recipe.
  ///
  /// Returns the set of tag IDs that should be applied.
  /// Respects exclusive group constraints.
  Future<Set<String>> evaluateRulesForRecipe(
    Recipe recipe,
    List<TagRulePair> tagRulePairs,
    List<PersonalTag> allTags,
    List<PersonalTagGroup> allGroups,
  ) async {
    final result = await executeServiceOperation(
      () async {
        if (tagRulePairs.isEmpty) return <String>{};

        final userId = _getCurrentUserId();
        final matchingTags =
            await _evaluateRules(recipe, tagRulePairs, userId: userId);

        return await _enforceExclusiveGroups(matchingTags, allTags, allGroups);
      },
      operationName: 'Evaluate rules for recipe',
      requiresAuth: true,
    );
    return result ?? {};
  }

  /// Evaluates rules against multiple recipes.
  ///
  /// Returns a map of recipe ID to matching tag IDs.
  Future<Map<String, Set<String>>> evaluateRulesForRecipes(
    List<Recipe> recipes,
    List<TagRulePair> tagRulePairs,
    List<PersonalTag> allTags,
    List<PersonalTagGroup> allGroups,
  ) async {
    final result = await executeServiceOperation(
      () async {
        if (tagRulePairs.isEmpty || recipes.isEmpty) {
          return <String, Set<String>>{};
        }

        final userId = _getCurrentUserId();
        final results = <String, Set<String>>{};

        for (final recipe in recipes) {
          final matchingTags = await _evaluateRules(
            recipe,
            tagRulePairs,
            userId: userId,
          );
          if (matchingTags.isNotEmpty) {
            final filtered =
                await _enforceExclusiveGroups(matchingTags, allTags, allGroups);
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

  /// Evaluates rules and returns a map of tag ID to matching rule IDs.
  ///
  /// Unlike [evaluateRulesForRecipe], this tracks which specific rules
  /// caused each tag to match -- used for source tracking in RecipePersonalTag.
  Future<Map<String, List<String>>> evaluateRulesWithSources(
    Recipe recipe,
    List<TagRulePair> tagRulePairs,
    List<PersonalTag> allTags,
    List<PersonalTagGroup> allGroups,
  ) async {
    final result = await executeServiceOperation(
      () async {
        if (tagRulePairs.isEmpty) return <String, List<String>>{};

        final userId = _getCurrentUserId();
        final sourcesMap = await _evaluateRulesWithSources(
          recipe,
          tagRulePairs,
          userId: userId,
        );

        final filteredIds = await _enforceExclusiveGroups(
            sourcesMap.keys.toSet(), allTags, allGroups);

        sourcesMap.removeWhere((tagId, _) => !filteredIds.contains(tagId));

        return sourcesMap;
      },
      operationName: 'Evaluate rules with sources',
      requiresAuth: true,
    );
    return result ?? {};
  }

  /// Evaluates rules with source tracking for multiple recipes.
  ///
  /// Returns a map of recipeId -> (tagId -> list of ruleIds).
  Future<Map<String, Map<String, List<String>>>>
      evaluateRulesWithSourcesForRecipes(
    List<Recipe> recipes,
    List<TagRulePair> tagRulePairs,
    List<PersonalTag> allTags,
    List<PersonalTagGroup> allGroups,
  ) async {
    final result = await executeServiceOperation(
      () async {
        if (tagRulePairs.isEmpty || recipes.isEmpty) {
          return <String, Map<String, List<String>>>{};
        }

        final userId = _getCurrentUserId();
        final results = <String, Map<String, List<String>>>{};

        for (final recipe in recipes) {
          final sourcesMap = await _evaluateRulesWithSources(
            recipe,
            tagRulePairs,
            userId: userId,
          );
          if (sourcesMap.isNotEmpty) {
            final filteredIds = await _enforceExclusiveGroups(
                sourcesMap.keys.toSet(), allTags, allGroups);
            sourcesMap.removeWhere((tagId, _) => !filteredIds.contains(tagId));
            if (sourcesMap.isNotEmpty) {
              results[recipe.id] = sourcesMap;
            }
          }
        }

        return results;
      },
      operationName: 'Evaluate rules with sources for recipes',
      requiresAuth: true,
    );
    return result ?? {};
  }

  /// Suggests tags for a recipe based on rule evaluation.
  Future<List<PersonalTag>> suggestTagsForRecipe(
    Recipe recipe,
    List<TagRulePair> tagRulePairs,
    List<PersonalTag> allTags,
    List<PersonalTagGroup> allGroups,
  ) async {
    final matchingTagIds = await evaluateRulesForRecipe(
      recipe,
      tagRulePairs,
      allTags,
      allGroups,
    );
    if (matchingTagIds.isEmpty) return [];

    return allTags.where((tag) => matchingTagIds.contains(tag.id)).toList();
  }

  // -- Private evaluation methods --

  Future<Set<String>> _evaluateRules(
    Recipe recipe,
    List<TagRulePair> tagRulePairs, {
    String? userId,
  }) async {
    final sourcesMap = await _evaluateRulesWithSources(
      recipe,
      tagRulePairs,
      userId: userId,
    );
    return sourcesMap.keys.toSet();
  }

  Future<Map<String, List<String>>> _evaluateRulesWithSources(
    Recipe recipe,
    List<TagRulePair> tagRulePairs, {
    String? userId,
  }) async {
    final result = <String, List<String>>{};

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
      if (pair.rule.evaluate(recipe, lookup, currentUserId: userId)) {
        result.putIfAbsent(pair.tag.id, () => []).add(pair.rule.id);
      }
    }

    return result;
  }

  /// Filters matching tags to respect exclusive group constraints.
  ///
  /// When multiple tags from an exclusive group would be applied, only the
  /// first one (by sort order) is kept.
  Future<Set<String>> _enforceExclusiveGroups(
    Set<String> matchingTagIds,
    List<PersonalTag> allTags,
    List<PersonalTagGroup> allGroups,
  ) async {
    if (matchingTagIds.isEmpty) return matchingTagIds;

    if (allTags.isEmpty) return matchingTagIds;

    final exclusiveGroupIds =
        allGroups.where((g) => g.isExclusive).map((g) => g.id).toSet();

    if (exclusiveGroupIds.isEmpty) return matchingTagIds;

    final tagById = {for (final tag in allTags) tag.id: tag};

    final result = <String>{};
    final seenExclusiveGroups = <String>{};
    int skippedCount = 0;

    for (final tagId in matchingTagIds) {
      final tag = tagById[tagId];
      if (tag == null) {
        result.add(tagId);
        continue;
      }

      if (tag.groupId != null && exclusiveGroupIds.contains(tag.groupId)) {
        if (!seenExclusiveGroups.contains(tag.groupId)) {
          result.add(tagId);
          seenExclusiveGroups.add(tag.groupId!);
        } else {
          skippedCount++;
        }
      } else {
        result.add(tagId);
      }
    }

    if (skippedCount > 0) {
      AppLogger.debug(
        'Exclusive group enforcement skipped $skippedCount tag(s)',
      );
    }

    return result;
  }

  String? _getCurrentUserId() {
    try {
      final authRepository = ServiceLocator.get<auth.AuthRepository>();
      return authRepository.currentUserId;
    } catch (e) {
      AppLogger.error('Failed to get current user ID: $e');
      return null;
    }
  }
}
