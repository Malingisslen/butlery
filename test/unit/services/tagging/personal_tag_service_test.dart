import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/personal_tag_crud_service.dart';
import 'package:butlery/services/tagging/personal_tag_rule_evaluator.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';

import '../../../infrastructure/builders/personal_tag_builder.dart';
import '../../../infrastructure/builders/recipe_builder.dart';

// Mocks
class MockFirebasePersonalTagRepository extends Mock
    implements FirebasePersonalTagRepository {}

class MockFirebasePersonalTagGroupRepository extends Mock
    implements FirebasePersonalTagGroupRepository {}

class MockIngredientLookupService extends Mock
    implements IngredientLookupService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRecipeRepository extends Mock implements RecipeRepository {}

class MockFirebaseRecipeRepository extends Mock
    implements FirebaseRecipeRepository {}

// Local WriteBatch mock — the tests below need `verify(() => batch.commit())`,
// which requires a real mocktail Mock. A FakeFirebaseFirestore batch won't
// work because we can't verify calls on it.
// ignore: subtype_of_sealed_class
class MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  late PersonalTagService service;
  late MockFirebasePersonalTagRepository mockTagRepository;
  late MockFirebasePersonalTagGroupRepository mockGroupRepository;
  late MockIngredientLookupService mockLookupService;
  late MockAuthRepository mockAuthRepository;
  late MockFirebaseRecipeRepository mockRecipeRepository;

  setUpAll(() async {
    // Register fallback values for mocktail
    registerFallbackValue(RecipeBuilder().build());
    registerFallbackValue(PersonalTagBuilder().build());
    registerFallbackValue(_createTestLookupResult());
    registerFallbackValue(_createTestIngredientData());
  });

  setUp(() async {
    mockTagRepository = MockFirebasePersonalTagRepository();
    mockGroupRepository = MockFirebasePersonalTagGroupRepository();
    mockLookupService = MockIngredientLookupService();
    mockAuthRepository = MockAuthRepository();
    mockRecipeRepository = MockFirebaseRecipeRepository();

    // Reset and reinitialize GetIt with mock repositories
    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(mockAuthRepository);
    getIt.registerSingleton<RecipeRepository>(mockRecipeRepository);

    // Initialize production ServiceLocator with DIContainer
    final container = DIContainer();
    ServiceLocator.initialize(container);

    // Configure mock auth to return a user ID
    when(() => mockAuthRepository.currentUserId).thenReturn('test-user-123');

    // Default lookup service stubs
    when(() => mockLookupService.initialize()).thenAnswer((_) async {});
    when(() => mockLookupService.dispose()).thenAnswer((_) async {});

    // #6: Default group repository stub for exclusive group enforcement
    when(() => mockGroupRepository.getAllSorted()).thenAnswer((_) async => []);

    final crudService = PersonalTagCrudService(
      tagRepository: mockTagRepository,
      groupRepository: mockGroupRepository,
    );

    final ruleEvaluator = PersonalTagRuleEvaluator(
      lookupService: mockLookupService,
    );

    service = PersonalTagService(
      crudService: crudService,
      ruleEvaluator: ruleEvaluator,
      tagRepository: mockTagRepository,
      groupRepository: mockGroupRepository,
    );
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('PersonalTagService', () {
    group('CRIT-5: evaluateRulesForRecipe', () {
      test('returns empty set when no enabled rules exist', () async {
        // Arrange: No tags with enabled rules
        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => []);

        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withIngredients(['kyckling', 'lök']).build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert
        expect(result, isEmpty);
        verifyNever(() => mockLookupService.lookupFromRaw(
              any(),
              userId: any(named: 'userId'),
            ));
      });

      test('matches recipe with ingredient condition', () async {
        // Arrange: Tag with ingredient rule for chicken
        final tag = PersonalTagBuilder()
            .withId('chicken-tag')
            .withName('Kycklingrecept')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Contains chicken')
                  .withIngredientCondition('kyckling')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        final recipe = RecipeBuilder()
            .withTitle('Kycklinggryta')
            .withIngredients(['500g kyckling', 'lök', 'grädde']).build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert
        expect(result, contains('chicken-tag'));
        expect(result.length, 1);
      });

      test('does not match recipe without matching ingredient', () async {
        // Arrange: Tag with ingredient rule for chicken
        final tag = PersonalTagBuilder()
            .withId('chicken-tag')
            .withName('Kycklingrecept')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Contains chicken')
                  .withIngredientCondition('kyckling')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        final recipe = RecipeBuilder()
            .withTitle('Pasta Bolognese')
            .withIngredients(['köttfärs', 'tomat', 'lök']).build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert
        expect(result, isEmpty);
      });

      test('passes userId to lookup service for property conditions', () async {
        // Arrange: Tag with property rule (requires lookup)
        final tag = PersonalTagBuilder()
            .withId('fish-tag')
            .withName('Fiskrecept')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Contains fish')
                  .withPropertyCondition('fish')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        when(() => mockLookupService.lookupFromRaw(
              any(),
              userId: any(named: 'userId'),
            )).thenAnswer((_) async => _createFishLookupResult());

        final recipe = RecipeBuilder()
            .withTitle('Stekt lax')
            .withIngredients(['lax', 'citron']).build();

        // Act
        await service.evaluateRulesForRecipe(recipe);

        // Assert: Verify userId was passed with correct value (CRIT-5 fix)
        verify(() => mockLookupService.lookupFromRaw(
              any(),
              userId: 'test-user-123', // Specific value from mock
            )).called(1);
      });

      test('handles MatchMode.any requiring any condition', () async {
        // Arrange: Tag with rule requiring chicken OR pasta
        final tag = PersonalTagBuilder()
            .withId('favorite-tag')
            .withName('Favoriter')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Chicken or pasta')
                  .withIngredientCondition('kyckling')
                  .withKeywordCondition('pasta')
                  .withMatchMode(MatchMode.any)
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        // Recipe with pasta in title (keyword match)
        final pastaRecipe = RecipeBuilder()
            .withTitle('Pasta carbonara')
            .withIngredients(['spaghetti', 'bacon', 'ägg']).build();

        // Act
        final result = await service.evaluateRulesForRecipe(pastaRecipe);

        // Assert: Should match because keyword condition passes
        expect(result, contains('favorite-tag'));
      });

      test('ignores disabled rules', () async {
        // Arrange: Tag with disabled rule
        final tag = PersonalTagBuilder()
            .withId('disabled-tag')
            .withName('Disabled Tag')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Disabled rule')
                  .withIngredientCondition('kyckling')
                  .asDisabled()
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        final recipe =
            RecipeBuilder().withIngredients(['kyckling', 'lök']).build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert: Disabled rule should not match
        expect(result, isEmpty);
      });

      test('matches multiple tags when multiple rules match', () async {
        // Arrange: Multiple tags with matching rules
        final chickenTag = PersonalTagBuilder()
            .withId('chicken-tag')
            .withName('Kyckling')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Contains chicken')
                  .withIngredientCondition('kyckling')
                  .build(),
            )
            .build();

        final quickTag = PersonalTagBuilder()
            .withId('quick-tag')
            .withName('Snabbt')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Quick recipe')
                  .withTimeCondition(30, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [chickenTag, quickTag]);

        final recipe = RecipeBuilder()
            .withTitle('Snabb kyckling')
            .withIngredients(['kyckling', 'lök'])
            .withTimeMinutes(20)
            .build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert: Both tags should match
        expect(result, containsAll(['chicken-tag', 'quick-tag']));
        expect(result.length, 2);
      });
    });

    group('CRIT-5: evaluateRulesForRecipes (batch)', () {
      test('returns empty map when no enabled rules exist', () async {
        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => []);

        final recipes = [
          RecipeBuilder().withId('recipe-1').build(),
          RecipeBuilder().withId('recipe-2').build(),
        ];

        // Act
        final result = await service.evaluateRulesForRecipes(recipes);

        // Assert
        expect(result, isEmpty);
      });

      test('evaluates rules for multiple recipes', () async {
        // Arrange: Tag with ingredient rule for chicken
        final tag = PersonalTagBuilder()
            .withId('chicken-tag')
            .withName('Kycklingrecept')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Contains chicken')
                  .withIngredientCondition('kyckling')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        final chickenRecipe = RecipeBuilder()
            .withId('recipe-1')
            .withIngredients(['kyckling', 'lök']).build();

        final beefRecipe = RecipeBuilder()
            .withId('recipe-2')
            .withIngredients(['nötkött', 'potatis']).build();

        final anotherChickenRecipe = RecipeBuilder()
            .withId('recipe-3')
            .withIngredients(['kycklingbröst', 'grädde']).build();

        final recipes = [chickenRecipe, beefRecipe, anotherChickenRecipe];

        // Act
        final result = await service.evaluateRulesForRecipes(recipes);

        // Assert: Only chicken recipes should match
        expect(result.containsKey('recipe-1'), isTrue);
        expect(result.containsKey('recipe-2'), isFalse);
        expect(result.containsKey('recipe-3'), isTrue);
        expect(result['recipe-1'], contains('chicken-tag'));
        expect(result['recipe-3'], contains('chicken-tag'));
      });

      test('passes userId to lookup service in batch mode', () async {
        // Arrange: Tag with property rule (requires lookup)
        final tag = PersonalTagBuilder()
            .withId('fish-tag')
            .withName('Fiskrecept')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Contains fish')
                  .withPropertyCondition('fish')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        when(() => mockLookupService.lookupFromRaw(
              any(),
              userId: any(named: 'userId'),
            )).thenAnswer((_) async => _createFishLookupResult());

        final recipes = [
          RecipeBuilder().withId('recipe-1').withIngredients(['lax']).build(),
          RecipeBuilder().withId('recipe-2').withIngredients(['torsk']).build(),
        ];

        // Act
        await service.evaluateRulesForRecipes(recipes);

        // Assert: Verify userId was passed for each recipe (CRIT-5 fix)
        verify(() => mockLookupService.lookupFromRaw(
              any(),
              userId: any(named: 'userId'),
            )).called(2);
      });

      test('returns empty map for empty recipe list', () async {
        final tag = PersonalTagBuilder()
            .withRule(PersonalTagRuleBuilder()
                .withIngredientCondition('kyckling')
                .build())
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        // Act
        final result = await service.evaluateRulesForRecipes([]);

        // Assert
        expect(result, isEmpty);
      });
    });

    group('suggestTagsForRecipe', () {
      test('returns PersonalTag objects for matching rules', () async {
        // Arrange
        final tag = PersonalTagBuilder()
            .withId('chicken-tag')
            .withName('Kycklingrecept')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Contains chicken')
                  .withIngredientCondition('kyckling')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        final recipe =
            RecipeBuilder().withIngredients(['kyckling', 'lök']).build();

        // Act
        final result = await service.suggestTagsForRecipe(recipe);

        // Assert
        expect(result.length, 1);
        expect(result.first.id, 'chicken-tag');
        expect(result.first.name, 'Kycklingrecept');
      });

      test('returns empty list when no rules match', () async {
        final tag = PersonalTagBuilder()
            .withId('fish-tag')
            .withName('Fiskrecept')
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Contains fish')
                  .withIngredientCondition('fisk')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [tag]);

        final recipe =
            RecipeBuilder().withIngredients(['kyckling', 'lök']).build();

        // Act
        final result = await service.suggestTagsForRecipe(recipe);

        // Assert
        expect(result, isEmpty);
      });
    });

    group('#6: Exclusive group enforcement', () {
      test('allows multiple tags from non-exclusive groups', () async {
        // Arrange: Two tags in a non-exclusive group
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          isExclusive: false, // Non-exclusive
        );

        final easyTag = PersonalTagBuilder()
            .withId('easy-tag')
            .withName('Lätt')
            .withGroupId(group.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Quick recipe')
                  .withTimeCondition(30, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        final mediumTag = PersonalTagBuilder()
            .withId('medium-tag')
            .withName('Medium')
            .withGroupId(group.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Medium time')
                  .withTimeCondition(60, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [easyTag, mediumTag]);
        when(() => mockGroupRepository.getAllSorted())
            .thenAnswer((_) async => [group]);

        final recipe = RecipeBuilder()
            .withTimeMinutes(20) // Matches both <30 and <60
            .build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert: Both tags should match (non-exclusive)
        expect(result, containsAll(['easy-tag', 'medium-tag']));
        expect(result.length, 2);
      });

      test('allows only one tag from exclusive group', () async {
        // Arrange: Two tags in an EXCLUSIVE group
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          isExclusive: true, // Exclusive!
        );

        final easyTag = PersonalTagBuilder()
            .withId('easy-tag')
            .withName('Lätt')
            .withGroupId(group.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Quick recipe')
                  .withTimeCondition(30, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        final mediumTag = PersonalTagBuilder()
            .withId('medium-tag')
            .withName('Medium')
            .withGroupId(group.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Medium time')
                  .withTimeCondition(60, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [easyTag, mediumTag]);
        when(() => mockGroupRepository.getAllSorted())
            .thenAnswer((_) async => [group]);

        final recipe = RecipeBuilder()
            .withTimeMinutes(20) // Matches both <30 and <60
            .build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert: Only first matching tag from exclusive group
        expect(result.length, 1);
        expect(result, contains('easy-tag'));
        expect(result, isNot(contains('medium-tag')));
      });

      test('allows tags from different exclusive groups', () async {
        // Arrange: Two exclusive groups
        final difficultyGroup = PersonalTagGroup.create(
          name: 'Difficulty',
          isExclusive: true,
        );

        final mealTypeGroup = PersonalTagGroup.create(
          name: 'Meal Type',
          isExclusive: true,
        );

        final easyTag = PersonalTagBuilder()
            .withId('easy-tag')
            .withName('Lätt')
            .withGroupId(difficultyGroup.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Quick recipe')
                  .withTimeCondition(30, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        final lunchTag = PersonalTagBuilder()
            .withId('lunch-tag')
            .withName('Lunch')
            .withGroupId(mealTypeGroup.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Lunch keyword')
                  .withKeywordCondition('lunch')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [easyTag, lunchTag]);
        when(() => mockGroupRepository.getAllSorted())
            .thenAnswer((_) async => [difficultyGroup, mealTypeGroup]);

        final recipe = RecipeBuilder()
            .withTitle('Quick lunch pasta')
            .withTimeMinutes(20)
            .build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert: One tag from each exclusive group
        expect(result, containsAll(['easy-tag', 'lunch-tag']));
        expect(result.length, 2);
      });

      test('allows ungrouped tags alongside exclusive groups', () async {
        // Arrange: One exclusive group + one ungrouped tag
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          isExclusive: true,
        );

        final easyTag = PersonalTagBuilder()
            .withId('easy-tag')
            .withName('Lätt')
            .withGroupId(group.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Quick recipe')
                  .withTimeCondition(30, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        final favoriteTag = PersonalTagBuilder()
            .withId('favorite-tag')
            .withName('Favorit')
            .withGroupId(null) // Ungrouped
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Favorite keyword')
                  .withKeywordCondition('favorit')
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [easyTag, favoriteTag]);
        when(() => mockGroupRepository.getAllSorted())
            .thenAnswer((_) async => [group]);

        final recipe = RecipeBuilder()
            .withTitle('Min favorit pasta')
            .withTimeMinutes(20)
            .build();

        // Act
        final result = await service.evaluateRulesForRecipe(recipe);

        // Assert: Both tags match (ungrouped + one from exclusive)
        expect(result, containsAll(['easy-tag', 'favorite-tag']));
        expect(result.length, 2);
      });

      test('enforces exclusive groups in batch evaluation', () async {
        // Arrange: Exclusive group with multiple matching tags
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          isExclusive: true,
        );

        final easyTag = PersonalTagBuilder()
            .withId('easy-tag')
            .withName('Lätt')
            .withGroupId(group.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Quick recipe')
                  .withTimeCondition(30, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        final mediumTag = PersonalTagBuilder()
            .withId('medium-tag')
            .withName('Medium')
            .withGroupId(group.id)
            .withRule(
              PersonalTagRuleBuilder()
                  .withName('Medium time')
                  .withTimeCondition(60, operator: ConditionOperator.lessThan)
                  .build(),
            )
            .build();

        when(() => mockTagRepository.getAllSorted())
            .thenAnswer((_) async => [easyTag, mediumTag]);
        when(() => mockGroupRepository.getAllSorted())
            .thenAnswer((_) async => [group]);

        final recipes = [
          RecipeBuilder()
              .withId('recipe-1')
              .withTimeMinutes(20) // Matches both
              .build(),
          RecipeBuilder()
              .withId('recipe-2')
              .withTimeMinutes(45) // Matches only medium
              .build(),
        ];

        // Act
        final result = await service.evaluateRulesForRecipes(recipes);

        // Assert: Each recipe gets only one tag from exclusive group
        expect(result['recipe-1']?.length, 1);
        expect(result['recipe-1'], contains('easy-tag'));
        expect(result['recipe-2']?.length, 1);
        expect(result['recipe-2'], contains('medium-tag'));
      });
    });

    group('updateTag - rename cascade', () {
      test('should cascade rename to recipes when tag name changes', () async {
        // Arrange
        final existingTag =
            PersonalTagBuilder().withId('tag-1').withName('Old Name').build();

        final updatedTag =
            PersonalTagBuilder().withId('tag-1').withName('New Name').build();

        when(() => mockTagRepository.nameExists('New Name', excludeId: 'tag-1'))
            .thenAnswer((_) async => false);
        when(() => mockTagRepository.read('tag-1'))
            .thenAnswer((_) async => existingTag);
        when(() => mockTagRepository.update(any())).thenAnswer((_) async {});
        when(() => mockRecipeRepository.renamePersonalTagInRecipes(
              'tag-1',
              'New Name',
            )).thenAnswer((_) async => 3);

        // Act
        await service.updateTag(updatedTag);

        // Assert: Verify rename was cascaded to recipes using tag ID
        verify(() => mockRecipeRepository.renamePersonalTagInRecipes(
              'tag-1',
              'New Name',
            )).called(1);
      });

      test('should not cascade when tag name has not changed', () async {
        // Arrange
        final existingTag =
            PersonalTagBuilder().withId('tag-1').withName('Same Name').build();

        final updatedTag =
            PersonalTagBuilder().withId('tag-1').withName('Same Name').build();

        when(() =>
                mockTagRepository.nameExists('Same Name', excludeId: 'tag-1'))
            .thenAnswer((_) async => false);
        when(() => mockTagRepository.read('tag-1'))
            .thenAnswer((_) async => existingTag);
        when(() => mockTagRepository.update(any())).thenAnswer((_) async {});

        // Act
        await service.updateTag(updatedTag);

        // Assert: No rename cascade should occur
        verifyNever(() => mockRecipeRepository.renamePersonalTagInRecipes(
              any(),
              any(),
            ));
      });

      test('should still update tag even when rename affects zero recipes',
          () async {
        // Arrange
        final existingTag =
            PersonalTagBuilder().withId('tag-1').withName('Old Name').build();

        final updatedTag =
            PersonalTagBuilder().withId('tag-1').withName('New Name').build();

        when(() => mockTagRepository.nameExists('New Name', excludeId: 'tag-1'))
            .thenAnswer((_) async => false);
        when(() => mockTagRepository.read('tag-1'))
            .thenAnswer((_) async => existingTag);
        when(() => mockTagRepository.update(any())).thenAnswer((_) async {});
        when(() => mockRecipeRepository.renamePersonalTagInRecipes(
              'tag-1',
              'New Name',
            )).thenAnswer((_) async => 0);

        // Act
        await service.updateTag(updatedTag);

        // Assert: Tag was updated in repository
        verify(() => mockTagRepository.update(any())).called(1);
        // Rename was still called using tag ID (returned 0 affected recipes)
        verify(() => mockRecipeRepository.renamePersonalTagInRecipes(
              'tag-1',
              'New Name',
            )).called(1);
      });

      test('should validate name before attempting rename cascade', () async {
        // Arrange: Tag with invalid name (contains comma)
        final updatedTag =
            PersonalTagBuilder().withId('tag-1').withName('Bad,Name').build();

        // Act: Should fail validation before reaching rename logic
        await service.updateTag(updatedTag);

        // Assert: Neither repository update nor rename should occur
        verifyNever(() => mockTagRepository.update(any()));
        verifyNever(() => mockRecipeRepository.renamePersonalTagInRecipes(
              any(),
              any(),
            ));
      });

      test('should reject update when new name already exists', () async {
        // Arrange
        final updatedTag = PersonalTagBuilder()
            .withId('tag-1')
            .withName('Duplicate Name')
            .build();

        when(() => mockTagRepository.nameExists('Duplicate Name',
            excludeId: 'tag-1')).thenAnswer((_) async => true);

        // Act
        await service.updateTag(updatedTag);

        // Assert: No update or rename should occur
        verifyNever(() => mockTagRepository.update(any()));
        verifyNever(() => mockRecipeRepository.renamePersonalTagInRecipes(
              any(),
              any(),
            ));
      });

      test('should validate group exists when groupId is specified', () async {
        // Arrange
        final updatedTag = PersonalTagBuilder()
            .withId('tag-1')
            .withName('Valid Name')
            .withGroupId('nonexistent-group')
            .build();

        when(() =>
                mockTagRepository.nameExists('Valid Name', excludeId: 'tag-1'))
            .thenAnswer((_) async => false);
        when(() => mockGroupRepository.read('nonexistent-group'))
            .thenAnswer((_) async => null);

        // Act
        await service.updateTag(updatedTag);

        // Assert: No update or rename should occur
        verifyNever(() => mockTagRepository.update(any()));
        verifyNever(() => mockRecipeRepository.renamePersonalTagInRecipes(
              any(),
              any(),
            ));
      });

      test(
          'should handle existing tag not found gracefully during rename check',
          () async {
        // Arrange: _tagRepository.read returns null for the existing tag
        final updatedTag =
            PersonalTagBuilder().withId('tag-1').withName('New Name').build();

        when(() => mockTagRepository.nameExists('New Name', excludeId: 'tag-1'))
            .thenAnswer((_) async => false);
        when(() => mockTagRepository.read('tag-1'))
            .thenAnswer((_) async => null);
        when(() => mockTagRepository.update(any())).thenAnswer((_) async {});

        // Act
        await service.updateTag(updatedTag);

        // Assert: Tag is updated but no rename cascade (oldName is null)
        verify(() => mockTagRepository.update(any())).called(1);
        verifyNever(() => mockRecipeRepository.renamePersonalTagInRecipes(
              any(),
              any(),
            ));
      });
    });

    // BUT-1186: deleteTag now cascades the per-recipe removal via the
    // self-chunking removePersonalTagFromRecipes FIRST (so >500 recipes on one
    // tag never overflow the 500-op batch limit), THEN deletes the tag doc in
    // a separate batch. No longer one atomic batch.
    group('deleteTag - chunked cascade then delete (BUT-1186)', () {
      late MockWriteBatch mockBatch;

      setUp(() {
        mockBatch = MockWriteBatch();
        when(() => mockTagRepository.newWriteBatch()).thenReturn(mockBatch);
        when(() => mockBatch.commit()).thenAnswer((_) async {});
        registerFallbackValue(mockBatch);
      });

      test('cascades removal via chunked path, then deletes the tag', () async {
        when(() => mockRecipeRepository.removePersonalTagFromRecipes('tag-1'))
            .thenAnswer((_) async => 5);
        when(() => mockTagRepository.addDeleteToBatch(any(), 'tag-1'))
            .thenReturn(null);

        await service.deleteTag('tag-1');

        verify(() => mockRecipeRepository.removePersonalTagFromRecipes('tag-1'))
            .called(1);
        verify(() => mockTagRepository.addDeleteToBatch(mockBatch, 'tag-1'))
            .called(1);
        verify(() => mockBatch.commit()).called(1);
      });

      test('ordering — cascade runs BEFORE the tag delete commits', () async {
        final calls = <String>[];
        when(() => mockRecipeRepository.removePersonalTagFromRecipes('tag-1'))
            .thenAnswer((_) async {
          calls.add('cascade');
          return 3;
        });
        when(() => mockTagRepository.addDeleteToBatch(any(), 'tag-1'))
            .thenReturn(null);
        when(() => mockBatch.commit()).thenAnswer((_) async {
          calls.add('delete-commit');
        });

        await service.deleteTag('tag-1');

        expect(calls, ['cascade', 'delete-commit']);
      });

      test('does NOT delete the tag when the cascade throws', () async {
        when(() => mockRecipeRepository.removePersonalTagFromRecipes('tag-1'))
            .thenThrow(Exception('network drop mid-cascade'));
        when(() => mockTagRepository.addDeleteToBatch(any(), 'tag-1'))
            .thenReturn(null);

        await service.deleteTag('tag-1');

        // executeServiceOperation swallows the throw; crucially the tag delete
        // never ran, so the source tag survives with references already pulled.
        verifyNever(() => mockTagRepository.addDeleteToBatch(any(), any()));
        verifyNever(() => mockBatch.commit());
      });

      test('deletes the tag even when cascade affects zero recipes', () async {
        when(() => mockRecipeRepository.removePersonalTagFromRecipes('tag-1'))
            .thenAnswer((_) async => 0);
        when(() => mockTagRepository.addDeleteToBatch(any(), 'tag-1'))
            .thenReturn(null);

        await service.deleteTag('tag-1');

        verify(() => mockTagRepository.addDeleteToBatch(mockBatch, 'tag-1'))
            .called(1);
        verify(() => mockBatch.commit()).called(1);
      });

      test('should still delete tag when recipe repo is unavailable', () async {
        // Re-register GetIt without recipe repository to simulate unavailability
        final getIt = GetIt.instance;
        getIt.unregister<RecipeRepository>();

        when(() => mockTagRepository.addDeleteToBatch(any(), 'tag-1'))
            .thenReturn(null);

        await service.deleteTag('tag-1');

        verify(() => mockTagRepository.addDeleteToBatch(mockBatch, 'tag-1'))
            .called(1);
        verify(() => mockBatch.commit()).called(1);

        // Re-register for other tests
        getIt.registerSingleton<RecipeRepository>(mockRecipeRepository);
      });
    });

    // BUT-1186: mergeTags is no longer one atomic batch. It self-chunks the
    // retag of every recipe carrying fromId via replaceTagInRecipes (committed
    // across N batches inside the repo) FIRST, then deletes the source tag in a
    // SEPARATE batch. Ordering is a correctness invariant: a delete-failure
    // leaves the source tag intact (recipes already moved), so a re-run is a
    // safe idempotent no-op retag + retry-delete. Never delete before retags.
    group('mergeTags - chunked retag then delete (BUT-1186)', () {
      late MockWriteBatch mockBatch;

      setUp(() {
        mockBatch = MockWriteBatch();
        when(() => mockTagRepository.newWriteBatch()).thenReturn(mockBatch);
        when(() => mockBatch.commit()).thenAnswer((_) async {});
        registerFallbackValue(mockBatch);
      });

      PersonalTag toTag() =>
          PersonalTagBuilder().withId('to-id').withName('Destination').build();

      test('retags recipes (chunked path), THEN deletes fromId separately',
          () async {
        when(() => mockTagRepository.read('to-id'))
            .thenAnswer((_) async => toTag());
        when(() => mockRecipeRepository.replaceTagInRecipes(
            'from-id', 'to-id', any())).thenAnswer((_) async => 4);
        when(() => mockTagRepository.addDeleteToBatch(any(), 'from-id'))
            .thenReturn(null);

        final count = await service.mergeTags('from-id', 'to-id');

        expect(count, 4);
        // Retag delegated to the self-chunking repo method (commits internally).
        verify(() => mockRecipeRepository.replaceTagInRecipes(
            'from-id', 'to-id', any())).called(1);
        // Delete lands on its OWN batch, committed after the retag.
        verify(() => mockTagRepository.addDeleteToBatch(mockBatch, 'from-id'))
            .called(1);
        verify(() => mockBatch.commit()).called(1);
      });

      test('ordering — retag runs BEFORE the source-tag delete commits',
          () async {
        final calls = <String>[];
        when(() => mockTagRepository.read('to-id'))
            .thenAnswer((_) async => toTag());
        when(() => mockRecipeRepository.replaceTagInRecipes(
            'from-id', 'to-id', any())).thenAnswer((_) async {
          calls.add('retag');
          return 4;
        });
        when(() => mockTagRepository.addDeleteToBatch(any(), 'from-id'))
            .thenReturn(null);
        when(() => mockBatch.commit()).thenAnswer((_) async {
          calls.add('delete-commit');
        });

        await service.mergeTags('from-id', 'to-id');

        expect(calls, ['retag', 'delete-commit']);
      });

      test('does NOT delete fromId when the retag throws mid-way', () async {
        when(() => mockTagRepository.read('to-id'))
            .thenAnswer((_) async => toTag());
        when(() => mockRecipeRepository.replaceTagInRecipes(
                'from-id', 'to-id', any()))
            .thenThrow(Exception('network drop mid-retag'));
        when(() => mockTagRepository.addDeleteToBatch(any(), 'from-id'))
            .thenReturn(null);

        final count = await service.mergeTags('from-id', 'to-id');

        // Throw is swallowed by executeServiceOperation → 0; the source tag is
        // NEVER deleted, so recipe references are never orphaned.
        expect(count, 0);
        verifyNever(() => mockTagRepository.addDeleteToBatch(any(), any()));
        verifyNever(() => mockBatch.commit());
      });

      test('passes destination tag rich-entry (manual source) to the repo',
          () async {
        when(() => mockTagRepository.read('to-id'))
            .thenAnswer((_) async => toTag());
        when(() => mockTagRepository.addDeleteToBatch(any(), 'from-id'))
            .thenReturn(null);

        Map<String, dynamic>? captured;
        when(() => mockRecipeRepository.replaceTagInRecipes(
            'from-id', 'to-id', any())).thenAnswer((invocation) async {
          captured = invocation.positionalArguments[2] as Map<String, dynamic>;
          return 1;
        });

        await service.mergeTags('from-id', 'to-id');

        expect(captured, isNotNull);
        expect(captured!['tagId'], 'to-id');
        expect(captured!['name'], 'Destination');
        expect(captured!['sources'], ['manual']);
      });

      test('is a no-op when fromId == toId', () async {
        final count = await service.mergeTags('same', 'same');

        expect(count, 0);
        verifyNever(() => mockTagRepository.newWriteBatch());
        verifyNever(() =>
            mockRecipeRepository.replaceTagInRecipes(any(), any(), any()));
        verifyNever(() => mockTagRepository.addDeleteToBatch(any(), any()));
      });

      test('returns 0 without touching firestore on empty ids', () async {
        expect(await service.mergeTags('', 'to-id'), 0);
        expect(await service.mergeTags('from-id', ''), 0);
        verifyNever(() => mockTagRepository.newWriteBatch());
        verifyNever(() =>
            mockRecipeRepository.replaceTagInRecipes(any(), any(), any()));
      });

      test('does not delete fromId when destination tag does not exist',
          () async {
        // Missing-dest guard throws BEFORE any retag or delete.
        when(() => mockTagRepository.read('to-id'))
            .thenAnswer((_) async => null);

        final count = await service.mergeTags('from-id', 'to-id');

        expect(count, 0);
        verifyNever(() =>
            mockRecipeRepository.replaceTagInRecipes(any(), any(), any()));
        verifyNever(() => mockTagRepository.addDeleteToBatch(any(), any()));
        verifyNever(() => mockBatch.commit());
      });

      test('deletes fromId even when retag affects zero recipes', () async {
        when(() => mockTagRepository.read('to-id'))
            .thenAnswer((_) async => toTag());
        when(() => mockRecipeRepository.replaceTagInRecipes(
            'from-id', 'to-id', any())).thenAnswer((_) async => 0);
        when(() => mockTagRepository.addDeleteToBatch(any(), 'from-id'))
            .thenReturn(null);

        final count = await service.mergeTags('from-id', 'to-id');

        expect(count, 0);
        verify(() => mockTagRepository.addDeleteToBatch(mockBatch, 'from-id'))
            .called(1);
        verify(() => mockBatch.commit()).called(1);
      });
    });

    group('createTag', () {
      test('should create a valid tag', () async {
        // Arrange
        final tag = PersonalTagBuilder()
            .withId('new-tag')
            .withName('Valid Tag')
            .build();

        when(() => mockTagRepository.nameExists('Valid Tag'))
            .thenAnswer((_) async => false);
        when(() => mockTagRepository.create(any()))
            .thenAnswer((_) async => tag);

        // Act
        final result = await service.createTag(tag);

        // Assert
        expect(result, isNotNull);
        expect(result!.name, 'Valid Tag');
        verify(() => mockTagRepository.create(tag)).called(1);
      });

      test('should reject tag with duplicate name', () async {
        // Arrange
        final tag = PersonalTagBuilder().withName('Duplicate').build();

        when(() => mockTagRepository.nameExists('Duplicate'))
            .thenAnswer((_) async => true);

        // Act
        final result = await service.createTag(tag);

        // Assert: Returns null (error handled by executeServiceOperation)
        expect(result, isNull);
        verifyNever(() => mockTagRepository.create(any()));
      });

      test('should reject tag with invalid name', () async {
        // Arrange: Name with comma is invalid
        final tag = PersonalTagBuilder().withName('Bad,Tag').build();

        // Act
        final result = await service.createTag(tag);

        // Assert
        expect(result, isNull);
        verifyNever(() => mockTagRepository.create(any()));
      });
    });

    group('#7: Atomic group deletion', () {
      test('deletes group and clears tags in single batch', () async {
        // Arrange
        final mockBatch = MockWriteBatch();
        const groupId = 'test-group-id';

        when(() => mockTagRepository.newWriteBatch()).thenReturn(mockBatch);
        when(() => mockTagRepository.addClearGroupToBatch(mockBatch, groupId))
            .thenAnswer((_) async => 3); // 3 tags cleared
        when(() => mockGroupRepository.addDeleteToBatch(mockBatch, groupId))
            .thenReturn(null);
        when(() => mockBatch.commit()).thenAnswer((_) async {});

        // Act
        await service.deleteGroup(groupId);

        // Assert: Verify both operations use same batch
        verify(() => mockTagRepository.newWriteBatch()).called(1);
        verify(() => mockTagRepository.addClearGroupToBatch(mockBatch, groupId))
            .called(1);
        verify(() => mockGroupRepository.addDeleteToBatch(mockBatch, groupId))
            .called(1);
        verify(() => mockBatch.commit()).called(1);
      });

      test('commits batch even when no tags in group', () async {
        // Arrange
        final mockBatch = MockWriteBatch();
        const groupId = 'empty-group-id';

        when(() => mockTagRepository.newWriteBatch()).thenReturn(mockBatch);
        when(() => mockTagRepository.addClearGroupToBatch(mockBatch, groupId))
            .thenAnswer((_) async => 0); // No tags to clear
        when(() => mockGroupRepository.addDeleteToBatch(mockBatch, groupId))
            .thenReturn(null);
        when(() => mockBatch.commit()).thenAnswer((_) async {});

        // Act
        await service.deleteGroup(groupId);

        // Assert: Delete still happens even with no tags
        verify(() => mockBatch.commit()).called(1);
        verify(() => mockGroupRepository.addDeleteToBatch(mockBatch, groupId))
            .called(1);
      });

      test('handles batch commit errors gracefully', () async {
        // Arrange
        final mockBatch = MockWriteBatch();
        const groupId = 'error-group-id';

        when(() => mockTagRepository.newWriteBatch()).thenReturn(mockBatch);
        when(() => mockTagRepository.addClearGroupToBatch(mockBatch, groupId))
            .thenAnswer((_) async => 1);
        when(() => mockGroupRepository.addDeleteToBatch(mockBatch, groupId))
            .thenReturn(null);
        when(() => mockBatch.commit())
            .thenThrow(Exception('Firestore batch failed'));

        // Act: executeServiceOperation handles errors gracefully
        // The method should complete without throwing (error is logged)
        await service.deleteGroup(groupId);

        // Assert: Batch operations were attempted
        verify(() => mockBatch.commit()).called(1);
      });
    });
  });

  // BUT-1055: the `tagsMutated` signal replaces the always-on Firestore
  // snapshot listener that AutoPersonalTagDisplay used to hold open. These
  // tests pin the contract consumers rely on: it fires exactly on tag-set
  // mutations, NOT on group-only ones, and the cache is cleared BEFORE the
  // signal fires so a consumer that re-reads in response gets fresh data.
  group('BUT-1055: tagsMutated invalidation signal', () {
    test('fires once when a tag is created', () async {
      final tag =
          PersonalTagBuilder().withId('t1').withName('Vegetariskt').build();
      when(() => mockTagRepository.nameExists('Vegetariskt'))
          .thenAnswer((_) async => false);
      when(() => mockTagRepository.create(any())).thenAnswer((_) async => tag);

      final events = <void>[];
      final sub = service.tagsMutated.listen(events.add);

      await service.createTag(tag);
      await Future<void>.delayed(Duration.zero); // flush broadcast delivery

      expect(events.length, 1,
          reason: 'createTag must emit exactly one tagsMutated event');
      await sub.cancel();
    });

    test('does NOT fire on a group-only mutation (createGroup)', () async {
      // Proves the signal is tag-scoped: creating a group clears only the
      // groups cache, so tag consumers must not be needlessly woken.
      final group = PersonalTagGroup.create(name: 'Middag');
      registerFallbackValue(group);
      when(() => mockGroupRepository.nameExists('Middag'))
          .thenAnswer((_) async => false);
      when(() => mockGroupRepository.create(any()))
          .thenAnswer((_) async => group);

      final events = <void>[];
      final sub = service.tagsMutated.listen(events.add);

      await service.createGroup(group);
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty,
          reason: 'group-only mutation must not emit tagsMutated');
      await sub.cancel();
    });

    test('clears the cache before firing so consumers re-read fresh', () async {
      final tagA = PersonalTagBuilder().withId('a').withName('A').build();
      final tagB = PersonalTagBuilder().withId('b').withName('B').build();

      // Prime the cache with [tagA].
      when(() => mockTagRepository.getAllSorted())
          .thenAnswer((_) async => [tagA]);
      final first = await service.getAllTags();
      expect(first.map((t) => t.id), ['a']);

      // Repository now holds the post-mutation set.
      when(() => mockTagRepository.getAllSorted())
          .thenAnswer((_) async => [tagA, tagB]);
      when(() => mockTagRepository.nameExists('B'))
          .thenAnswer((_) async => false);
      when(() => mockTagRepository.create(any())).thenAnswer((_) async => tagB);

      await service.createTag(tagB); // _invalidateTagsCache → clears + emits

      // Because the cache was cleared, this re-reads from the repository
      // rather than returning the stale primed [tagA].
      final second = await service.getAllTags();
      expect(second.map((t) => t.id), ['a', 'b'],
          reason: 'getAllTags after a mutation must reflect fresh repo data');
      verify(() => mockTagRepository.getAllSorted()).called(2);
    });
  });
}

// Test helpers
IngredientLookupResult _createTestLookupResult() {
  return IngredientLookupResult.fromLists(
    matched: [_createTestIngredientData()],
    unmatched: [],
  );
}

IngredientLookupResult _createFishLookupResult() {
  return IngredientLookupResult.fromLists(
    matched: [
      IngredientData(
        id: 'salmon',
        swedish: 'lax',
        english: 'salmon',
        group: 'fish',
        properties: const {'fish', 'omega-3', 'protein'},
      ),
    ],
    unmatched: [],
  );
}

IngredientData _createTestIngredientData() {
  return IngredientData(
    id: 'chicken',
    swedish: 'kyckling',
    english: 'chicken',
    group: 'meat',
    properties: const {'meat', 'poultry', 'protein'},
  );
}
