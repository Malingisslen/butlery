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
    when(() => mockIngredientRepository.getAll()).thenAnswer((_) async => []);
    // Each raw row looks up to the registry id of the same name.
    when(
      () => mockLookupService.lookupFromRaw(
        any(),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer(
      (inv) async => IngredientLookupResult(
        matched: [
          for (final raw in inv.positionalArguments[0] as List<String>)
            _ingredientData(raw, raw),
        ],
        unmatched: const [],
        coverage: 1.0,
      ),
    );

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
        _recipe(id: 'r1', title: 'Test', raw: ['chicken']),
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
          raw: ['chicken', 'rice'],
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
          raw: ['chicken', 'rice', 'onion', 'pepper'],
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
        _recipe(id: 'r1', title: 'Tofu', raw: ['tofu', 'soy-sauce']),
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
          raw: ['chicken', 'rice', 'onion', 'pepper'],
        ),
        _recipe(
          id: 'r2',
          title: 'High match',
          raw: ['chicken', 'rice'],
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

    test('matches on registry ids, not on the stored names', () async {
      // What the app stores: cleaned Swedish names in ingredientsNormalized,
      // while the selection holds registry ids. Comparing the two found
      // nothing for any recipe.
      final recipe = _recipe(
        id: 'r1',
        title: 'Fish & chips',
        normalized: ['potatis', 'citron'],
        raw: ['500 g potatis', '1 citron'],
      );
      when(
        () => mockLookupService.lookupFromRaw(
          ['500 g potatis', '1 citron'],
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => IngredientLookupResult(
          matched: [
            _ingredientData('potato', 'potatis'),
            _ingredientData('lemon', 'citron'),
          ],
          unmatched: const [],
          coverage: 1.0,
        ),
      );

      final results = await service.matchRecipes(
        selectedIngredientIds: {'potato'},
        recipes: [recipe],
      );

      expect(results, hasLength(1));
      expect(results.first.matchPercent, 0.5);
      expect(results.first.missingIngredientIds, ['lemon']);
    });

    test('recipes without ingredients are skipped', () async {
      final recipes = [
        _recipe(id: 'r1', title: 'Empty', raw: const []),
        _recipe(id: 'r2', title: 'Modern', raw: ['chicken']),
      ];

      final results = await service.matchRecipes(
        selectedIngredientIds: {'chicken'},
        recipes: recipes,
      );

      expect(results, hasLength(1));
      expect(results.first.recipe.id, 'r2');
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

      when(
        () => mockLookupService.lookupFromRaw(
          ['2 dl mjölk', '500g kycklingfilé'],
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => IngredientLookupResult(
          matched: [
            _ingredientData('milk', 'mjölk'),
            _ingredientData('chicken-breast', 'kycklingfilé'),
          ],
          unmatched: const [],
          coverage: 1.0,
        ),
      );

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

      when(
        () => mockLookupService.lookupFromRaw(
          ['ägg'],
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => IngredientLookupResult(
          matched: [_ingredientData('egg', 'ägg')],
          unmatched: const [],
          coverage: 1.0,
        ),
      );

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
      verify(
        () => mockLookupService.lookupFromRaw(
          ['ägg'],
          userId: any(named: 'userId'),
        ),
      ).called(1);
    });
  });

  group('a selected ingredient finds its specific forms', () {
    IngredientData entry(String id, String swedish, String group) =>
        IngredientData(
          id: id,
          swedish: swedish,
          english: id,
          group: group,
          properties: const {},
        );

    setUp(() {
      when(() => mockIngredientRepository.getAll()).thenAnswer(
        (_) async => [
          entry('chicken', 'kyckling', 'protein/meat/poultry'),
          entry('chicken-breast', 'kycklingfilé', 'protein/meat/poultry'),
          entry('chicken-whole', 'hel kyckling', 'protein/meat/poultry'),
          entry('turkey-breast', 'kalkonfilé', 'protein/meat/poultry'),
          entry('chicken-broth', 'kycklingbuljong', 'other/beverage'),
          entry('potato', 'potatis', 'vegetable/root'),
          entry('sweet-potato', 'sötpotatis', 'vegetable/root'),
          entry('cream', 'grädde', 'dairy/cream'),
        ],
      );
    });

    Future<List<IngredientMatchResult>> search(
      Set<String> selected,
      List<String> recipeIds,
    ) => service.matchRecipesWithNormalization(
      selectedIngredientIds: selected,
      recipes: [_recipe(id: 'r', title: 'R', raw: recipeIds)],
    );

    test('"kyckling" finds a recipe with kycklingfilé', () async {
      final results = await search({'chicken'}, ['chicken-breast', 'cream']);

      expect(results, hasLength(1));
      expect(results.single.matchedCount, 1);
      expect(results.single.missingIngredientIds, ['cream']);
    });

    test(
      '"kyckling" finds "hel kyckling", where the word is not first',
      () async {
        expect(await search({'chicken'}, ['chicken-whole']), hasLength(1));
      },
    );

    test('"kyckling" does not find kalkon in the same group', () async {
      expect(await search({'chicken'}, ['turkey-breast']), isEmpty);
    });

    test('"kyckling" does not find kycklingbuljong in another group', () async {
      expect(await search({'chicken'}, ['chicken-broth']), isEmpty);
    });

    test('"potatis" does not find sötpotatis', () async {
      expect(await search({'potato'}, ['sweet-potato']), isEmpty);
    });

    test(
      'the pantry match stays exact: kyckling is not kycklingfilé',
      () async {
        final results = await service.matchRecipes(
          selectedIngredientIds: {'chicken'},
          recipes: [
            _recipe(id: 'r', title: 'R', raw: ['chicken-breast']),
          ],
        );

        expect(results, isEmpty);
      },
    );

    test('an unreadable registry falls back to the exact match', () async {
      when(
        () => mockIngredientRepository.getAll(),
      ).thenThrow(Exception('offline'));

      expect(await search({'chicken'}, ['chicken-breast']), isEmpty);
      expect(await search({'chicken'}, ['chicken']), hasLength(1));
    });
  });

  group('resolveIngredientNames', () {
    test('returns Swedish display names for ingredient IDs', () async {
      when(() => mockIngredientRepository.getById('chicken-breast')).thenAnswer(
        (_) async => _ingredientData('chicken-breast', 'kycklingfilé'),
      );
      when(
        () => mockIngredientRepository.getById('rice'),
      ).thenAnswer((_) async => _ingredientData('rice', 'ris'));

      final names = await service.resolveIngredientNames([
        'chicken-breast',
        'rice',
      ]);

      expect(names, {'chicken-breast': 'kycklingfilé', 'rice': 'ris'});
    });

    test('resolves English name via findByName fallback', () async {
      when(
        () => mockIngredientRepository.getById('chicken breast'),
      ).thenAnswer((_) async => null);
      when(
        () => mockIngredientRepository.findByName(
          'chicken breast',
          language: 'en',
        ),
      ).thenAnswer(
        (_) async => _ingredientData('chicken-breast', 'kycklingbröst'),
      );

      final names = await service.resolveIngredientNames(['chicken breast']);

      expect(names, {'chicken breast': 'kycklingbröst'});
    });

    test('falls back to cleaned ID when no lookup matches', () async {
      when(
        () => mockIngredientRepository.getById('unknown-thing'),
      ).thenAnswer((_) async => null);
      when(
        () => mockIngredientRepository.findByName(
          'unknown-thing',
          language: 'en',
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockIngredientRepository.findByName('unknown-thing'),
      ).thenAnswer((_) async => null);

      final names = await service.resolveIngredientNames(['unknown-thing']);

      expect(names, {'unknown-thing': 'unknown thing'});
    });
  });
}
