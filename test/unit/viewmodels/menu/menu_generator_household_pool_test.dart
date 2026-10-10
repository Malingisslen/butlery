/// BUT-2345: the pool the overflow-tray restore reads filters the household's
/// allergens AND its diets, as menu generation does. A pool that skipped
/// either would bring an unsafe dish back into the tray unchecked.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/menu_generator.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';

Recipe _dish(
  String id, {
  Map<String, TriState> allergen = const {},
  Map<String, TriState> dietary = const {},
}) {
  final base = RecipeFactory.build(id: id, title: id, mealType: 'Middag');
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: const {},
        allergenStatus: allergen,
        dietaryStatus: dietary,
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => TestServiceLocator.initialize());
  tearDownAll(() => TestServiceLocator.reset());

  test(
    'drops a dish with a tracked allergen and one outside the diet',
    () async {
      final users = MockUserService();
      stubOwnPreferences(
        users,
        const UserAllergenPreferences(
          trackedAllergens: {'nötter'},
          trackedDietary: {'vegetarisk'},
        ),
        useHouseholdAllergens: false,
      );
      final recipes = MockUnifiedRecipeService()
        ..setRecipeState(
          isInitialized: true,
          recipes: [
            _dish(
              'safe',
              allergen: {'nötter': TriState.free},
              dietary: {'vegetarisk': TriState.free},
            ),
            _dish(
              'nuts',
              allergen: {'nötter': TriState.contains},
              dietary: {'vegetarisk': TriState.free},
            ),
            _dish(
              'meat',
              allergen: {'nötter': TriState.free},
              dietary: {'vegetarisk': TriState.contains},
            ),
          ],
        );

      final pool = await MenuGenerator.readHouseholdSafePool(
        menuService: MockMenuService(),
        recipeService: recipes,
        userService: users,
      );

      expect(pool.map((r) => r.id), ['safe']);
    },
  );
}
