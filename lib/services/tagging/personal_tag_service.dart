import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_rule_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

/// Service for managing user-defined personal tags and automation rules.
///
/// Provides:
/// - CRUD operations for PersonalTag and PersonalTagRule
/// - Rule evaluation engine for automatic tag application
/// - Real-time streams for UI updates
class PersonalTagService extends BaseService {
  final FirebasePersonalTagRepository _tagRepository;
  final FirebasePersonalTagRuleRepository _ruleRepository;
  final IngredientLookupService _lookupService;

  static const String _tagsCacheKey = 'personal_tags';
  static const String _rulesCacheKey = 'personal_rules';

  PersonalTagService({
    required FirebasePersonalTagRepository tagRepository,
    required FirebasePersonalTagRuleRepository ruleRepository,
    required IngredientLookupService lookupService,
  })  : _tagRepository = tagRepository,
        _ruleRepository = ruleRepository,
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

        final updated = tag.copyWith(updatedAt: DateTime.now());
        await _tagRepository.update(updated);
        clearCache(_tagsCacheKey);
        AppLogger.info('Updated personal tag: ${tag.name}');
      },
      operationName: 'Update personal tag',
      requiresAuth: true,
    );
  }

  /// Deletes a personal tag and all associated rules.
  Future<void> deleteTag(String tagId) async {
    await executeServiceOperation(
      () async {
        // Cascade delete: remove all rules for this tag first
        await _ruleRepository.deleteRulesForTag(tagId);
        await _tagRepository.delete(tagId);
        clearCache(_tagsCacheKey);
        clearCache(_rulesCacheKey);
        AppLogger.info('Deleted personal tag and associated rules: $tagId');
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

  /// Gets the next available sort order value.
  Future<int> getNextSortOrder() async {
    return await executeServiceOperation(
          () => _tagRepository.getNextSortOrder(),
          operationName: 'Get next sort order',
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

  // ============================================================
  // RULE CRUD OPERATIONS
  // ============================================================

  /// Creates a new personal tag rule.
  Future<PersonalTagRule?> createRule(PersonalTagRule rule) async {
    return await executeServiceOperation(
      () async {
        final validation = PersonalTagRule.validate(rule);
        if (validation != null) {
          throw ArgumentError(validation);
        }

        // Verify tag exists
        final tag = await _tagRepository.read(rule.tagId);
        if (tag == null) {
          throw ArgumentError('Taggen för regeln finns inte');
        }

        await _ruleRepository.create(rule);
        clearCache(_rulesCacheKey);
        AppLogger.info('Created personal tag rule: ${rule.name}');
        return rule;
      },
      operationName: 'Create personal tag rule',
      requiresAuth: true,
    );
  }

  /// Gets a personal tag rule by ID.
  Future<PersonalTagRule?> getRule(String ruleId) async {
    return await executeServiceOperation<PersonalTagRule?>(
      () async => await _ruleRepository.read(ruleId),
      operationName: 'Get personal tag rule',
      requiresAuth: true,
    );
  }

  /// Gets all rules for a specific tag.
  Future<List<PersonalTagRule>> getRulesForTag(String tagId) async {
    return await executeServiceOperation(
          () => _ruleRepository.getRulesForTag(tagId),
          operationName: 'Get rules for tag',
          requiresAuth: true,
        ) ??
        [];
  }

  /// Gets all enabled rules.
  Future<List<PersonalTagRule>> getEnabledRules() async {
    return await getCachedOrExecute(
          _rulesCacheKey,
          () => _ruleRepository.getEnabledRules(),
          cacheDuration: const Duration(minutes: 5),
        ) ??
        [];
  }

  /// Updates a personal tag rule.
  Future<void> updateRule(PersonalTagRule rule) async {
    await executeServiceOperation(
      () async {
        final validation = PersonalTagRule.validate(rule);
        if (validation != null) {
          throw ArgumentError(validation);
        }

        final updated = rule.copyWith(updatedAt: DateTime.now());
        await _ruleRepository.update(updated);
        clearCache(_rulesCacheKey);
        AppLogger.info('Updated personal tag rule: ${rule.name}');
      },
      operationName: 'Update personal tag rule',
      requiresAuth: true,
    );
  }

  /// Deletes a personal tag rule.
  Future<void> deleteRule(String ruleId) async {
    await executeServiceOperation(
      () async {
        await _ruleRepository.delete(ruleId);
        clearCache(_rulesCacheKey);
        AppLogger.info('Deleted personal tag rule: $ruleId');
      },
      operationName: 'Delete personal tag rule',
      requiresAuth: true,
    );
  }

  /// Enables or disables a rule.
  Future<void> setRuleEnabled(String ruleId, {required bool enabled}) async {
    await executeServiceOperation(
      () async {
        await _ruleRepository.setEnabled(ruleId, enabled: enabled);
        clearCache(_rulesCacheKey);
        AppLogger.info('Set rule $ruleId enabled: $enabled');
      },
      operationName: 'Set rule enabled',
      requiresAuth: true,
    );
  }

  /// Watches all enabled rules with real-time updates.
  Stream<List<PersonalTagRule>> watchEnabledRules() {
    return _ruleRepository.watchEnabledRules();
  }

  /// Watches all rules (enabled and disabled) for management UI.
  Stream<List<PersonalTagRule>> watchAllRules() {
    return _ruleRepository.watchAllRules();
  }

  /// Watches rules for a specific tag.
  Stream<List<PersonalTagRule>> watchRulesForTag(String tagId) {
    return _ruleRepository.watchRulesForTag(tagId);
  }

  // ============================================================
  // RULE EVALUATION ENGINE
  // ============================================================

  /// Evaluates all enabled rules against a recipe.
  ///
  /// Returns the set of tag IDs that should be applied to the recipe
  /// based on matching rules.
  Future<Set<String>> evaluateRulesForRecipe(Recipe recipe) async {
    final result = await executeServiceOperation(
      () async {
        final rules = await getEnabledRules();
        if (rules.isEmpty) return <String>{};

        return _evaluateRules(recipe, rules);
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
  ) async {
    final result = await executeServiceOperation(
      () async {
        final rules = await getEnabledRules();
        if (rules.isEmpty || recipes.isEmpty) return <String, Set<String>>{};

        final results = <String, Set<String>>{};

        for (final recipe in recipes) {
          final matchingTags = await _evaluateRules(recipe, rules);
          if (matchingTags.isNotEmpty) {
            results[recipe.id] = matchingTags;
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
  Future<Set<String>> _evaluateRules(
    Recipe recipe,
    List<PersonalTagRule> rules,
  ) async {
    final matchingTagIds = <String>{};

    // Check if any rule requires ingredient lookup
    final requiresLookup = rules.any((r) => r.requiresLookup);

    IngredientLookupResult? lookup;
    if (requiresLookup) {
      lookup = await _lookupService.lookupFromRaw(recipe.ingredients);
    }

    for (final rule in rules) {
      if (rule.evaluate(recipe, lookup)) {
        matchingTagIds.add(rule.tagId);
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
}
