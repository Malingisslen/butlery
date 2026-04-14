import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/ingredient_match_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/ingredient_search_viewmodel.dart';

class MockIngredientMatchService extends Mock
    implements IngredientMatchService {}

class MockIngredientRepository extends Mock implements IngredientRepository {}

class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class MockAuthRepository extends Mock implements AuthRepository {}

IngredientData _ingredient(String id, String swedish) => IngredientData(
      id: id,
      swedish: swedish,
      english: swedish,
      group: 'other',
      properties: const {},
    );

Recipe _recipe(String id, String title) => Recipe(
      core: RecipeCore(
        id: id,
        title: title,
        description: '',
        ingredients: const ['test'],
        instructions: const ['step'],
        mealType: 'Middag',
        ingredientsNormalized: ['ingredient-$id'],
      ),
      type: RecipeType.personal,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IngredientSearchViewModel vm;
  late MockIngredientMatchService mockMatchService;
  late MockIngredientRepository mockIngredientRepo;
  late MockUnifiedRecipeService mockRecipeService;
  late MockAuthRepository mockAuthRepo;

  setUp(() async {
    mockMatchService = MockIngredientMatchService();
    mockIngredientRepo = MockIngredientRepository();
    mockRecipeService = MockUnifiedRecipeService();
    mockAuthRepo = MockAuthRepository();

    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(mockAuthRepo);
    ServiceLocator.initialize(DIContainer());

    when(() => mockAuthRepo.currentUserId).thenReturn('test-user');
    when(() => mockRecipeService.recipes).thenReturn([_recipe('r1', 'Test')]);

    vm = IngredientSearchViewModel(
      matchService: mockMatchService,
      ingredientRepository: mockIngredientRepo,
      recipeService: mockRecipeService,
    );
  });

  tearDown(() async {
    vm.dispose();
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('ingredient selection', () {
    test('addIngredient adds to selectedIngredients', () {
      final chicken = _ingredient('chicken', 'kyckling');
      vm.addIngredient(chicken);

      expect(vm.selectedIngredients, hasLength(1));
      expect(vm.selectedIngredients.first.id, 'chicken');
    });

    test('addIngredient ignores duplicates', () {
      final chicken = _ingredient('chicken', 'kyckling');
      vm.addIngredient(chicken);
      vm.addIngredient(chicken);

      expect(vm.selectedIngredients, hasLength(1));
    });

    test('removeIngredient removes by ID', () {
      vm.addIngredient(_ingredient('chicken', 'kyckling'));
      vm.addIngredient(_ingredient('rice', 'ris'));
      vm.removeIngredient('chicken');

      expect(vm.selectedIngredients, hasLength(1));
      expect(vm.selectedIngredients.first.id, 'rice');
    });

    test('clearIngredients resets all state', () async {
      vm.addIngredient(_ingredient('chicken', 'kyckling'));

      when(() => mockMatchService.matchRecipesWithNormalization(
            selectedIngredientIds: any(named: 'selectedIngredientIds'),
            recipes: any(named: 'recipes'),
          )).thenAnswer((_) async => [
            IngredientMatchResult(
              recipe: _recipe('r1', 'Test'),
              matchPercent: 1.0,
              matchedCount: 1,
              totalCount: 1,
              missingIngredientIds: const [],
            ),
          ]);
      when(() => mockMatchService.resolveIngredientNames(any()))
          .thenAnswer((_) async => {});

      await vm.performSearch();
      vm.clearIngredients();

      expect(vm.selectedIngredients, isEmpty);
      expect(vm.matchResults, isEmpty);
      expect(vm.hasSearched, false);
    });
  });

  group('autocomplete', () {
    test('debounced search fires after 300ms', () {
      fakeAsync((async) {
        when(() => mockIngredientRepo.searchIngredients('kyck', limit: 10))
            .thenAnswer((_) async => [_ingredient('chicken', 'kyckling')]);

        vm.searchIngredient('kyck');
        expect(vm.autocompleteResults, isEmpty);

        async.elapse(const Duration(milliseconds: 300));

        expect(vm.autocompleteResults, hasLength(1));
        expect(vm.autocompleteResults.first.id, 'chicken');
      });
    });

    test('already-selected ingredients are filtered from results', () {
      fakeAsync((async) {
        vm.addIngredient(_ingredient('chicken', 'kyckling'));

        when(() => mockIngredientRepo.searchIngredients('k', limit: 10))
            .thenAnswer((_) async => [
                  _ingredient('chicken', 'kyckling'),
                  _ingredient('cinnamon', 'kanel'),
                ]);

        vm.searchIngredient('k');
        async.elapse(const Duration(milliseconds: 300));

        expect(vm.autocompleteResults, hasLength(1));
        expect(vm.autocompleteResults.first.id, 'cinnamon');
      });
    });

    test('empty query clears autocomplete results immediately', () {
      fakeAsync((async) {
        when(() => mockIngredientRepo.searchIngredients('k', limit: 10))
            .thenAnswer((_) async => [_ingredient('cinnamon', 'kanel')]);

        vm.searchIngredient('k');
        async.elapse(const Duration(milliseconds: 300));
        expect(vm.autocompleteResults, hasLength(1));

        vm.searchIngredient('');
        // No elapse needed — clears synchronously
        expect(vm.autocompleteResults, isEmpty);
      });
    });
  });

  group('performSearch', () {
    test('calls matchService with selected ingredient IDs', () async {
      vm.addIngredient(_ingredient('chicken', 'kyckling'));
      vm.addIngredient(_ingredient('rice', 'ris'));

      when(() => mockMatchService.matchRecipesWithNormalization(
            selectedIngredientIds: {'chicken', 'rice'},
            recipes: any(named: 'recipes'),
          )).thenAnswer((_) async => []);
      when(() => mockMatchService.resolveIngredientNames(any()))
          .thenAnswer((_) async => {});

      await vm.performSearch();

      verify(() => mockMatchService.matchRecipesWithNormalization(
            selectedIngredientIds: {'chicken', 'rice'},
            recipes: any(named: 'recipes'),
          )).called(1);
      expect(vm.hasSearched, true);
    });

    test('does nothing when no ingredients selected', () async {
      await vm.performSearch();

      verifyNever(() => mockMatchService.matchRecipesWithNormalization(
            selectedIngredientIds: any(named: 'selectedIngredientIds'),
            recipes: any(named: 'recipes'),
          ));
      expect(vm.hasSearched, false);
    });

    test('exposes match results sorted by service', () async {
      vm.addIngredient(_ingredient('chicken', 'kyckling'));

      final expectedResults = [
        IngredientMatchResult(
          recipe: _recipe('r1', 'Test'),
          matchPercent: 0.75,
          matchedCount: 3,
          totalCount: 4,
          missingIngredientIds: const ['pepper'],
        ),
      ];

      when(() => mockMatchService.matchRecipesWithNormalization(
            selectedIngredientIds: any(named: 'selectedIngredientIds'),
            recipes: any(named: 'recipes'),
          )).thenAnswer((_) async => expectedResults);
      when(() => mockMatchService.resolveIngredientNames(['pepper']))
          .thenAnswer((_) async => {'pepper': 'peppar'});

      await vm.performSearch();

      expect(vm.matchResults, hasLength(1));
      expect(vm.matchResults.first.matchPercent, 0.75);
      expect(vm.ingredientName('pepper'), 'peppar');
    });
  });
}
