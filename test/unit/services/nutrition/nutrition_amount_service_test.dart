/// BUT-643 follow-up: `NutritionService` counts a household's own amounts and
/// keeps them in step with what it saves.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/household.dart';
import 'package:butlery/models/nutrition/nutrition_amount_choice.dart';
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

class _FakeChoice extends Fake implements NutritionAmountChoice {}

class _FakeBundle extends AssetBundle {
  _FakeBundle(this.assets);
  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      assets[key]!;
}

// Food 1 is 100 kcal per 100 g, so the total kcal equals the grams counted.
final _bundle = _FakeBundle({
  NutritionService.foodsAsset: jsonEncode({
    'version': 'test',
    'foods': [
      {'id': 1, 'name': 'Kyckling', 'kcal': 100},
    ],
  }),
  NutritionService.matchingAsset: jsonEncode({
    'ingredients': {
      'kyckling': {'food': 1},
    },
  }),
});

const _userId = 'user-1';

// A line with no amount of its own, for four portions.
Recipe _recipe() => Recipe(
  type: RecipeType.personal,
  core: RecipeCore(
    id: 'r1',
    title: 'Kycklinggryta',
    description: '',
    ingredients: const ['kyckling'],
    structuredIngredients: const [
      RecipeIngredient(name: 'kyckling', raw: 'kyckling'),
    ],
    instructions: const [],
    mealType: 'Huvudrätt',
    portions: 4,
  ),
);

Household _household(
  Map<String, NutritionAmountChoice> amounts, {
  String id = 'hh-read',
}) => Household(
  id: id,
  name: Household.defaultName,
  members: const [],
  createdBy: _userId,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  nutritionAmountChoices: amounts,
);

void main() {
  late _MockHouseholdRepository households;
  late NutritionService service;

  setUpAll(() => registerFallbackValue(_FakeChoice()));

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    final auth = TestServiceLocator.get<AuthRepository>() as FakeAuthRepository;
    auth.setAuthState(userId: _userId, isAuthenticated: true);
    final permissions = _MockPermissionService();
    when(() => permissions.currentUserId).thenReturn(_userId);
    TestServiceLocator.registerSingleton<PermissionService>(permissions);

    households = _MockHouseholdRepository();
    when(
      () => households.setNutritionAmountChoice(
        householdId: any(named: 'householdId'),
        key: any(named: 'key'),
        choice: any(named: 'choice'),
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

  void stubRead(Map<String, NutritionAmountChoice> amounts) => when(
    () => households.getActiveForUser(_userId),
  ).thenAnswer((_) async => _household(amounts));

  Future<double> kcal() async =>
      (await service.summarize(_recipe())).total.kcal;

  const grams600 = NutritionAmountChoice(amount: 600, unit: 'g');
  const grams200 = NutritionAmountChoice(amount: 200, unit: 'g');

  test(
    'a line with no amount and no household amount is not counted',
    () async {
      stubRead({});

      expect(await kcal(), 0);
    },
  );

  test('the household\'s amount for the ingredient is counted', () async {
    stubRead({'kyckling': grams600});

    expect(await kcal(), 600);
  });

  test(
    'the amount for this recipe wins over the one for every recipe',
    () async {
      stubRead({
        'kyckling': grams600,
        NutritionAmountChoice.recipeKey('r1', 'kyckling')!: grams200,
      });

      expect(await kcal(), 200);
    },
  );

  group('setAmount', () {
    test('saves the key and choice on the ensured household', () async {
      await service.setAmount('kyckling', grams200);

      verify(
        () => households.setNutritionAmountChoice(
          householdId: 'hh-ensured',
          key: 'kyckling',
          choice: grams200,
        ),
      ).called(1);
    });

    test(
      'the next summary counts it without reading the household again',
      () async {
        stubRead({});
        expect(await kcal(), 0);

        await service.setAmount('kyckling', grams200);

        expect(await kcal(), 200);
        verify(() => households.getActiveForUser(_userId)).called(1);
      },
    );

    test('a null choice removes the cached amount', () async {
      stubRead({'kyckling': grams600});
      expect(await kcal(), 600);

      await service.setAmount('kyckling', null);

      expect(await kcal(), 0);
    });

    test(
      'a full household surfaces as its own exception and caches nothing',
      () async {
        stubRead({});
        expect(await kcal(), 0);
        when(
          () => households.setNutritionAmountChoice(
            householdId: any(named: 'householdId'),
            key: any(named: 'key'),
            choice: any(named: 'choice'),
          ),
        ).thenThrow(const NutritionAmountChoicesFullException());

        await expectLater(
          service.setAmount('kyckling', grams200),
          throwsA(isA<NutritionAmountChoicesFullException>()),
        );

        expect(await kcal(), 0);
      },
    );

    test('any other failure throws, and caches nothing', () async {
      stubRead({});
      expect(await kcal(), 0);
      when(
        () => households.setNutritionAmountChoice(
          householdId: any(named: 'householdId'),
          key: any(named: 'key'),
          choice: any(named: 'choice'),
        ),
      ).thenThrow(StateError('denied'));

      await expectLater(
        service.setAmount('kyckling', grams200),
        throwsA(isA<StateError>()),
      );

      expect(await kcal(), 0);
    });
  });

  test('setAmount reuses the household id a read already found', () async {
    stubRead({});
    await kcal();

    await service.setAmount('kyckling', grams200);

    verifyNever(() => households.ensureForUser(any()));
    verify(
      () => households.setNutritionAmountChoice(
        householdId: 'hh-read',
        key: 'kyckling',
        choice: grams200,
      ),
    ).called(1);
  });
}
