import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
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
  List<String> aliasesSv = const [],
}) => IngredientData(
  id: id,
  swedish: swedish,
  english: swedish,
  group: 'other',
  properties: const {},
  typicalUnit: typicalUnit,
  typicalStorage: typicalStorage,
  aliasesSv: aliasesSv,
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
}) => PantryItem(
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
    when(
      () => mockMatchService.matchRecipes(
        selectedIngredientIds: any(named: 'selectedIngredientIds'),
        recipes: any(named: 'recipes'),
      ),
    ).thenAnswer((invocation) async {
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
        matches.add(
          IngredientMatchResult(
            recipe: recipe,
            matchPercent: overlap / normalizedSet.length,
            matchedCount: overlap,
            totalCount: normalizedSet.length,
            missingIngredientIds: normalizedSet
                .difference(selectedIds)
                .toList(),
          ),
        );
      }
      matches.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
      return matches;
    });

    when(
      () => mockMatchService.keysForNames(any()),
    ).thenAnswer((_) async => const {});

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
        when(
          () => mockPantryRepository.getAll(userId),
        ).thenAnswer((_) async => pantryItems);

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
      },
    );

    test('a pantry row typed by hand, with no registry link, still counts '
        '(k10)', () async {
      final pantryItems = [
        _pantryItem(id: 'p1', ingredientName: 'Lök'),
        _pantryItem(id: 'p2', ingredientId: 'rice'),
      ];
      when(
        () => mockPantryRepository.getAll(userId),
      ).thenAnswer((_) async => pantryItems);
      when(
        () => mockMatchService.keysForNames(['Lök']),
      ).thenAnswer((_) async => {'onion'});

      final recipe = _recipeWithNormalizedIngredients(
        id: 'r1',
        title: 'Lökris',
        normalized: const ['onion', 'rice', 'butter', 'salt'],
      );

      final result = await service.getMatchingRecipes(userId, [recipe]);

      expect(result, hasLength(1));
      expect(result.first.matchPercent, closeTo(0.5, 1e-9));
    });

    test(
      'should exclude recipes with zero ingredient overlap from the result',
      () async {
        // Arrange: pantry has chicken, recipe is a tofu dish — no overlap.
        final pantryItems = [
          _pantryItem(id: 'p1', ingredientId: 'chicken-breast'),
        ];
        when(
          () => mockPantryRepository.getAll(userId),
        ).thenAnswer((_) async => pantryItems);

        final recipe = _recipeWithNormalizedIngredients(
          id: 'r-tofu',
          title: 'Tofu Stir Fry',
          normalized: const ['tofu', 'soy-sauce', 'ginger'],
        );

        // Act
        final result = await service.getMatchingRecipes(userId, [recipe]);

        // Assert: recipe dropped entirely, not returned with 0% match.
        expect(result, isEmpty);
      },
    );
  });

  group('PantryService.addFromText', () {
    test(
      'should link to taxonomy ingredient when fuzzy search finds a match',
      () async {
        // Arrange: ingredient lookup returns a canonical match.
        final match = _ingredient(
          id: 'chicken-breast',
          swedish: 'Kycklingfilé',
          typicalUnit: 'g',
          typicalStorage: 'refrigerated',
        );
        when(
          () => mockIngredientRepository.searchIngredients(
            'kycklingfilé',
            limit: 1,
          ),
        ).thenAnswer((_) async => [match]);
        when(
          () => mockPantryRepository.add(userId, any()),
        ).thenAnswer((_) async => 'new-item-id');

        // Act
        await service.addFromText(
          userId,
          'kycklingfilé',
          quantity: 500,
          unit: 'g',
        );

        // Assert: repository received an item linked to the taxonomy match.
        final captured =
            verify(
                  () => mockPantryRepository.add(userId, captureAny()),
                ).captured.single
                as PantryItem;
        expect(captured.ingredientId, 'chicken-breast');
        expect(captured.ingredientName, 'Kycklingfilé');
        expect(captured.quantity, 500);
        expect(captured.unit, 'g');
      },
    );

    test(
      'should create an orphan item with null ingredientId when no taxonomy match is found',
      () async {
        // Arrange: search returns nothing.
        when(
          () => mockIngredientRepository.searchIngredients(
            'XYZABC123',
            limit: 1,
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => mockPantryRepository.add(userId, any()),
        ).thenAnswer((_) async => 'new-item-id');

        // Act
        await service.addFromText(userId, 'XYZABC123');

        // Assert: item was stored with the raw text, no taxonomy link.
        final captured =
            verify(
                  () => mockPantryRepository.add(userId, captureAny()),
                ).captured.single
                as PantryItem;
        expect(captured.ingredientId, isNull);
        expect(captured.ingredientName, 'XYZABC123');
        expect(captured.quantity, 1);
      },
    );

    test('an explicit null quantity is stored as no quantity, not 1', () async {
      when(
        () => mockIngredientRepository.searchIngredients(
          'XYZABC123',
          limit: 1,
        ),
      ).thenAnswer((_) async => const []);
      when(
        () => mockPantryRepository.add(userId, any()),
      ).thenAnswer((_) async => 'new-item-id');

      await service.addFromText(userId, 'XYZABC123', quantity: null);

      final captured =
          verify(
                () => mockPantryRepository.add(userId, captureAny()),
              ).captured.single
              as PantryItem;
      expect(captured.quantity, isNull);
    });

    test(
      'a shopping row bought without an amount is added as "har hemma"',
      () async {
        when(
          () => mockIngredientRepository.searchIngredients(
            'XYZABC123',
            limit: 1,
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => mockPantryRepository.add(userId, any()),
        ).thenAnswer((_) async => 'new-item-id');

        await service.addFromShoppingItem(
          userId,
          UnifiedShoppingItem(name: 'XYZABC123', amount: 0, unit: ''),
        );

        final captured =
            verify(
                  () => mockPantryRepository.add(userId, captureAny()),
                ).captured.single
                as PantryItem;
        expect(captured.quantity, isNull);
      },
    );

    test('a search hit that is another product is not linked and lends '
        'nothing (typed "mjöl", hit "Mjölk")', () async {
      when(
        () => mockIngredientRepository.searchIngredients('mjöl', limit: 1),
      ).thenAnswer(
        (_) async => [
          _ingredient(
            id: 'milk',
            swedish: 'Mjölk',
            typicalUnit: 'l',
            typicalStorage: 'refrigerated',
          ),
        ],
      );
      when(
        () => mockPantryRepository.add(userId, any()),
      ).thenAnswer((_) async => 'new-item-id');

      await service.addFromText(userId, 'mjöl');

      final captured =
          verify(
                () => mockPantryRepository.add(userId, captureAny()),
              ).captured.single
              as PantryItem;
      expect(captured.ingredientName, 'mjöl');
      expect(captured.ingredientId, isNull);
      expect(captured.unit, isNot('l'));
    });

    test('a search hit that lists the typed word as an alias is linked and '
        'named by the registry', () async {
      when(
        () =>
            mockIngredientRepository.searchIngredients('florsocker', limit: 1),
      ).thenAnswer(
        (_) async => [
          _ingredient(
            id: 'icing-sugar',
            swedish: 'Pudersocker',
            aliasesSv: const ['florsocker'],
          ),
        ],
      );
      when(
        () => mockPantryRepository.add(userId, any()),
      ).thenAnswer((_) async => 'new-item-id');

      await service.addFromText(userId, 'florsocker');

      final captured =
          verify(
                () => mockPantryRepository.add(userId, captureAny()),
              ).captured.single
              as PantryItem;
      expect(captured.ingredientId, 'icing-sugar');
      expect(captured.ingredientName, 'Pudersocker');
    });
  });

  group('PantryService.addFromIngredient', () {
    final salt = _ingredient(id: 'salt', swedish: 'Salt');

    setUp(() {
      when(
        () => mockPantryRepository.add(userId, any()),
      ).thenAnswer((_) async => 'new-item-id');
    });

    Future<PantryItem> addedWith(Future<PantryItem> Function() act) async {
      await act();
      return verify(
            () => mockPantryRepository.add(userId, captureAny()),
          ).captured.single
          as PantryItem;
    }

    test('an explicit null quantity is stored as no quantity, not 1', () async {
      final captured = await addedWith(
        () => service.addFromIngredient(userId, salt, quantity: null),
      );
      expect(captured.quantity, isNull);
    });

    test('a typed quantity is stored as typed', () async {
      final captured = await addedWith(
        () => service.addFromIngredient(userId, salt, quantity: 6),
      );
      expect(captured.quantity, 6);
    });

    test('an omitted quantity defaults to 1', () async {
      final captured = await addedWith(
        () => service.addFromIngredient(userId, salt),
      );
      expect(captured.quantity, 1);
    });

    test(
      'a zero quantity is refused before it reaches the repository',
      () async {
        await expectLater(
          service.addFromIngredient(userId, salt, quantity: 0),
          throwsStateError,
        );
        verifyNever(() => mockPantryRepository.add(any(), any()));
      },
    );
  });

  group('PantryService.restoreItem (BUT-954)', () {
    test(
      're-adds the removed item and returns it with the fresh document id',
      () async {
        // Intent: the snackbar-undo flow must round-trip — the restored item
        // is byte-identical to the removed one except for the new id the
        // repository generates.
        final removed = _pantryItem(id: 'old-id', ingredientName: 'Mjölk');
        when(
          () => mockPantryRepository.add(userId, removed),
        ).thenAnswer((_) async => 'new-id');

        final restored = await service.restoreItem(userId, removed);

        expect(restored.id, 'new-id');
        expect(restored.ingredientName, 'Mjölk');
        verify(() => mockPantryRepository.add(userId, removed)).called(1);
      },
    );

    test('rejects invalid payloads via the shared input validation', () async {
      // A blank-name item must never reach the repository — same contract
      // as addFromIngredient/addFromText.
      final junk = _pantryItem(id: 'x', ingredientName: '   ');

      await expectLater(
        service.restoreItem(userId, junk),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => mockPantryRepository.add(any(), any()));
    });
  });

  // P5-U28: per-field writes and relative quantities
  group('PantryService part A (P5-U28)', () {
    setUp(() {
      when(
        () => mockPantryRepository.updateFields(
          any(),
          any(),
          any(),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockPantryRepository.adjustQuantity(any(), any(), any()),
      ).thenAnswer((_) async {});
    });

    test(
      'updateItem sends only the fields that differ from previous',
      () async {
        final before = _pantryItem(id: 'p1', ingredientName: 'Mjölk');
        final after = before.copyWith(note: 'laktosfri');

        await service.updateItem(userId, after, previous: before);

        final changes =
            verify(
                  () => mockPantryRepository.updateFields(
                    userId,
                    'p1',
                    captureAny(),
                    before: before,
                  ),
                ).captured.single
                as Map<String, Object>;
        expect(changes, {'note': 'laktosfri'});
      },
    );

    test('updateItem with nothing changed writes nothing', () async {
      final item = _pantryItem(id: 'p1');

      await service.updateItem(userId, item, previous: item);

      verifyNever(() => mockPantryRepository.updateFields(any(), any(), any()));
    });

    test(
      'an item without an amount is valid and does not send quantity',
      () async {
        final before = _pantryItem(id: 'p1');
        final after = before.copyWith(clearQuantity: true);

        await service.updateItem(userId, after, previous: before);

        verifyNever(
          () => mockPantryRepository.updateFields(any(), any(), any()),
        );
      },
    );

    test('adjustQuantity sends the delta, not a new total', () async {
      final item = _pantryItem(id: 'p1');

      final written = await service.adjustQuantity(userId, item, -2);

      expect(written, isTrue);
      verify(
        () => mockPantryRepository.adjustQuantity(userId, 'p1', -2),
      ).called(1);
      verifyNever(() => mockPantryRepository.updateFields(any(), any(), any()));
    });

    test('adjustQuantity leaves an item without an amount as it is', () async {
      final item = _pantryItem(id: 'p1').copyWith(clearQuantity: true);

      final written = await service.adjustQuantity(userId, item, 3);

      expect(written, isFalse);
      verifyNever(
        () => mockPantryRepository.adjustQuantity(any(), any(), any()),
      );
    });

    // Q5-02 = A: "har hemma" takes the bought amount, sent relatively
    // so two purchases at once add up.
    test(
      'fillUnknownQuantity writes the unit, then the amount as a delta',
      () async {
        final item = _pantryItem(
          id: 'p1',
        ).copyWith(clearQuantity: true, unit: '');

        final written = await service.fillUnknownQuantity(
          userId,
          item,
          6,
          'st',
        );

        expect(written, isTrue);
        verifyInOrder([
          () => mockPantryRepository.updateFields(userId, 'p1', {'unit': 'st'}),
          () => mockPantryRepository.adjustQuantity(userId, 'p1', 6),
        ]);
      },
    );

    test(
      'fillUnknownQuantity with the same unit sends only the delta',
      () async {
        final item = _pantryItem(id: 'p1').copyWith(clearQuantity: true);

        await service.fillUnknownQuantity(userId, item, 2, item.unit);

        verify(
          () => mockPantryRepository.adjustQuantity(userId, 'p1', 2),
        ).called(1);
        verifyNever(
          () => mockPantryRepository.updateFields(any(), any(), any()),
        );
      },
    );

    test(
      'fillUnknownQuantity leaves a known amount to adjustQuantity',
      () async {
        final item = _pantryItem(id: 'p1');

        final written = await service.fillUnknownQuantity(
          userId,
          item,
          2,
          'st',
        );

        expect(written, isFalse);
        verifyNever(
          () => mockPantryRepository.adjustQuantity(any(), any(), any()),
        );
      },
    );
  });

  group('PantryService failed reads and deletes', () {
    test('getAll rethrows when the pantry cannot be read, not an empty list '
        '(an empty list would look like an empty pantry)', () async {
      when(
        () => mockPantryRepository.getAll(userId),
      ).thenAnswer((_) => Future<List<PantryItem>>.error(StateError('read')));

      await expectLater(service.getAll(userId), throwsA(isA<StateError>()));
    });

    test('getAll returns the stored rows when the read works', () async {
      final rows = [_pantryItem(id: 'p1')];
      when(
        () => mockPantryRepository.getAll(userId),
      ).thenAnswer((_) async => rows);

      expect(await service.getAll(userId), rows);
    });

    test('removeItem rethrows when the repository delete is refused', () async {
      when(
        () => mockPantryRepository.remove(userId, 'p1'),
      ).thenAnswer((_) => Future<void>.error(StateError('refused')));

      await expectLater(
        service.removeItem(userId, 'p1'),
        throwsA(isA<StateError>()),
      );
    });

    test('removeItem returns normally when the delete is accepted', () async {
      when(
        () => mockPantryRepository.remove(userId, 'p1'),
      ).thenAnswer((_) async {});

      await service.removeItem(userId, 'p1');

      verify(() => mockPantryRepository.remove(userId, 'p1')).called(1);
    });

    test('updateItem throws when the write fails, instead of returning null '
        'as if it were saved', () async {
      final before = _pantryItem(id: 'p1', ingredientName: 'Mjölk');
      when(
        () => mockPantryRepository.updateFields(
          any(),
          any(),
          any(),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) => Future<void>.error(StateError('refused')));

      await expectLater(
        service.updateItem(
          userId,
          before.copyWith(note: 'ny'),
          previous: before,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'updateItem failed',
          ),
        ),
      );
    });
  });
}
