import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/ingredient_match_service.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

class MockIngredientRepository extends Mock implements IngredientRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockIngredientMatchService extends Mock
    implements IngredientMatchService {}

// Minimal PantryItem fallback for mocktail argument matchers.
PantryItem _fallbackPantryItem() => PantryItem(
      id: 'fallback',
      ingredientName: 'fallback',
      quantity: 1,
      unit: 'st',
      location: PantryLocation.pantry,
      addedAt: DateTime.utc(2026, 1, 1),
    );

IngredientData _ingredient({
  required String id,
  required String swedish,
  String? typicalUnit,
  String? typicalStorage,
}) =>
    IngredientData(
      id: id,
      swedish: swedish,
      english: swedish,
      group: 'other',
      properties: const {},
      typicalUnit: typicalUnit,
      typicalStorage: typicalStorage,
    );

Recipe _recipeWithNormalizedIngredients({
  required String id,
  required String title,
  required List<String> normalized,
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: 'Test description',
      ingredients: const ['ingredient'],
      instructions: const ['step'],
      mealType: 'Middag',
      ingredientsNormalized: normalized,
    ),
    type: RecipeType.personal,
  );
}

PantryItem _pantryItem({
  required String id,
  String? ingredientId,
  String ingredientName = 'Test',
  DateTime? expiryDate,
}) =>
    PantryItem(
      id: id,
      ingredientId: ingredientId,
      ingredientName: ingredientName,
      quantity: 1,
      unit: 'st',
      location: PantryLocation.pantry,
      addedAt: DateTime.utc(2026, 1, 1),
      expiryDate: expiryDate,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PantryService service;
  late MockPantryRepository mockPantryRepository;
  late MockIngredientRepository mockIngredientRepository;
  late MockAuthRepository mockAuthRepository;
  late MockIngredientMatchService mockMatchService;

  const userId = 'test-user-123';

  setUpAll(() {
    registerFallbackValue(_fallbackPantryItem());
  });

  setUp(() async {
    mockPantryRepository = MockPantryRepository();
    mockIngredientRepository = MockIngredientRepository();
    mockAuthRepository = MockAuthRepository();
    mockMatchService = MockIngredientMatchService();

    // BaseService.executeServiceOperation performs an auth pre-flight
    // via ServiceLocator.get<AuthRepository>(). We route GetIt through
    // the production ServiceLocator bridge so that check passes.
    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(mockAuthRepository);
    ServiceLocator.initialize(DIContainer());

    when(() => mockAuthRepository.currentUserId).thenReturn(userId);

    // Stub matchRecipes to delegate correctly — by default return
    // results computed from the actual set intersection so existing
    // tests keep verifying PantryService end-to-end behavior.
    when(() => mockMatchService.matchRecipes(
          selectedIngredientIds: any(named: 'selectedIngredientIds'),
          recipes: any(named: 'recipes'),
        )).thenAnswer((invocation) async {
      final selectedIds =
          invocation.namedArguments[#selectedIngredientIds] as Set<String>;
      final recipes = invocation.namedArguments[#recipes] as List<Recipe>;
      final matches = <IngredientMatchResult>[];
      for (final recipe in recipes) {
        final normalized = recipe.core.ingredientsNormalized;
        if (normalized == null || normalized.isEmpty) continue;
        final normalizedSet = normalized.toSet();
        final overlap = normalizedSet.intersection(selectedIds).length;
        if (overlap == 0) continue;
        matches.add(IngredientMatchResult(
          recipe: recipe,
          matchPercent: overlap / normalizedSet.length,
          matchedCount: overlap,
          totalCount: normalizedSet.length,
          missingIngredientIds: normalizedSet.difference(selectedIds).toList(),
        ));
      }
      matches.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
      return matches;
    });

    service = PantryService(
      pantryRepository: mockPantryRepository,
      ingredientRepository: mockIngredientRepository,
      matchService: mockMatchService,
    );
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('PantryService.getMatchingRecipes', () {
    test(
        'should return recipe with 75% match when pantry covers 3 of 4 ingredients',
        () async {
      // Arrange: pantry has 3 taxonomy-linked items, recipe needs 4.
      final pantryItems = [
        _pantryItem(id: 'p1', ingredientId: 'chicken-breast'),
        _pantryItem(id: 'p2', ingredientId: 'rice'),
        _pantryItem(id: 'p3', ingredientId: 'onion'),
      ];
      when(() => mockPantryRepository.getAll(userId))
          .thenAnswer((_) async => pantryItems);

      final recipe = _recipeWithNormalizedIngredients(
        id: 'r1',
        title: 'Chicken Rice Bowl',
        normalized: const ['chicken-breast', 'rice', 'onion', 'bell-pepper'],
      );

      // Act
      final result = await service.getMatchingRecipes(userId, [recipe]);

      // Assert
      expect(result, hasLength(1));
      expect(result.first.recipe.core.id, 'r1');
      expect(result.first.matchPercent, closeTo(0.75, 1e-9));
    });

    test('should exclude recipes with zero ingredient overlap from the result',
        () async {
      // Arrange: pantry has chicken, recipe is a tofu dish — no overlap.
      final pantryItems = [
        _pantryItem(id: 'p1', ingredientId: 'chicken-breast'),
      ];
      when(() => mockPantryRepository.getAll(userId))
          .thenAnswer((_) async => pantryItems);

      final recipe = _recipeWithNormalizedIngredients(
        id: 'r-tofu',
        title: 'Tofu Stir Fry',
        normalized: const ['tofu', 'soy-sauce', 'ginger'],
      );

      // Act
      final result = await service.getMatchingRecipes(userId, [recipe]);

      // Assert: recipe dropped entirely, not returned with 0% match.
      expect(result, isEmpty);
    });
  });

  group('PantryService.addFromText', () {
    test('should link to taxonomy ingredient when fuzzy search finds a match',
        () async {
      // Arrange: ingredient lookup returns a canonical match.
      final match = _ingredient(
        id: 'chicken-breast',
        swedish: 'Kycklingfilé',
        typicalUnit: 'g',
        typicalStorage: 'refrigerated',
      );
      when(() => mockIngredientRepository.searchIngredients(
            'kycklingfilé',
            limit: 1,
          )).thenAnswer((_) async => [match]);
      when(() => mockPantryRepository.add(userId, any()))
          .thenAnswer((_) async => 'new-item-id');

      // Act
      await service.addFromText(
        userId,
        'kycklingfilé',
        quantity: 500,
        unit: 'g',
      );

      // Assert: repository received an item linked to the taxonomy match.
      final captured =
          verify(() => mockPantryRepository.add(userId, captureAny()))
              .captured
              .single as PantryItem;
      expect(captured.ingredientId, 'chicken-breast');
      expect(captured.ingredientName, 'Kycklingfilé');
      expect(captured.quantity, 500);
      expect(captured.unit, 'g');
    });

    test(
        'should create an orphan item with null ingredientId when no taxonomy match is found',
        () async {
      // Arrange: search returns nothing.
      when(() => mockIngredientRepository.searchIngredients(
            'XYZABC123',
            limit: 1,
          )).thenAnswer((_) async => const []);
      when(() => mockPantryRepository.add(userId, any()))
          .thenAnswer((_) async => 'new-item-id');

      // Act
      await service.addFromText(userId, 'XYZABC123');

      // Assert: item was stored with the raw text, no taxonomy link.
      final captured =
          verify(() => mockPantryRepository.add(userId, captureAny()))
              .captured
              .single as PantryItem;
      expect(captured.ingredientId, isNull);
      expect(captured.ingredientName, 'XYZABC123');
    });
  });

  group('PantryService.getExpiringSoon', () {
    test('should return only items expiring within the window, ordered by date',
        () async {
      // Arrange: the repository filters by expiry cutoff, so we stub it
      // to return the items that would survive the query — day+1 and day+2
      // sorted ascending. day+5 and undated items never reach the service.
      final today = DateTime.now();
      DateTime day(int offset) => today.add(Duration(days: offset));

      final day1 = _pantryItem(
        id: 'd1',
        ingredientName: 'Milk',
        expiryDate: day(1),
      );
      final day2 = _pantryItem(
        id: 'd2',
        ingredientName: 'Yogurt',
        expiryDate: day(2),
      );

      when(() => mockPantryRepository.getExpiringSoon(userId, 3))
          .thenAnswer((_) async => [day1, day2]);

      // Act
      final result = await service.getExpiringSoon(userId, days: 3);

      // Assert: only the in-window items, in ascending expiry order.
      expect(result.map((i) => i.id).toList(), ['d1', 'd2']);
      verify(() => mockPantryRepository.getExpiringSoon(userId, 3)).called(1);
    });
  });
}
