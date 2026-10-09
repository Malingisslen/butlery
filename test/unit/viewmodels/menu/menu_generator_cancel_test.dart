/// BUT-2157: a cancelled generation starts no further read. The generator
/// asks its `isCancelled` callback after each step; once it answers true the
/// week-plan read and the menu computation never run.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
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

class _MockPantryService extends Mock implements PantryService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMenuService menuService;
  late _MockWeeklyMenuPlanService planService;
  late MenuGenerator generator;

  setUpAll(() async {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<Recipe>[]);
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

  // The cancel can land while any later step is running. Each case lets the
  // step itself raise the flag, then checks that the NEXT step never starts:
  // a step after the cancel is a read the user already said no to.
  group('a cancel that lands between the later steps', () {
    late MockUserService users;
    late _MockPantryService pantry;
    late MenuGenerator laterGenerator;
    var cancelled = false;

    // The generator resolves the pantry through the production locator.
    setUpAll(() => prod.ServiceLocator.initialize(DIContainer()));
    tearDownAll(prod.ServiceLocator.reset);

    setUp(() {
      cancelled = false;
      users = MockUserService();
      stubOwnPreferences(
        users,
        const UserAllergenPreferences(
          trackedAllergens: {},
          trackedDietary: {},
        ),
      );
      when(() => users.currentUserId).thenReturn('u');
      pantry = _MockPantryService();
      when(
        () => pantry.getMatchingRecipes(any(), any()),
      ).thenAnswer((_) async => []);
      TestServiceLocator.registerMock<PantryService>(pantry);
      final recipes = MockUnifiedRecipeService()
        ..setRecipeState(
          isInitialized: true,
          recipes: [RecipeFactory.build(id: 'r1', mealType: 'Middag')],
        );
      laterGenerator = MenuGenerator(
        menuService: menuService,
        recipeService: recipes,
        userService: users,
        weeklyMenuPlanService: planService,
        filterByAllergens: true,
      );
    });

    tearDown(() => TestServiceLocator.unregister<PantryService>());

    Future<void> expectCancelled() => expectLater(
      laterGenerator.generateMenuFromPrompt(
        'en middag',
        isCancelled: () => cancelled,
      ),
      throwsA(isA<MenuGenerationCancelled>()),
    );

    test(
      'after the allergen-safe pool is read: no week read follows',
      () async {
        final profile = users.currentUserProfile;
        when(() => users.currentUserProfile).thenAnswer((_) {
          cancelled = true;
          return profile;
        });

        await expectCancelled();

        verifyNever(() => planService.getWeek(any()));
        expect(menuService.lastGeneratePrompt, isNull);
        // The screen went back to an earlier suggestion; its stats stay.
        expect(laterGenerator.lastPoolStats, isNull);
      },
    );

    test('after the recent weeks are read: no pantry read follows', () async {
      when(() => planService.getWeek(any())).thenAnswer((_) async {
        cancelled = true;
        return WeeklyMenuPlan(
          id: 'w',
          userId: 'u',
          weekStartDate: DateTime(2026, 9, 21),
          entries: const [],
          createdAt: DateTime(2026, 9, 21),
          updatedAt: DateTime(2026, 9, 21),
        );
      });

      await expectCancelled();

      verify(() => planService.getWeek(any())).called(2);
      verifyNever(() => pantry.getMatchingRecipes(any(), any()));
      expect(menuService.lastGeneratePrompt, isNull);
    });

    test('after the scoring context is built: the computation never '
        'starts', () async {
      when(() => pantry.getMatchingRecipes(any(), any())).thenAnswer((_) async {
        cancelled = true;
        return [];
      });

      await expectCancelled();

      verify(() => pantry.getMatchingRecipes(any(), any())).called(1);
      expect(menuService.lastGeneratePrompt, isNull);
    });
  });
}
