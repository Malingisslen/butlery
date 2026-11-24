// BUT-2497: the pool a day suggestion draws from. Own file (fresh isolate):
// the generator resolves HouseholdService through the global ServiceLocator.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/menu_generator/strict_safe_pool.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';

class _MockHouseholdService extends Mock implements HouseholdService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  Recipe recipe(String id, Map<String, TriState> allergens) {
    final base = RecipeFactory.build(id: id, title: id);
    return Recipe(
      core: base.core.copyWith(
        tagResult: TagResult(
          tags: const {},
          allergenStatus: allergens,
          dietaryStatus: const {},
          coverage: 1.0,
          generatedAt: DateTime(2026),
          generatorVersion: kTagGeneratorVersion,
        ),
      ),
      type: base.type,
    );
  }

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();
    stubOwnPreferences(
      userService,
      const UserAllergenPreferences(
        trackedAllergens: {'gluten'},
        trackedDietary: {},
        includeUnknownInMenu: true,
      ),
    );
    final household = _MockHouseholdService();
    when(() => household.hasHousehold).thenReturn(false);
    TestServiceLocator.registerSingleton<HouseholdService>(household);
  });

  test(
    'keeps a recipe proven free of the tracked allergen, drops one that '
    'contains it, and drops one whose status is unknown',
    () async {
      recipeService.setRecipeState(
        isInitialized: true,
        recipes: [
          recipe('free', {'gluten': TriState.free}),
          recipe('contains', {'gluten': TriState.contains}),
          recipe('unknown', {'gluten': TriState.unknown}),
        ],
      );

      final pool = await StrictSafePool.read(
        menuService: menuService,
        recipeService: recipeService,
        userService: userService,
      );

      expect(pool.map((r) => r.id), ['free']);
    },
  );
}
