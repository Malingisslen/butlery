// test/unit/viewmodels/menu/menu_generator_personalization_test.dart
//
// BUT-1320/1321 personalisation-context plumbing. Verifies that MenuGenerator
// assembles the pantry/cuisine/skill signals and threads them into
// MenuService.generateMenuFromPrompt as a MenuScoringContext — and, crucially,
// that a missing or failing PantryService degrades to an empty context instead
// of blocking generation (the BUT-1279 "a failing/absent pantry must never
// block generation" contract, applied to the pantry-aware scoring read).
//
// Kept in its own file (like menu_generator_present_aware_test.dart) because
// the generator resolves PantryService via the global ServiceLocator; a
// dedicated file gives a clean locator without the 60+ prior tests' shared
// state.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/menu/menu_generator.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/pantry/pantry_service.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockPantryService extends Mock implements PantryService {}

UserProfile _profile({
  Set<String> affinities = const {},
  CookingSkillLevel? skill,
}) => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 'test@example.com',
  joinedAt: DateTime(2026),
  lastActiveAt: DateTime(2026),
  cuisineAffinities: affinities.toList(),
  cookingSkillLevel: skill,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MenuGenerator generator;
  late MockMenuService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUserService userService;

  // MenuGenerator resolves PantryService via ServiceLocator.tryGet, which reads
  // the PRODUCTION container — bridge it (same as the present-aware test).
  setUpAll(() async {
    registerFallbackValue(<Recipe>[]);
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    menuService = MockMenuService();
    recipeService = MockUnifiedRecipeService();
    userService = MockUserService();

    when(() => userService.allergenPreferences).thenReturn(
      const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
    );
    when(() => userService.currentUserId).thenReturn('u1');
    when(() => userService.currentUserProfile).thenReturn(_profile());

    generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
    );

    recipeService.setRecipeState(
      isInitialized: true,
      recipes: [
        RecipeFactory.build(id: 'r1', title: 'r1', mealType: 'middag'),
        RecipeFactory.build(id: 'r2', title: 'r2', mealType: 'middag'),
      ],
    );
    menuService.setGenerateMenuResult({
      'middag': [RecipeFactory.build(id: 'r1', title: 'r1')],
    });
  });

  tearDown(() {
    // Clear any PantryService registered during a test so the next test's
    // "unregistered" scenario is honest. TestServiceLocator and the production
    // ServiceLocator share GetIt.instance, so removing it here is sufficient.
    if (GetIt.instance.isRegistered<PantryService>()) {
      GetIt.instance.unregister<PantryService>();
    }
  });

  group('MenuGenerator - personalisation context plumbing (BUT-1320/1321)', () {
    test(
      'threads pantry overlap, cuisine affinities and skill into the service',
      () async {
        when(() => userService.currentUserProfile).thenReturn(
          _profile(
            affinities: {'italiensk'},
            skill: CookingSkillLevel.beginner,
          ),
        );
        final pantry = _MockPantryService();
        when(() => pantry.getMatchingRecipes(any(), any())).thenAnswer(
          (_) async => [
            (
              recipe: RecipeFactory.build(id: 'r1', title: 'r1'),
              matchPercent: 0.8,
            ),
          ],
        );
        TestServiceLocator.registerSingleton<PantryService>(pantry);

        await generator.generateMenuFromPrompt('veckomeny');

        final ctx = menuService.lastScoringContext;
        expect(ctx, isNotNull);
        expect(
          ctx!.cuisineAffinities,
          contains('italiensk'),
          reason: 'favourite cuisines must reach the scorer',
        );
        expect(
          ctx.skill,
          CookingSkillLevel.beginner,
          reason: 'cooking skill must reach the scorer',
        );
        expect(
          ctx.pantryMatchByRecipeId['r1'],
          0.8,
          reason: 'the pantry overlap must be memoised by recipe id',
        );
      },
    );

    test(
      'a failing pantry read degrades to an empty pantry map, generation '
      'still completes (BUT-1279 fail-open)',
      () async {
        when(() => userService.currentUserProfile).thenReturn(
          _profile(
            affinities: {'italiensk'},
            skill: CookingSkillLevel.beginner,
          ),
        );
        final pantry = _MockPantryService();
        when(
          () => pantry.getMatchingRecipes(any(), any()),
        ).thenThrow(StateError('boom — pantry read failed'));
        TestServiceLocator.registerSingleton<PantryService>(pantry);

        final result = await generator.generateMenuFromPrompt('veckomeny');

        expect(
          result,
          isNotEmpty,
          reason: 'a pantry read failure must never block menu generation',
        );
        final ctx = menuService.lastScoringContext;
        expect(ctx, isNotNull);
        expect(
          ctx!.pantryMatchByRecipeId,
          isEmpty,
          reason: 'the failed pantry read contributes no boost, not a crash',
        );
        // The non-pantry signals survive the pantry failure.
        expect(ctx.cuisineAffinities, contains('italiensk'));
        expect(ctx.skill, CookingSkillLevel.beginner);
      },
    );

    test(
      'no PantryService registered -> empty pantry map, other signals intact',
      () async {
        when(() => userService.currentUserProfile).thenReturn(
          _profile(skill: CookingSkillLevel.advanced),
        );
        // No PantryService registered (tearDown/absence). tryGet returns null.

        final result = await generator.generateMenuFromPrompt('veckomeny');

        expect(result, isNotEmpty);
        final ctx = menuService.lastScoringContext!;
        expect(ctx.pantryMatchByRecipeId, isEmpty);
        expect(ctx.skill, CookingSkillLevel.advanced);
      },
    );

    test(
      'a null profile yields an empty-but-non-null context (no signals, no '
      'crash)',
      () async {
        when(() => userService.currentUserProfile).thenReturn(null);

        final result = await generator.generateMenuFromPrompt('veckomeny');

        expect(result, isNotEmpty);
        final ctx = menuService.lastScoringContext!;
        expect(ctx.cuisineAffinities, isEmpty);
        expect(ctx.skill, isNull);
        expect(ctx.pantryMatchByRecipeId, isEmpty);
      },
    );
  });
}
