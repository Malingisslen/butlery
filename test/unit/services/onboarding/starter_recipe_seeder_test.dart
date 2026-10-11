// BUT-920: the starter recipes onboarding and the guest start both seed.

import 'package:butlery/data/recipes/recipe_seeds.dart';
import 'package:butlery/services/onboarding/starter_recipe_seeder.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRecipes extends Mock implements UnifiedRecipeService {}

void main() {
  late _MockRecipes recipes;
  late int created;

  void stubCreate({String? Function(String title)? idFor}) {
    when(
      () => recipes.createPersonalRecipe(
        title: any(named: 'title'),
        description: any(named: 'description'),
        ingredients: any(named: 'ingredients'),
        instructions: any(named: 'instructions'),
        mealType: any(named: 'mealType'),
        portions: any(named: 'portions'),
        timeMinutes: any(named: 'timeMinutes'),
        sourceUrl: any(named: 'sourceUrl'),
      ),
    ).thenAnswer((invocation) async {
      final title = invocation.namedArguments[#title] as String;
      created++;
      return idFor == null ? 'id-$created' : idFor(title);
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    recipes = _MockRecipes();
    created = 0;
  });

  test(
    'seeds every starter recipe and returns the stored ids in order',
    () async {
      stubCreate();

      final ids = await StarterRecipeSeeder(
        recipeService: recipes,
      ).seed(uid: 'u1');

      expect(ids, [
        for (var i = 1; i <= RecipeSeeds.allRecipes.length; i++) 'id-$i',
      ]);
    },
  );

  test('a second seed for the same account adds nothing', () async {
    stubCreate();
    final seeder = StarterRecipeSeeder(recipeService: recipes);

    await seeder.seed(uid: 'u1');
    final again = await seeder.seed(uid: 'u1');

    expect(again, isEmpty);
    expect(created, RecipeSeeds.allRecipes.length);
  });

  test('another account on the same device is seeded', () async {
    stubCreate();
    final seeder = StarterRecipeSeeder(recipeService: recipes);

    await seeder.seed(uid: 'u1');
    final other = await seeder.seed(uid: 'u2');

    expect(other, hasLength(RecipeSeeds.allRecipes.length));
  });

  test('one failing recipe does not stop the others', () async {
    final failing = RecipeSeeds.allRecipes.first.core.title;
    when(
      () => recipes.createPersonalRecipe(
        title: any(named: 'title'),
        description: any(named: 'description'),
        ingredients: any(named: 'ingredients'),
        instructions: any(named: 'instructions'),
        mealType: any(named: 'mealType'),
        portions: any(named: 'portions'),
        timeMinutes: any(named: 'timeMinutes'),
        sourceUrl: any(named: 'sourceUrl'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.namedArguments[#title] == failing) {
        throw Exception('permission-denied');
      }
      return 'ok';
    });

    final ids = await StarterRecipeSeeder(
      recipeService: recipes,
    ).seed(uid: 'u1');

    expect(ids, hasLength(RecipeSeeds.allRecipes.length - 1));
  });

  test('a seed where nothing was stored can be tried again', () async {
    stubCreate(idFor: (_) => null);
    final seeder = StarterRecipeSeeder(recipeService: recipes);

    await seeder.seed(uid: 'u1');
    stubCreate();
    final retry = await seeder.seed(uid: 'u1');

    expect(retry, hasLength(RecipeSeeds.allRecipes.length));
  });
}
