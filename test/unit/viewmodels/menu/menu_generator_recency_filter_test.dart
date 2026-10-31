/// Re-shuffle and swap follow the same prefilter and recency rules as the
/// generation that produced the menu.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';

class _MockPlanService extends Mock implements WeeklyMenuPlanService {}

Recipe _recipe(
  String id, {
  bool favorite = false,
  DateTime? lastCookedAt,
}) {
  final base = RecipeFactory.build(
    id: id,
    title: id,
    mealType: 'Middag',
    lastCookedAt: lastCookedAt,
  );
  return Recipe(
    core: base.core.copyWith(isFavorite: favorite),
    type: base.type,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 4, 7, 9);

  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;
  late _MockPlanService planService;
  late MenuGenerator generator;

  setUpAll(() async {
    registerFallbackValue(DateTime(2026));
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDownAll(() async {
    prod.ServiceLocator.reset();
    await TestServiceLocator.reset();
  });

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();
    planService = _MockPlanService();
    stubOwnPreferences(
      userService,
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );
    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
      weeklyMenuPlanService: planService,
    );
    generator.useSmartSwap = true;
    menuService.setGenerateMenuResult({
      'Middag': [_recipe('x')],
    });
  });

  void planUses(List<String> recipeIds, {bool readFailed = false}) {
    when(() => planService.readWeek(any())).thenAnswer((i) async {
      final week = i.positionalArguments.first as DateTime;
      final empty = WeeklyMenuPlan.empty(userId: 'u', date: week);
      final plan = empty.copyWith(
        entries: [
          for (final id in recipeIds)
            WeeklyMenuPlanEntry.create(
              day: DayOfWeek.mon,
              slot: MealSlot.ovrigt,
              recipeId: id,
              recipeTitle: id,
            ),
        ],
      );
      return WeeklyMenuPlanRead(plan: plan, readFailed: readFailed);
    });
  }

  group('re-shuffle uses the generation keyword prefilter', () {
    test('"favoriter" prompt keeps the re-roll pool to favourites', () async {
      planUses(const []);
      recipeService.setRecipeState(
        recipes: [
          _recipe('f1', favorite: true),
          _recipe('f2', favorite: true),
          _recipe('f3', favorite: true),
          _recipe('plain1'),
          _recipe('plain2'),
        ],
        isInitialized: true,
      );

      await generator.regenerateMenuSection(
        'Middag',
        {
          'Middag': [_recipe('x')],
        },
        originalPrompt: 'tre middagar från favoriter',
      );

      expect(
        menuService.lastGenerateRecipes!.map((r) => r.id).toSet(),
        {'f1', 'f2', 'f3'},
      );
    });

    test('"senaste" prompt keeps recently cooked recipes', () async {
      planUses(const []);
      final cooked = fixedNow.subtract(const Duration(days: 5));
      recipeService.setRecipeState(
        recipes: [
          _recipe('c1', lastCookedAt: cooked),
          _recipe('c2', lastCookedAt: cooked),
          _recipe('c3', lastCookedAt: cooked),
          _recipe('old'),
        ],
        isInitialized: true,
      );

      await withClock(Clock.fixed(fixedNow), () async {
        await generator.regenerateMenuSection(
          'Middag',
          {
            'Middag': [_recipe('x')],
          },
          originalPrompt: 'tre middagar med senaste recept',
        );
      });

      expect(
        menuService.lastGenerateRecipes!.map((r) => r.id).toSet(),
        {'c1', 'c2', 'c3'},
      );
    });

    test('too small a filtered pool falls back to the full pool', () async {
      planUses(const []);
      recipeService.setRecipeState(
        recipes: [_recipe('f1', favorite: true), _recipe('p1'), _recipe('p2')],
        isInitialized: true,
      );

      await generator.regenerateMenuSection(
        'Middag',
        {
          'Middag': [_recipe('x')],
        },
        originalPrompt: 'tre middagar från favoriter',
      );

      expect(menuService.lastGenerateRecipes, hasLength(3));
    });

    test('a prompt without keywords leaves the pool alone', () async {
      planUses(const []);
      recipeService.setRecipeState(
        recipes: [
          _recipe('f1', favorite: true),
          _recipe('p1'),
          _recipe('p2'),
          _recipe('p3'),
        ],
        isInitialized: true,
      );

      await generator.regenerateMenuSection(
        'Middag',
        {
          'Middag': [_recipe('x')],
        },
        originalPrompt: 'tre middagar',
      );

      expect(menuService.lastGenerateRecipes, hasLength(4));
    });
  });

  group('swap avoids recently used recipes', () {
    Future<SwapResult> swap(Recipe current) => generator.swapSingleRecipe(
      current,
      'Middag',
      {
        'Middag': [current],
      },
    );

    test('picks a fresh recipe whenever one exists', () async {
      planUses(['recent1', 'recent2']);
      final current = _recipe('current');
      recipeService.setRecipeState(
        recipes: [
          current,
          _recipe('recent1'),
          _recipe('recent2'),
          _recipe('fresh'),
        ],
        isInitialized: true,
      );

      final picks = <String>{};
      for (var i = 0; i < 15; i++) {
        picks.add((await swap(current)).recipe!.id);
      }

      expect(picks, {'fresh'});
    });

    test('still returns a recipe when every candidate is recent', () async {
      planUses(['recent1', 'recent2']);
      final current = _recipe('current');
      recipeService.setRecipeState(
        recipes: [current, _recipe('recent1'), _recipe('recent2')],
        isInitialized: true,
      );

      final result = await swap(current);

      expect(result.recipe, isNotNull);
      expect({'recent1', 'recent2'}, contains(result.recipe!.id));
      expect(result.alternativesRemaining, 1);
    });

    test('a failed read does not block the swap but is flagged', () async {
      planUses(const [], readFailed: true);
      final current = _recipe('current');
      recipeService.setRecipeState(
        recipes: [current, _recipe('other')],
        isInitialized: true,
      );

      final result = await swap(current);

      expect(result.recipe!.id, 'other');
      expect(generator.lastRecencyReadFailed, isTrue);
    });

    test(
      'a re-shuffle read failure is flagged, a clean one keeps it',
      () async {
        planUses(const [], readFailed: true);
        recipeService.setRecipeState(
          recipes: [_recipe('a'), _recipe('b')],
          isInitialized: true,
        );
        await generator.regenerateMenuSection('Middag', {
          'Middag': [_recipe('x')],
        });
        expect(generator.lastRecencyReadFailed, isTrue);

        planUses(const []);
        await generator.regenerateMenuSection('Middag', {
          'Middag': [_recipe('x')],
        });
        expect(
          generator.lastRecencyReadFailed,
          isTrue,
          reason: 'the menu on screen still came from the unread generation',
        );
      },
    );
  });
}
