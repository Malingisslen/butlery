import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/services/tagging/tagging_service.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

// Mocks
class MockIngredientLookupService extends Mock
    implements IngredientLookupService {}

class MockTagGenerator extends Mock implements TagGenerator {}

class MockUserIngredientRepository extends Mock
    implements UserIngredientRepository {}

void main() {
  late TaggingService service;
  late MockIngredientLookupService mockLookupService;
  late MockTagGenerator mockTagGenerator;
  late MockUserIngredientRepository mockUserIngredientRepo;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(RecipeBuilder().build());
    registerFallbackValue(_createTestLookupResult());
    registerFallbackValue(const Duration(seconds: 30));
    registerFallbackValue(_createTestIngredientData());
  });

  setUp(() {
    mockLookupService = MockIngredientLookupService();
    mockTagGenerator = MockTagGenerator();
    mockUserIngredientRepo = MockUserIngredientRepository();

    // Default stub for initialize/dispose
    when(() => mockLookupService.initialize()).thenAnswer((_) async {});
    when(() => mockLookupService.dispose()).thenAnswer((_) async {});

    service = TaggingService(
      lookupService: mockLookupService,
      tagGenerator: mockTagGenerator,
      userIngredientRepository: mockUserIngredientRepo,
    );
  });

  group('TaggingService', () {
    group('H20: generateTags', () {
      test('returns TagResult for valid recipe', () async {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withIngredients(['tomat', 'lök']).build();
        final lookupResult = _createTestLookupResult();
        final tagResult = _createTestTagResult();

        when(() => mockLookupService.lookupFromRaw(any(),
                userId: any(named: 'userId')))
            .thenAnswer((_) async => lookupResult);
        when(() => mockTagGenerator.generate(
              ingredients: any(named: 'ingredients'),
              recipe: any(named: 'recipe'),
              timeout: any(named: 'timeout'),
            )).thenReturn(tagResult);

        final result = await service.generateTags(recipe);

        expect(result, isNotNull);
        expect(result!.tags, isNotEmpty);
        verify(() => mockLookupService.lookupFromRaw(any(),
            userId: any(named: 'userId'))).called(1);
        verify(() => mockTagGenerator.generate(
              ingredients: any(named: 'ingredients'),
              recipe: any(named: 'recipe'),
              timeout: any(named: 'timeout'),
            )).called(1);
      });

      test('returns empty TagResult for recipe with no ingredients', () async {
        final recipe = RecipeBuilder()
            .withTitle('Empty Recipe')
            .withIngredients([]).build();

        final result = await service.generateTags(recipe);

        expect(result, isNotNull);
        expect(result!.tags, isEmpty);
        // Lookup should not be called for empty ingredients
        verifyNever(() => mockLookupService.lookupFromRaw(any(),
            userId: any(named: 'userId')));
      });

      test('returns failed result on lookup timeout', () async {
        final recipe = RecipeBuilder()
            .withTitle('Timeout Recipe')
            .withIngredients(['tomat']).build();

        when(() => mockLookupService.lookupFromRaw(any(),
            userId: any(named: 'userId'))).thenAnswer((_) async {
          throw TimeoutException('Lookup timeout');
        });

        final result = await service.generateTags(recipe);

        expect(result, isNotNull);
        expect(result!.tags, isEmpty);
        // TagGenerator should not be called on lookup timeout
        verifyNever(() => mockTagGenerator.generate(
              ingredients: any(named: 'ingredients'),
              recipe: any(named: 'recipe'),
              timeout: any(named: 'timeout'),
            ));
      });

      test('passes remaining timeout to TagGenerator', () async {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withIngredients(['tomat']).build();
        final lookupResult = _createTestLookupResult();
        final tagResult = _createTestTagResult();

        when(() => mockLookupService.lookupFromRaw(any(),
                userId: any(named: 'userId')))
            .thenAnswer((_) async => lookupResult);
        when(() => mockTagGenerator.generate(
              ingredients: any(named: 'ingredients'),
              recipe: any(named: 'recipe'),
              timeout: any(named: 'timeout'),
            )).thenReturn(tagResult);

        await service.generateTags(recipe);

        // Verify timeout is passed (will be less than 30 seconds due to lookup time)
        final captured = verify(() => mockTagGenerator.generate(
              ingredients: any(named: 'ingredients'),
              recipe: any(named: 'recipe'),
              timeout: captureAny(named: 'timeout'),
            )).captured;

        expect(captured.single, isA<Duration>());
        final duration = captured.single as Duration;
        expect(duration.inSeconds, lessThanOrEqualTo(30));
      });
    });

    group('H20: generatePreview', () {
      test('calls generatePhase1Only for preview', () async {
        final recipe = RecipeBuilder()
            .withTitle('Preview Recipe')
            .withIngredients(['tomat']).build();
        final lookupResult = _createTestLookupResult();
        final phase1Result = _createTestTagResult(tags: {'phase1-tag'});

        when(() => mockLookupService.lookupFromRaw(any(),
                userId: any(named: 'userId')))
            .thenAnswer((_) async => lookupResult);
        when(() => mockTagGenerator.generatePhase1Only(
              ingredients: any(named: 'ingredients'),
              recipe: any(named: 'recipe'),
            )).thenReturn(phase1Result);

        final result = await service.generatePreview(recipe);

        expect(result, isNotNull);
        expect(result!.tags, contains('phase1-tag'));
        verify(() => mockTagGenerator.generatePhase1Only(
              ingredients: any(named: 'ingredients'),
              recipe: any(named: 'recipe'),
            )).called(1);
        // Full generate should NOT be called for preview
        verifyNever(() => mockTagGenerator.generate(
              ingredients: any(named: 'ingredients'),
              recipe: any(named: 'recipe'),
              timeout: any(named: 'timeout'),
            ));
      });

      test('returns empty result for empty ingredients', () async {
        final recipe = RecipeBuilder()
            .withTitle('Empty Preview')
            .withIngredients([]).build();

        final result = await service.generatePreview(recipe);

        expect(result, isNotNull);
        expect(result!.tags, isEmpty);
      });
    });

    group('H20: lookupIngredients', () {
      test('delegates to lookupService', () async {
        final lookupResult = _createTestLookupResult();

        when(() => mockLookupService.lookupFromRaw(any(),
                userId: any(named: 'userId')))
            .thenAnswer((_) async => lookupResult);

        final result = await service.lookupIngredients(['tomat', 'lök']);

        expect(result, isNotNull);
        expect(result!.matchedCount, 2);
        verify(() => mockLookupService.lookupFromRaw(['tomat', 'lök'],
            userId: any(named: 'userId'))).called(1);
      });
    });

    group('H20: needsRetagging', () {
      test('returns true for recipe with no tagResult', () {
        final recipe = RecipeBuilder()
            .withTitle('No Tags')
            .withIngredients(['tomat']).build();

        expect(service.needsRetagging(recipe), isTrue);
      });

      test('returns true for recipe with old generator version', () {
        final recipe = _createRecipeWithTagResult(
          TagResult(
            tags: {'test'},
            allergenStatus: {},
            dietaryStatus: {},
            coverage: 1.0,
            unknownIngredients: [],
            generatorVersion: 'v0.0.1', // Old version
            generatedAt: DateTime.now(),
          ),
        );

        expect(service.needsRetagging(recipe), isTrue);
      });

      test('returns false for recipe with current generator version', () {
        final recipe = _createRecipeWithTagResult(
          TagResult(
            tags: {'test'},
            allergenStatus: {},
            dietaryStatus: {},
            coverage: 1.0,
            unknownIngredients: [],
            generatorVersion: kTagGeneratorVersion,
            generatedAt: DateTime.now(),
          ),
        );

        expect(service.needsRetagging(recipe), isFalse);
      });
    });

    // Note: saveUserIngredient requires authentication context which is not
    // available in unit tests. The method is tested in integration tests.

    group('H20: getUnknownIngredients', () {
      test('returns unmatched ingredients from lookup', () async {
        final recipe = RecipeBuilder()
            .withTitle('Partial Match')
            .withIngredients(['tomat', 'unknown1', 'unknown2']).build();
        final lookupResult = IngredientLookupResult.fromLists(
          matched: [_createTestIngredientData()],
          unmatched: ['unknown1', 'unknown2'],
        );

        when(() => mockLookupService.lookupFromRaw(any(),
                userId: any(named: 'userId')))
            .thenAnswer((_) async => lookupResult);

        final result = await service.getUnknownIngredients(recipe);

        expect(result, hasLength(2));
        expect(result, contains('unknown1'));
        expect(result, contains('unknown2'));
      });

      test('returns empty list when all ingredients matched', () async {
        final recipe = RecipeBuilder()
            .withTitle('Full Match')
            .withIngredients(['tomat', 'lök']).build();
        final lookupResult = _createTestLookupResult();

        when(() => mockLookupService.lookupFromRaw(any(),
                userId: any(named: 'userId')))
            .thenAnswer((_) async => lookupResult);

        final result = await service.getUnknownIngredients(recipe);

        expect(result, isEmpty);
      });
    });

    // Note: retagUserRecipes requires authentication context which is not
    // available in unit tests. These methods are better tested in integration tests.
    // The key logic (needsRetagging, generateTags) is already covered above.

    group('initialization', () {
      test('initializes lookup service on init', () async {
        await service.initialize();

        verify(() => mockLookupService.initialize()).called(1);
      });

      test('disposes lookup service on dispose', () async {
        await service.dispose();

        verify(() => mockLookupService.dispose()).called(1);
      });
    });
  });
}

// Helper functions to create test data
Recipe _createRecipeWithTagResult(TagResult tagResult, {String? id}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: 'Test Recipe',
      description: 'A test recipe',
      ingredients: ['tomat', 'lök'],
      instructions: ['Step 1'],
      mealType: 'Middag',
      portions: 4,
      timeMinutes: 30,
      tagResult: tagResult,
    ),
    type: RecipeType.personal,
  );
}

IngredientLookupResult _createTestLookupResult() {
  return IngredientLookupResult.fromLists(
    matched: [
      _createTestIngredientData(id: 'tomato', swedish: 'tomat'),
      _createTestIngredientData(id: 'onion', swedish: 'lök'),
    ],
    unmatched: [],
  );
}

IngredientData _createTestIngredientData({
  String id = 'test-id',
  String swedish = 'test',
}) {
  return IngredientData(
    id: id,
    swedish: swedish,
    english: swedish,
    group: 'test',
    properties: const {},
  );
}

TagResult _createTestTagResult({Set<String>? tags}) {
  return TagResult(
    tags: tags ?? {'tag1', 'tag2'},
    allergenStatus: {'gluten': TriState.free},
    dietaryStatus: {'vegansk': TriState.free},
    coverage: 1.0,
    unknownIngredients: [],
    generatorVersion: kTagGeneratorVersion,
    generatedAt: DateTime.now(),
  );
}
