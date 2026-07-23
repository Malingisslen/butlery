import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';
import 'package:butlery/services/tagging/phases/tag_phase5_cuisine.dart';
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
    // BUT-1483: runPhase1/runPhase5 now take the resolved config-backed phase
    // as their first arg, so mocktail needs fallbacks for those types too.
    registerFallbackValue(TagPhase1Base());
    registerFallbackValue(TagPhase5Cuisine());
    // BUT-553: per-phase methods need Phase*Result fallbacks so mocktail
    // can match `any()` for the new runPhaseN signatures.
    registerFallbackValue(_createTestPhase1Result(_createTestLookupResult()));
    registerFallbackValue(
      Phase2Result(
        tags: const {},
        phase1: _createTestPhase1Result(_createTestLookupResult()),
      ),
    );
    registerFallbackValue(
      Phase3Result(
        tags: const {},
        phase1: _createTestPhase1Result(_createTestLookupResult()),
        phase2: Phase2Result(
          tags: const {},
          phase1: _createTestPhase1Result(_createTestLookupResult()),
        ),
      ),
    );
    registerFallbackValue(
      Phase4Result(
        tags: const {},
        phase1: _createTestPhase1Result(_createTestLookupResult()),
        phase2: Phase2Result(
          tags: const {},
          phase1: _createTestPhase1Result(_createTestLookupResult()),
        ),
        phase3: Phase3Result(
          tags: const {},
          phase1: _createTestPhase1Result(_createTestLookupResult()),
          phase2: Phase2Result(
            tags: const {},
            phase1: _createTestPhase1Result(_createTestLookupResult()),
          ),
        ),
      ),
    );
    registerFallbackValue(
      Phase5Result(
        tags: const {},
        phase4: Phase4Result(
          tags: const {},
          phase1: _createTestPhase1Result(_createTestLookupResult()),
          phase2: Phase2Result(
            tags: const {},
            phase1: _createTestPhase1Result(_createTestLookupResult()),
          ),
          phase3: Phase3Result(
            tags: const {},
            phase1: _createTestPhase1Result(_createTestLookupResult()),
            phase2: Phase2Result(
              tags: const {},
              phase1: _createTestPhase1Result(_createTestLookupResult()),
            ),
          ),
        ),
      ),
    );
    registerFallbackValue(
      Phase5ResultPartial(
        tags: const {},
        phase1: _createTestPhase1Result(_createTestLookupResult()),
      ),
    );
  });

  setUp(() {
    mockLookupService = MockIngredientLookupService();
    mockTagGenerator = MockTagGenerator();
    mockUserIngredientRepo = MockUserIngredientRepository();

    // Default stub for initialize/dispose
    when(() => mockLookupService.initialize()).thenAnswer((_) async {});
    when(() => mockLookupService.dispose()).thenAnswer((_) async {});

    // BUT-1483: the runner resolves the config-backed phase pair once per run
    // via the generator; give the mock a valid (boot) pair by default.
    when(
      () => mockTagGenerator.resolveConfigPhases(),
    ).thenReturn((
      phase1: TagPhase1Base(),
      phase5: TagPhase5Cuisine(),
      configVersion: null,
    ));

    service = TaggingService(
      lookupService: mockLookupService,
      tagGenerator: mockTagGenerator,
      userIngredientRepository: mockUserIngredientRepo,
    );
  });

  group('TaggingService', () {
    group('H20: generateTags', () {
      test('returns TagResult for valid recipe', () async {
        // BUT-553: Service now delegates to TaggingPipelineRunner which
        // calls per-phase methods (runPhase1..5) on the generator instead
        // of `generate()`. The contract from the caller's view is
        // unchanged — non-null TagResult with tags from the pipeline.
        final recipe = RecipeBuilder().withTitle('Test Recipe').withIngredients(
          ['tomat', 'lök'],
        ).build();
        final lookupResult = _createTestLookupResult();
        final phase1Result = _createTestPhase1Result(lookupResult);
        final phase2Result = Phase2Result(
          tags: const {'p2'},
          phase1: phase1Result,
        );
        final phase3Result = Phase3Result(
          tags: const {'p3'},
          phase1: phase1Result,
          phase2: phase2Result,
        );
        final phase4Result = Phase4Result(
          tags: const {'p4'},
          phase1: phase1Result,
          phase2: phase2Result,
          phase3: phase3Result,
        );
        final phase5Result = Phase5Result(
          tags: const {'p5'},
          phase4: phase4Result,
        );
        final fakeAssemble = TagResult(
          tags: const {'p1', 'p2', 'p3', 'p4', 'p5'},
          allergenStatus: const {},
          dietaryStatus: const {},
          coverage: 1.0,
          unknownIngredients: const [],
          generatorVersion: kTagGeneratorVersion,
          generatedAt: DateTime.now(),
        );

        when(
          () => mockLookupService.lookupFromRaw(
            any(),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => lookupResult);
        when(
          () => mockTagGenerator.runPhase1(any(), any(), any()),
        ).thenReturn(phase1Result);
        when(
          () => mockTagGenerator.runPhase2(any(), any()),
        ).thenReturn(phase2Result);
        when(
          () => mockTagGenerator.runPhase3(any(), any(), any()),
        ).thenReturn(phase3Result);
        when(
          () => mockTagGenerator.runPhase4(any(), any(), any(), any()),
        ).thenReturn(phase4Result);
        when(
          () => mockTagGenerator.runPhase5(any(), any(), any()),
        ).thenReturn(phase5Result);
        when(
          () => mockTagGenerator.assembleResult(
            ingredients: any(named: 'ingredients'),
            recipe: any(named: 'recipe'),
            phase1Result: any(named: 'phase1Result'),
            phase2Result: any(named: 'phase2Result'),
            phase3Result: any(named: 'phase3Result'),
            phase4Result: any(named: 'phase4Result'),
            phase5Result: any(named: 'phase5Result'),
            phase5PartialResult: any(named: 'phase5PartialResult'),
            isPartial: any(named: 'isPartial'),
            configVersion: any(named: 'configVersion'),
          ),
        ).thenReturn(fakeAssemble);

        final result = await service.generateTags(recipe);

        expect(result, isNotNull);
        expect(result!.tags, isNotEmpty);
        verify(
          () => mockLookupService.lookupFromRaw(
            any(),
            userId: any(named: 'userId'),
          ),
        ).called(1);
        // Each phase invoked exactly once on the happy path.
        verify(() => mockTagGenerator.runPhase1(any(), any(), any())).called(1);
        verify(() => mockTagGenerator.runPhase5(any(), any(), any())).called(1);
      });

      test('returns empty TagResult for recipe with no ingredients', () async {
        final recipe = RecipeBuilder()
            .withTitle('Empty Recipe')
            .withIngredients([])
            .build();

        final result = await service.generateTags(recipe);

        expect(result, isNotNull);
        expect(result!.tags, isEmpty);
        // Lookup should not be called for empty ingredients
        verifyNever(
          () => mockLookupService.lookupFromRaw(
            any(),
            userId: any(named: 'userId'),
          ),
        );
      });

      test(
        'returns partial result with safe defaults on lookup timeout',
        () async {
          // BUT-553: Lookup floor case — when the lookup phase errors
          // (or times out), the runner returns a safe-defaults TagResult
          // with `timeout-warning` and skips all downstream phases.
          final recipe = RecipeBuilder()
              .withTitle('Timeout Recipe')
              .withIngredients(['tomat'])
              .build();

          when(
            () => mockLookupService.lookupFromRaw(
              any(),
              userId: any(named: 'userId'),
            ),
          ).thenAnswer((_) async {
            throw TimeoutException('Lookup timeout');
          });

          final result = await service.generateTags(recipe);

          expect(result, isNotNull);
          // CRIT-4: Lookup error returns partial result with visible indicator.
          // (BUT-553 changed the generatorVersion from 'lookup_timeout' to
          // 'lookup_<outcome>' — for a TimeoutException it's still
          // 'lookup_timeout'; for other errors it's 'lookup_error'.)
          expect(result!.tags, contains('timeout-warning'));
          expect(result.isPartial, isTrue);
          expect(result.generatorVersion, 'lookup_timeout');
          expect(result.coverage, 0.0);
          expect(result.unknownIngredients, ['tomat']);
          // No phases should run when lookup fails.
          verifyNever(() => mockTagGenerator.runPhase1(any(), any(), any()));
        },
      );
    });

    group('H20: lookupIngredients', () {
      test('delegates to lookupService', () async {
        final lookupResult = _createTestLookupResult();

        when(
          () => mockLookupService.lookupFromRaw(
            any(),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => lookupResult);

        final result = await service.lookupIngredients(['tomat', 'lök']);

        expect(result, isNotNull);
        expect(result!.matchedCount, 2);
        verify(
          () => mockLookupService.lookupFromRaw([
            'tomat',
            'lök',
          ], userId: any(named: 'userId')),
        ).called(1);
      });
    });

    group('H20: needsRetagging', () {
      test('returns true for recipe with no tagResult', () {
        final recipe = RecipeBuilder().withTitle('No Tags').withIngredients([
          'tomat',
        ]).build();

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
            .withIngredients(['tomat', 'unknown1', 'unknown2'])
            .build();
        final lookupResult = IngredientLookupResult.fromLists(
          matched: [_createTestIngredientData()],
          unmatched: ['unknown1', 'unknown2'],
        );

        when(
          () => mockLookupService.lookupFromRaw(
            any(),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => lookupResult);

        final result = await service.getUnknownIngredients(recipe);

        expect(result, hasLength(2));
        expect(result, contains('unknown1'));
        expect(result, contains('unknown2'));
      });

      test('returns empty list when all ingredients matched', () async {
        final recipe = RecipeBuilder().withTitle('Full Match').withIngredients([
          'tomat',
          'lök',
        ]).build();
        final lookupResult = _createTestLookupResult();

        when(
          () => mockLookupService.lookupFromRaw(
            any(),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => lookupResult);

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

Phase1Result _createTestPhase1Result(IngredientLookupResult lookup) {
  return Phase1Result(
    tags: const {'p1-test'},
    allergenStatus: const {},
    dietaryStatus: const {},
    lookup: lookup,
  );
}
