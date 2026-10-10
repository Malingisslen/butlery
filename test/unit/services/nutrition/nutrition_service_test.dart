import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/household.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/nutrition/nutrition_service.dart';
import 'package:butlery/services/permission_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

/// Serves the two bundled nutrition assets from memory.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.assets);
  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      assets[key]!;
}

// One ingredient, "kyckling", curated to food 1. Foods 2 and 3 are what a
// household can choose instead; their kcal differ so the total says which
// food was used.
final _bundle = _FakeBundle({
  NutritionService.foodsAsset: jsonEncode({
    'version': 'test',
    'foods': [
      {'id': 1, 'name': 'Kyckling standard', 'kcal': 100},
      {'id': 2, 'name': 'Kyckling ekologisk', 'kcal': 200},
      {'id': 3, 'name': 'Kyckling lårfilé', 'kcal': 300},
    ],
  }),
  NutritionService.matchingAsset: jsonEncode({
    'ingredients': {
      'kyckling': {'food': 1},
    },
  }),
});

const _userId = 'user-1';

// 100 g of kyckling, so total kcal equals the chosen food's kcal.
Recipe _recipe() => Recipe(
  type: RecipeType.personal,
  core: RecipeCore(
    id: 'r1',
    title: 'Kycklinggryta',
    description: '',
    ingredients: const ['100 g kyckling'],
    structuredIngredients: const [
      RecipeIngredient(
        amount: 100,
        unit: 'g',
        name: 'kyckling',
        raw: '100 g kyckling',
      ),
    ],
    instructions: const [],
    mealType: 'Huvudrätt',
    portions: 4,
  ),
);

Household _household(Map<String, int> choices, {String id = 'hh-read'}) =>
    Household(
      id: id,
      name: Household.defaultName,
      members: const [],
      createdBy: _userId,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      nutritionFoodChoices: choices,
    );

void main() {
  late _MockHouseholdRepository households;
  late FakeAuthRepository auth;
  late NutritionService service;

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    // executeServiceOperation reads the production locator's AuthRepository;
    // unwired, setChoice's closure would never run.
    auth = TestServiceLocator.get<AuthRepository>() as FakeAuthRepository;
    auth.setAuthState(userId: _userId, isAuthenticated: true);
    final permissions = _MockPermissionService();
    when(() => permissions.currentUserId).thenReturn(_userId);
    TestServiceLocator.registerSingleton<PermissionService>(permissions);

    households = _MockHouseholdRepository();
    when(
      () => households.setNutritionFoodChoice(
        householdId: any(named: 'householdId'),
        key: any(named: 'key'),
        foodId: any(named: 'foodId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => households.ensureForUser(_userId),
    ).thenAnswer((_) async => _household({}, id: 'hh-ensured'));
    service = NutritionService(
      householdRepository: households,
      bundle: _bundle,
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  void stubRead(Map<String, int>? choices, {String id = 'hh-read'}) =>
      when(
        () => households.getActiveForUser(_userId),
      ).thenAnswer(
        (_) async => choices == null ? null : _household(choices, id: id),
      );

  Future<double> kcal() async =>
      (await service.summarize(_recipe())).total.kcal;

  Future<void> setChoiceOk(String key, int? foodId) =>
      service.setChoice(key, foodId);

  group('summarize', () {
    test(
      'uses the household\'s chosen food instead of the curated one',
      () async {
        stubRead({'kyckling': 2});

        expect(await kcal(), 200);
        verify(() => households.getActiveForUser(_userId)).called(1);
      },
    );

    test('without a household the curated food is used', () async {
      stubRead(null);

      expect(await kcal(), 100);
    });

    test('reads the household once per session', () async {
      stubRead({'kyckling': 2});
      expect(await kcal(), 200);

      // A different answer on a second read would be visible in the total.
      stubRead({'kyckling': 3});
      expect(await kcal(), 200);

      verify(() => households.getActiveForUser(_userId)).called(1);
    });

    test(
      'a failed read falls back to the curated food and is retried',
      () async {
        when(
          () => households.getActiveForUser(_userId),
        ).thenThrow(Exception('offline'));
        expect(await kcal(), 100);

        stubRead({'kyckling': 3});
        expect(await kcal(), 300);

        verify(() => households.getActiveForUser(_userId)).called(2);
      },
    );

    test('a read that found no household is cached, not retried', () async {
      stubRead(null);
      expect(await kcal(), 100);

      stubRead({'kyckling': 2});
      expect(await kcal(), 100);

      verify(() => households.getActiveForUser(_userId)).called(1);
    });
  });

  group('setChoice', () {
    test('saves the exact key and food id on the ensured household', () async {
      await setChoiceOk('kyckling', 2);

      verify(
        () => households.setNutritionFoodChoice(
          householdId: 'hh-ensured',
          key: 'kyckling',
          foodId: 2,
        ),
      ).called(1);
    });

    test('ensures the household on the first write only', () async {
      await setChoiceOk('kyckling', 2);
      await setChoiceOk('kyckling', 3);

      verify(() => households.ensureForUser(_userId)).called(1);
      verify(
        () => households.setNutritionFoodChoice(
          householdId: 'hh-ensured',
          key: 'kyckling',
          foodId: 3,
        ),
      ).called(1);
    });

    test('reuses the household id a read already found', () async {
      stubRead({}, id: 'hh-read');
      await kcal();

      await setChoiceOk('kyckling', 2);

      verifyNever(() => households.ensureForUser(any()));
      verify(
        () => households.setNutritionFoodChoice(
          householdId: 'hh-read',
          key: 'kyckling',
          foodId: 2,
        ),
      ).called(1);
    });

    test(
      'after a read, the next summarize reflects the pick without re-reading',
      () async {
        stubRead({});
        expect(await kcal(), 100);

        await setChoiceOk('kyckling', 2);

        expect(await kcal(), 200);
        verify(() => households.getActiveForUser(_userId)).called(1);
      },
    );

    test('a null food id removes the cached pick', () async {
      stubRead({'kyckling': 2});
      expect(await kcal(), 200);

      await setChoiceOk('kyckling', null);

      expect(await kcal(), 100);
      verify(
        () => households.setNutritionFoodChoice(
          householdId: 'hh-read',
          key: 'kyckling',
          foodId: null,
        ),
      ).called(1);
      verify(() => households.getActiveForUser(_userId)).called(1);
    });

    test(
      'before any successful read the cache stays empty, so the next summarize re-reads',
      () async {
        // The stored set differs from both "empty" and "just this pick": only a
        // re-read gives 300.
        stubRead({'kyckling': 3});

        await setChoiceOk('kyckling', 2);

        expect(await kcal(), 300);
        verify(() => households.getActiveForUser(_userId)).called(1);
      },
    );

    test(
      'a failed save does not change what the next summarize uses',
      () async {
        stubRead({});
        expect(await kcal(), 100);
        when(
          () => households.setNutritionFoodChoice(
            householdId: any(named: 'householdId'),
            key: any(named: 'key'),
            foodId: any(named: 'foodId'),
          ),
        ).thenThrow(Exception('permission-denied'));

        // The picker shows its save error only if this throws.
        await expectLater(
          service.setChoice('kyckling', 2),
          throwsA(isA<StateError>()),
        );

        expect(await kcal(), 100);
      },
    );

    test('signed out, nothing is written', () async {
      auth.setAuthState();

      await expectLater(
        service.setChoice('kyckling', 2),
        throwsA(isA<StateError>()),
      );

      verifyNever(() => households.ensureForUser(any()));
      verifyNever(
        () => households.setNutritionFoodChoice(
          householdId: any(named: 'householdId'),
          key: any(named: 'key'),
          foodId: any(named: 'foodId'),
        ),
      );
    });
  });

  group('dispose', () {
    test('clears the cached choices, so the next summarize re-reads', () async {
      stubRead({'kyckling': 2});
      expect(await kcal(), 200);
      stubRead({'kyckling': 3});

      await service.dispose();

      expect(await kcal(), 300);
      verify(() => households.getActiveForUser(_userId)).called(2);
    });

    test(
      'forgets the household id, so the next write ensures it again',
      () async {
        await setChoiceOk('kyckling', 2);

        await service.dispose();
        await setChoiceOk('kyckling', 3);

        verify(() => households.ensureForUser(_userId)).called(2);
      },
    );
  });
}
