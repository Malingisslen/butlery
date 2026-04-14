import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/ingredient_match_service.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

class MockIngredientLookupService extends Mock
    implements IngredientLookupService {}

class MockIngredientRepository extends Mock implements IngredientRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

Recipe _recipe({
  required String id,
  required String title,
  List<String>? normalized,
  List<String> raw = const ['ingredient'],
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: '',
      ingredients: raw,
      instructions: const ['step'],
      mealType: 'Middag',
      ingredientsNormalized: normalized,
    ),
    type: RecipeType.personal,
  );
}

IngredientData _ingredientData(String id, String swedish) => IngredientData(
      id: id,
      swedish: swedish,
      english: swedish,
      group: 'other',
      properties: const {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IngredientMatchService service;
  late MockIngredientLookupService mockLookupService;
  late MockIngredientRepository mockIngredientRepository;
  late MockAuthRepository mockAuthRepository;

  setUp(() async {
    mockLookupService = MockIngredientLookupService();
    mockIngredientRepository = MockIngredientRepository();
    mockAuthRepository = MockAuthRepository();

    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(mockAuthRepository);
    ServiceLocator.initialize(DIContainer());

    when(() => mockAuthRepository.currentUserId).thenReturn('test-user');

    service = IngredientMatchService(
      lookupService: mockLookupService,
      ingredientRepository: mockIngredientRepository,
    );
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('matchRecipes', () {
    test('empty ingredient set returns empty results', () async {
      final recipes = [
        _recipe(id: 'r1', title: 'Test', normalized: ['chicken']),
      ];

      final results = await service.matchRecipes(
        selectedIngredientIds: {},
        recipes: recipes,
      );

      expect(results, isEmpty);
    });

    test('full match returns 100%', () async {
      final recipes = [
        _recipe(
          id: 'r1',
          title: 'Simple',
          normalized: ['chicken', 'rice'],
        ),
      ];

      final results = await service.matchRecipes(
        selectedIngredientIds: {'chicken', 'rice'},
        recipes: recipes,
      );

      expect(results, hasLength(1));
      expect(results.first.matchPercent, 1.0);
      expect(results.first.matchedCount, 2);
      expect(results.first.totalCount, 2);
      expect(results.first.missingIngredientIds, isEmpty);
    });

    test('partial match calculates correct percentage', () async {
      final recipes = [
        _recipe(
          id: 'r1',
          title: 'Bowl',
          normalized: ['chicken', 'rice', 'onion', 'pepper'],
        ),
      ];

      final results = await service.matchRecipes(
        selectedIngredientIds: {'chicken', 'rice', 'onion'},
        recipes: recipes,
      );

      expect(results, hasLength(1));
      expect(results.first.matchPercent, closeTo(0.75, 1e-9));
      expect(results.first.matchedCount, 3);
      expect(results.first.totalCount, 4);
      expect(results.first.missingIngredientIds, ['pepper']);
    });

    test('zero-overlap recipes are excluded', () async {
      final recipes = [
        _recipe(id: 'r1', title: 'Tofu', normalized: ['tofu', 'soy-sauce']),
      ];

      final results = await service.matchRecipes(
        selectedIngredientIds: {'chicken', 'rice'},
        recipes: recipes,
      );

      expect(results, isEmpty);
    });

    test('results are sorted by match% descending', () async {
      final recipes = [
        _recipe(
          id: 'r1',
          title: 'Low match',
          normalized: ['chicken', 'rice', 'onion', 'pepper'],
        ),
        _recipe(
          id: 'r2',
          title: 'High match',
          normalized: ['chicken', 'rice'],
        ),
      ];

      final results = await service.matchRecipes(
        selectedIngredientIds: {'chicken', 'rice'},
        recipes: recipes,
      );

      expect(results, hasLength(2));
      expect(results[0].recipe.core.id, 'r2'); // 100%
      expect(results[1].recipe.core.id, 'r1'); // 50%
    });

    test('recipes with null ingredientsNormalized are skipped', () async {
      final recipes = [
        _recipe(id: 'r1', title: 'Legacy', normalized: null),
        _recipe(id: 'r2', title: 'Modern', normalized: ['chicken']),
      ];

      final results = await service.matchRecipes(
        selectedIngredientIds: {'chicken'},
        recipes: recipes,
      );

      expect(results, hasLength(1));
      expect(results.first.recipe.core.id, 'r2');
    });

    test('recipes with empty ingredientsNormalized are skipped', () async {
      final recipes = [
        _recipe(id: 'r1', title: 'Empty', normalized: []),
      ];

      final results = await service.matchRecipes(
        selectedIngredientIds: {'chicken'},
        recipes: recipes,
      );

      expect(results, isEmpty);
    });
  });

  group('matchRecipesWithNormalization', () {
    test('normalizes legacy recipes via lookupFromRaw', () async {
      final recipes = [
        _recipe(
          id: 'r-legacy',
          title: 'Legacy',
          normalized: null,
          raw: ['2 dl mjölk', '500g kycklingfilé'],
        ),
      ];

      when(() => mockLookupService.lookupFromRaw(
            ['2 dl mjölk', '500g kycklingfilé'],
            userId: any(named: 'userId'),
          )).thenAnswer((_) async => IngredientLookupResult(
            matched: [
              _ingredientData('milk', 'mjölk'),
              _ingredientData('chicken-breast', 'kycklingfilé'),
            ],
            unmatched: const [],
            coverage: 1.0,
          ));

      final results = await service.matchRecipesWithNormalization(
        selectedIngredientIds: {'milk', 'chicken-breast'},
        recipes: recipes,
      );

      expect(results, hasLength(1));
      expect(results.first.matchPercent, 1.0);
    });

    test('caches normalization results across calls', () async {
      final recipe = _recipe(
        id: 'r-cached',
        title: 'Cached',
        normalized: null,
        raw: ['ägg'],
      );

      when(() => mockLookupService.lookupFromRaw(
            ['ägg'],
            userId: any(named: 'userId'),
          )).thenAnswer((_) async => IngredientLookupResult(
            matched: [_ingredientData('egg', 'ägg')],
            unmatched: const [],
            coverage: 1.0,
          ));

      // First call — triggers normalization
      await service.matchRecipesWithNormalization(
        selectedIngredientIds: {'egg'},
        recipes: [recipe],
      );

      // Second call — uses cache
      await service.matchRecipesWithNormalization(
        selectedIngredientIds: {'egg'},
        recipes: [recipe],
      );

      // lookupFromRaw should only be called once (cached on second call)
      verify(() => mockLookupService.lookupFromRaw(
            ['ägg'],
            userId: any(named: 'userId'),
          )).called(1);
    });
  });

  group('resolveIngredientNames', () {
    test('returns Swedish display names for ingredient IDs', () async {
      when(() => mockIngredientRepository.getById('chicken-breast')).thenAnswer(
          (_) async => _ingredientData('chicken-breast', 'kycklingfilé'));
      when(() => mockIngredientRepository.getById('rice'))
          .thenAnswer((_) async => _ingredientData('rice', 'ris'));

      final names =
          await service.resolveIngredientNames(['chicken-breast', 'rice']);

      expect(names, {'chicken-breast': 'kycklingfilé', 'rice': 'ris'});
    });

    test('resolves English name via findByName fallback', () async {
      when(() => mockIngredientRepository.getById('chicken breast'))
          .thenAnswer((_) async => null);
      when(() => mockIngredientRepository.findByName('chicken breast',
              language: 'en'))
          .thenAnswer(
              (_) async => _ingredientData('chicken-breast', 'kycklingbröst'));

      final names = await service.resolveIngredientNames(['chicken breast']);

      expect(names, {'chicken breast': 'kycklingbröst'});
    });

    test('falls back to cleaned ID when no lookup matches', () async {
      when(() => mockIngredientRepository.getById('unknown-thing'))
          .thenAnswer((_) async => null);
      when(() => mockIngredientRepository.findByName('unknown-thing',
          language: 'en')).thenAnswer((_) async => null);
      when(() => mockIngredientRepository.findByName('unknown-thing'))
          .thenAnswer((_) async => null);

      final names = await service.resolveIngredientNames(['unknown-thing']);

      expect(names, {'unknown-thing': 'unknown thing'});
    });
  });
}
