/// Unit tests for PersonalTagRuleEvaluator.
///
/// Tests the evaluator in isolation (not through PersonalTagService) to pin
/// the domain contracts that the service tests don't isolate:
///
///  - ENG-06 target 1: rule matches → tag included in result set
///  - ENG-06 target 2: rule does not match → tag excluded
///  - ENG-06 target 3: empty rules list → returns empty set without calling
///      the lookup service
///  - ENG-06 target 4: exclusive-group enforcement keeps only the first
///      matching tag and discards the rest from that group
///  - ENG-06 target 5: evaluateRulesWithSources returns the rule ID that
///      caused each tag to match (source tracking invariant)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/personal_tag_rule_evaluator.dart';
import 'package:butlery/services/tagging/personal_tag_types.dart';

import '../../../infrastructure/builders/personal_tag_builder.dart';
import '../../../infrastructure/builders/recipe_builder.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockIngredientLookupService extends Mock
    implements IngredientLookupService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Returns an IngredientLookupResult where [matchedProperties] are all
/// attached to a single synthetic ingredient and all names pass through as
/// unmatched when [matchedProperties] is empty.
IngredientLookupResult _lookupWith(Set<String> matchedProperties) {
  if (matchedProperties.isEmpty) {
    return IngredientLookupResult.fromLists(matched: [], unmatched: ['item']);
  }
  return IngredientLookupResult.fromLists(
    matched: [
      IngredientData(
        id: 'test-ing',
        swedish: 'Testingrediens',
        english: 'test ingredient',
        group: 'test/group',
        properties: matchedProperties,
      ),
    ],
    unmatched: [],
  );
}

PersonalTagGroup _exclusiveGroup(String id) => PersonalTagGroup(
  id: id,
  name: 'Exklusiv grupp',
  isExclusive: true,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

void main() {
  late PersonalTagRuleEvaluator evaluator;
  late _MockIngredientLookupService mockLookup;
  late _MockAuthRepository mockAuth;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() async {
    mockLookup = _MockIngredientLookupService();
    mockAuth = _MockAuthRepository();

    // Wire the production ServiceLocator that _getCurrentUserId() uses.
    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(mockAuth);
    ServiceLocator.initialize(DIContainer());

    when(() => mockAuth.currentUserId).thenReturn('u1');

    // Default stub — individual tests override when they need lookup.
    when(
      () => mockLookup.lookupFromRaw(
        any(),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => _lookupWith({}));

    evaluator = PersonalTagRuleEvaluator(lookupService: mockLookup);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  // ── Test 1: empty rules → empty result, lookup never called ─────────────────

  test(
    'empty tagRulePairs returns empty set without calling the lookup service',
    () async {
      // Intent: when there are no rules at all the evaluator short-circuits
      // and must NOT fire a (potentially expensive) Firestore lookup.
      final recipe = RecipeBuilder().withTitle('Pasta').build();

      final result = await evaluator.evaluateRulesForRecipe(
        recipe,
        [],
        [],
        [],
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockLookup.lookupFromRaw(
          any(),
          userId: any(named: 'userId'),
        ),
      );
    },
  );

  // ── Test 2: matching rule → tag ID appears in result ────────────────────────

  test(
    'rule whose condition matches the recipe returns the owning tag ID',
    () async {
      // Intent: a keyword condition that matches the recipe title causes the
      // evaluator to include that tag ID in the result set.
      final tag = PersonalTagBuilder()
          .withId('pasta-tag')
          .withName('Pastamiddagar')
          .build();

      final rule = PersonalTagRuleBuilder()
          .withId('rule-kw')
          .withTagId('pasta-tag')
          .withKeywordCondition('pasta')
          .build();

      final recipe = RecipeBuilder()
          .withTitle('Pasta bolognese')
          .withIngredients(['pasta', 'köttfärs'])
          .build();

      final result = await evaluator.evaluateRulesForRecipe(
        recipe,
        [TagRulePair(tag, rule)],
        [tag],
        [],
      );

      expect(result, contains('pasta-tag'));
    },
  );

  // ── Test 3: non-matching rule → tag ID absent ────────────────────────────────

  test(
    'rule whose condition does not match the recipe excludes that tag ID',
    () async {
      // Intent: a keyword condition that is NOT present in the recipe leaves
      // the result set empty — the evaluator doesn't default-include tags.
      final tag = PersonalTagBuilder()
          .withId('fish-tag')
          .withName('Fiskrecept')
          .build();

      final rule = PersonalTagRuleBuilder()
          .withId('rule-fish')
          .withTagId('fish-tag')
          .withKeywordCondition('lax') // recipe has no lax
          .build();

      final recipe = RecipeBuilder()
          .withTitle('Pasta bolognese')
          .withIngredients(['pasta', 'köttfärs'])
          .build();

      final result = await evaluator.evaluateRulesForRecipe(
        recipe,
        [TagRulePair(tag, rule)],
        [tag],
        [],
      );

      expect(
        result,
        isEmpty,
        reason: 'No keyword "lax" in recipe — tag must not be applied',
      );
    },
  );

  // ── Test 4: exclusive group keeps only the first matching tag ────────────────

  test(
    'exclusive group enforcement keeps only one tag when two rules match',
    () async {
      // Intent: when two tags belong to the same exclusive group and both
      // rules match, the evaluator must drop the second and emit exactly one.
      // This guards the "difficulty" radio-group contract.
      const groupId = 'difficulty-group';
      final group = _exclusiveGroup(groupId);

      final easyTag = PersonalTagBuilder()
          .withId('easy-tag')
          .withGroupId(groupId)
          .withName('Enkel')
          .build();

      final hardTag = PersonalTagBuilder()
          .withId('hard-tag')
          .withGroupId(groupId)
          .withName('Avancerad')
          .build();

      // Both rules match on the same keyword so both would fire without
      // exclusive-group enforcement.
      final easyRule = PersonalTagRuleBuilder()
          .withId('rule-easy')
          .withTagId('easy-tag')
          .withKeywordCondition('pasta')
          .build();

      final hardRule = PersonalTagRuleBuilder()
          .withId('rule-hard')
          .withTagId('hard-tag')
          .withKeywordCondition('pasta')
          .build();

      final recipe = RecipeBuilder()
          .withTitle('Pasta carbonara')
          .withIngredients(['pasta', 'ägg'])
          .build();

      final result = await evaluator.evaluateRulesForRecipe(
        recipe,
        [TagRulePair(easyTag, easyRule), TagRulePair(hardTag, hardRule)],
        [easyTag, hardTag],
        [group],
      );

      // Exactly one tag from the exclusive group must survive.
      expect(
        result.length,
        equals(1),
        reason: 'Exclusive group must emit exactly one tag',
      );
      // The surviving tag must belong to the group.
      expect(
        {easyTag.id, hardTag.id}.containsAll(result),
        isTrue,
        reason: 'The surviving tag must be one of the two group members',
      );
    },
  );

  // ── Test 5: evaluateRulesWithSources tracks which rule triggered each tag ───

  test(
    'evaluateRulesWithSources returns the rule ID that matched each tag',
    () async {
      // Intent: source tracking is the contract for RecipePersonalTag storage.
      // If a rule matches, its ID must appear in the sources list for that tag.
      // A test that only checks "tag is present" can't catch a bug where
      // sources are empty or misattributed.
      final tag = PersonalTagBuilder()
          .withId('quick-tag')
          .withName('Snabb')
          .build();

      final rule = PersonalTagRuleBuilder()
          .withId('rule-quick-kw')
          .withTagId('quick-tag')
          .withKeywordCondition('snabb')
          .build();

      final recipe = RecipeBuilder().withTitle('Snabb pasta').withIngredients([
        'pasta',
      ]).build();

      final result = await evaluator.evaluateRulesWithSources(
        recipe,
        [TagRulePair(tag, rule)],
        [tag],
        [],
      );

      expect(result, contains('quick-tag'));
      expect(
        result['quick-tag'],
        contains('rule-quick-kw'),
        reason: 'The matching rule ID must appear in the sources list',
      );
    },
  );
}
