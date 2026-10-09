/// BUT-2157: a cancelled generation starts no further read. The generator
/// asks its `isCancelled` callback after each step; once it answers true the
/// week-plan read and the menu computation never run.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/viewmodels/menu/menu_generation_run.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMenuService menuService;
  late _MockWeeklyMenuPlanService planService;
  late MenuGenerator generator;

  setUpAll(() async {
    registerFallbackValue(DateTime(2026));
    await TestServiceLocator.initialize();
  });

  tearDownAll(() => TestServiceLocator.reset());

  setUp(() {
    menuService = MockMenuService()
      ..setGenerateMenuResult({
        'Middag': [RecipeFactory.build(id: 'r1', mealType: 'Middag')],
      });
    planService = _MockWeeklyMenuPlanService();
    when(() => planService.getWeek(any())).thenAnswer(
      (_) async => WeeklyMenuPlan(
        id: 'w',
        userId: 'u',
        weekStartDate: DateTime(2026, 9, 21),
        entries: const [],
        createdAt: DateTime(2026, 9, 21),
        updatedAt: DateTime(2026, 9, 21),
      ),
    );
    final users = MockUserService();
    stubOwnPreferences(
      users,
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );
    final recipes = MockUnifiedRecipeService()
      ..setRecipeState(
        isInitialized: true,
        recipes: [
          RecipeFactory.build(id: 'r1', mealType: 'Middag'),
          RecipeFactory.build(id: 'r2', mealType: 'Middag'),
        ],
      );
    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipes,
      userService: users,
      weeklyMenuPlanService: planService,
    );
  });

  test('cancelled during the first wait: no week read and no '
      'computation', () async {
    var cancelled = false;
    final run = generator.generateMenuFromPrompt(
      'tre middagar',
      isCancelled: () => cancelled,
    );
    cancelled = true;

    await expectLater(run, throwsA(isA<MenuGenerationCancelled>()));
    verifyNever(() => planService.getWeek(any()));
    expect(menuService.lastGeneratePrompt, isNull);
  });

  test('a run nobody cancels reads the weeks and computes', () async {
    final menu = await generator.generateMenuFromPrompt(
      'tre middagar',
      isCancelled: () => false,
    );

    expect(menu.keys, ['Middag']);
    verify(() => planService.getWeek(any())).called(2);
    expect(menuService.lastGeneratePrompt, 'tre middagar');
  });

  test('a re-roll cancelled during its first wait computes nothing', () async {
    var cancelled = false;
    final run = generator.regenerateMenuSection(
      'Middag',
      const {},
      originalPrompt: 'tre middagar',
      isCancelled: () => cancelled,
    );
    cancelled = true;

    await expectLater(run, throwsA(isA<MenuGenerationCancelled>()));
    verifyNever(() => planService.getWeek(any()));
    expect(menuService.lastGeneratePrompt, isNull);
  });
}
