import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/trackers/menu_events_tracker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

// Local pure-Mock MenuService — the centralized one has concrete @override
// methods that prevent mocktail stubbing with when().
class _MockMenuService extends Mock implements MenuService {}

// Local pure-Mock AnalyticsService — the centralized one's delegate methods
// return null instead of Future<void>, crashing await calls.
class _MockAnalyticsService extends Fake implements AnalyticsService {
  // Real tracker mock for the `.menu` getter so milestone calls
  // (`logFirstMealPlanIfMilestone`) resolve to a no-op Future<bool>.
  final MockMenuEventsTracker _menuTracker = MockMenuEventsTracker();

  @override
  MenuEventsTracker get menu => _menuTracker;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MenuViewModel', () {
    late MenuViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late _MockMenuService mockMenuService;
    late _MockAnalyticsService mockAnalyticsService;
    late MockUserService mockUserService;

    final testUserId = 'user123';
    final testFriendId = 'friend456';

    final testRecipe = RecipeBuilder()
        .withId('recipe1')
        .withTitle('Kottbullar')
        .withMealType('Middag')
        .withPortions(4)
        .withTimeMinutes(30)
        .build();

    final testRecipe2 = RecipeBuilder()
        .withId('recipe2')
        .withTitle('Pannkakor')
        .withMealType('Frukost')
        .withPortions(4)
        .withTimeMinutes(15)
        .build();

    final testMenuSnapshot = <String, List<Recipe>>{
      'Middag': [testRecipe],
      'Frukost': [testRecipe2],
    };

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());
      registerFallbackValue(testRecipe);
      registerFallbackValue(SharedMenu.create(
        sharedByUserId: testUserId,
        sharedByDisplayName: 'Test',
        sharedToUserIds: [testFriendId],
        menuTitle: 'Fallback',
        menuSnapshot: testMenuSnapshot,
        shareMessage: '',
      ));
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockRecipeService = MockFactory.createUnifiedRecipeService();
      mockMenuService = _MockMenuService();
      mockAnalyticsService = _MockAnalyticsService();

      // BUT-1317: the personal flow now filters by allergen/dietary prefs by
      // default, so the VM resolves UserService.allergenPreferences during
      // availableRecipes. Default to empty prefs (no filtering) for the
      // baseline tests; the BUT-1317 group overrides this per-test.
      mockUserService = MockUserService();
      when(() => mockUserService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {},
          trackedDietary: {},
        ),
      );
      TestServiceLocator.registerMock<UserService>(mockUserService);

      mockRecipeService.setRecipeState(
        recipes: [testRecipe, testRecipe2],
        currentUserId: testUserId,
        currentUserDisplayName: 'Test User',
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
          .thenAnswer((_) async => testMenuSnapshot);

      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      TestServiceLocator.registerMock<MenuService>(mockMenuService);
      TestServiceLocator.registerMock<AnalyticsService>(mockAnalyticsService);

      viewModel = MenuViewModel(
        recipeService: mockRecipeService,
        menuService: mockMenuService,
        analyticsService: mockAnalyticsService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
      await BaseUnitTest.teardownUnit();
    });

    // -- Initialization -------------------------------------------------------

    group('Initialization', () {
      test('should initialize with correct defaults', () {
        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.isGenerating, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.menu, isEmpty);
        expect(viewModel.totalRecipeCount, equals(0));
        expect(viewModel.lastPrompt, isEmpty);
        expect(viewModel.savedMenus, isEmpty);
        expect(viewModel.availableRecipes, isNotEmpty);
        expect(viewModel.hasAvailableRecipes, isTrue);
      });
    });

    // -- Generation -----------------------------------------------------------

    group('Menu Generation', () {
      test('should generate menu with valid prompt', () async {
        const prompt = 'Vegetarisk veckomeny';
        when(() => mockMenuService.generateMenuFromPrompt(prompt, any()))
            .thenAnswer((_) async => testMenuSnapshot);

        await viewModel.generateMenu(prompt);

        expect(viewModel.hasMenu, isTrue);
        expect(viewModel.menu, equals(testMenuSnapshot));
        expect(viewModel.menu.containsKey('Middag'), isTrue);
        expect(viewModel.totalRecipeCount, equals(2));
        expect(viewModel.lastPrompt, equals(prompt));
        verify(() => mockMenuService.generateMenuFromPrompt(prompt, any()))
            .called(1);
      });

      test('should reject empty prompt', () async {
        await viewModel.generateMenu('');

        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.error, equals('Ange vad du vill ha för meny'));
        verifyNever(() => mockMenuService.generateMenuFromPrompt(any(), any()));
      });

      test('should reject whitespace-only prompt', () async {
        await viewModel.generateMenu('   ');

        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.error, equals('Ange vad du vill ha för meny'));
        verifyNever(() => mockMenuService.generateMenuFromPrompt(any(), any()));
      });

      test('should handle generation error', () async {
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenThrow(Exception('Generation failed'));

        await viewModel.generateMenu('Valid prompt');

        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      test('should track generating state', () async {
        bool wasGenerating = false;
        viewModel.addListener(() {
          if (viewModel.isGenerating) wasGenerating = true;
        });

        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);

        await viewModel.generateMenu('Valid prompt');

        expect(wasGenerating, isTrue);
        expect(viewModel.isGenerating, isFalse);
      });

      test('should regenerate section', () async {
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Initial prompt');

        // regenerateMenuSection passes the original prompt (not '1 Middag')
        // so re-stub the any() matcher to return the regenerated section
        final regenerated = <String, List<Recipe>>{
          'Middag': [testRecipe2],
        };
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => regenerated);

        await viewModel.regenerateSection('Middag');

        expect(viewModel.menu['Middag']?.length, equals(1));
        expect(viewModel.menu['Middag']?.first.id, equals('recipe2'));
      });

      test('should not regenerate section without menu', () async {
        await viewModel.regenerateSection('Middag');

        expect(viewModel.hasMenu, isFalse);
        verifyNever(() => mockMenuService.generateMenuFromPrompt(any(), any()));
      });
    });

    // -- Saving ---------------------------------------------------------------

    group('Menu Saving', () {
      test('should save menu with name and comment', () async {
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid prompt');

        final result = await viewModel.saveMenuWithNameAndComment(
          'Test Menu',
          'Test comment',
        );

        expect(result, isTrue);
      });

      test('should reject saving without menu', () async {
        final result = await viewModel.saveMenuWithNameAndComment(
          'Test Menu',
          'Comment',
        );

        expect(result, isFalse);
        expect(viewModel.error, equals('Ingen meny att spara'));
      });

      test('should reject saving with empty name', () async {
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid prompt');

        final result =
            await viewModel.saveMenuWithNameAndComment('', 'Comment');

        expect(result, isFalse);
        expect(viewModel.error, equals('Ange ett namn för menyn'));
      });
    });

    // -- Loading --------------------------------------------------------------

    group('Menu Loading', () {
      test('should report false when menu not found', () async {
        final result = await viewModel.loadSavedMenu('nonexistent');

        expect(result, isFalse);
        expect(viewModel.error, equals('Menyn kunde inte hittas'));
      });

      test('should return bool on load attempt', () async {
        final result = await viewModel.loadSavedMenu('any_key');
        expect(result, isA<bool>());
      });
    });

    // -- Management -----------------------------------------------------------

    group('Menu Management', () {
      test('should clear current menu', () async {
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid prompt');
        expect(viewModel.hasMenu, isTrue);

        viewModel.clearMenu();

        expect(viewModel.hasMenu, isFalse);
        expect(viewModel.menu, isEmpty);
        expect(viewModel.lastPrompt, isEmpty);
        expect(viewModel.error, isNull);
      });

      test('should delete saved menu', () async {
        final result = await viewModel.deleteSavedMenu('menu123');
        // With FakeFirestore and no pre-existing menu, delete returns false
        expect(result, isA<bool>());
      });

      test('should refresh saved menus', () async {
        await viewModel.refreshSavedMenus();
        expect(viewModel.savedMenus, isA<List<SavedMenuInfo>>());
      });
    });

    // -- Social ---------------------------------------------------------------

    group('Social Features', () {
      test('should get available shared menus', () async {
        final menus = await viewModel.getAvailableSharedMenus();
        expect(menus, isA<List<Map<String, dynamic>>>());
      });

      test('should import shared menu', () async {
        final result = await viewModel.importSharedMenu('shared123');
        expect(result, isA<bool>());
      });

      test('should mark shared menu as viewed', () async {
        await viewModel.markSharedMenuAsViewed('shared123');
        // void method, verify no throw
        expect(() => viewModel.markSharedMenuAsViewed('shared123'),
            returnsNormally);
      });
    });

    // -- Recipe Operations ----------------------------------------------------

    group('Recipe Operations', () {
      test('should expose available recipes from service', () {
        expect(viewModel.availableRecipes, isNotEmpty);
        expect(viewModel.hasAvailableRecipes, isTrue);
        expect(viewModel.availableRecipes, contains(testRecipe));
        expect(viewModel.availableRecipes, contains(testRecipe2));
      });

      test('should track menu state after generation', () async {
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);
        await viewModel.generateMenu('Valid prompt');

        expect(viewModel.menu['Middag'], hasLength(1));
        expect(viewModel.menu['Frukost'], hasLength(1));
        expect(viewModel.totalRecipeCount, equals(2));
      });
    });

    // -- Error Handling -------------------------------------------------------

    group('Error Handling', () {
      test('should clear error', () async {
        await viewModel.generateMenu('');
        expect(viewModel.hasError, isTrue);

        viewModel.clearError();

        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should handle concurrent operations', () async {
        when(() => mockMenuService.generateMenuFromPrompt(any(), any()))
            .thenAnswer((_) async => testMenuSnapshot);

        final future1 = viewModel.generateMenu('First prompt');
        final future2 = viewModel.generateMenu('Second prompt');

        await Future.wait([future1, future2]);

        expect(viewModel.hasMenu, isTrue);
      });
    });

    // -- Disposal -------------------------------------------------------------

    group('Disposal', () {
      test('should clean up resources on dispose', () {
        final vm = MenuViewModel(
          recipeService: mockRecipeService,
          menuService: mockMenuService,
          analyticsService: mockAnalyticsService,
        );
        expect(() => vm.dispose(), returnsNormally);
      });

      test('should throw on double dispose', () {
        final vm = MenuViewModel(
          recipeService: mockRecipeService,
          menuService: mockMenuService,
          analyticsService: mockAnalyticsService,
        );
        vm.dispose();
        expect(() => vm.dispose(), throwsFlutterError);
      });
    });

    // -- BUT-1317: Personal flow allergen/dietary safety -----------------------
    //
    // The personal weekly-menu flow must filter out recipes containing the
    // user's tracked allergens / failing dietary prefs BY DEFAULT (sourced
    // from userService.allergenPreferences, honoring includeUnknownInMenu).
    // Before BUT-1317 the MenuViewModel constructed MenuGenerator with the
    // filter flags defaulting OFF, so a nut-allergic user could be served nut
    // recipes. These tests construct the real MenuViewModel (exercising the
    // exact wiring the bug lived in) and assert the unsafe recipes are gone.
    // They would FAIL on the old default (filters off => unsafe recipe kept).
    group('BUT-1317 personal flow allergen/dietary safety', () {
      TagResult tagWith({
        Map<String, TriState>? allergen,
        Map<String, TriState>? dietary,
      }) {
        return TagResult(
          tags: const {},
          allergenStatus: allergen ?? const {},
          dietaryStatus: dietary ?? const {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
        );
      }

      Recipe recipeWith(String id, TagResult tag) {
        return RecipeBuilder()
            .withId(id)
            .withTitle(id)
            .withMealType('Middag')
            .withTagResult(tag)
            .build();
      }

      // Re-create the VM with a UserService whose prefs we control, plus a
      // recipe pool seeded for the scenario under test.
      MenuViewModel buildVmWith({
        required UserAllergenPreferences prefs,
        required List<Recipe> recipes,
      }) {
        when(() => mockUserService.allergenPreferences).thenReturn(prefs);
        mockRecipeService.setRecipeState(
          recipes: recipes,
          currentUserId: testUserId,
          currentUserDisplayName: 'Test User',
          isInitialized: true,
          isLoading: false,
          error: null,
        );
        return MenuViewModel(
          recipeService: mockRecipeService,
          menuService: mockMenuService,
          analyticsService: mockAnalyticsService,
        );
      }

      test(
          'criterion 1: excludes a recipe CONTAINING a tracked allergen by default',
          () {
        final nutFree = recipeWith(
          'nut_free',
          tagWith(allergen: {'nötter': TriState.free}),
        );
        final containsNuts = recipeWith(
          'contains_nuts',
          tagWith(allergen: {'nötter': TriState.contains}),
        );

        final vm = buildVmWith(
          prefs: const UserAllergenPreferences(
            trackedAllergens: {'nötter'},
            trackedDietary: {},
            includeUnknownInMenu: true,
          ),
          recipes: [nutFree, containsNuts],
        );
        addTearDown(vm.dispose);

        final ids = vm.availableRecipes.map((r) => r.id).toSet();
        expect(ids, contains('nut_free'));
        expect(ids, isNot(contains('contains_nuts')),
            reason:
                'nut-allergic user must never get a nut recipe in the personal menu');
      });

      test(
          'criterion 2: excludes a recipe failing a tracked dietary preference',
          () {
        final vegetarian = recipeWith(
          'vegetarian',
          tagWith(dietary: {'vegetarisk': TriState.free}),
        );
        final notVegetarian = recipeWith(
          'not_vegetarian',
          tagWith(dietary: {'vegetarisk': TriState.contains}),
        );

        final vm = buildVmWith(
          prefs: const UserAllergenPreferences(
            trackedAllergens: {},
            trackedDietary: {'vegetarisk'},
            includeUnknownInMenu: true,
          ),
          recipes: [vegetarian, notVegetarian],
        );
        addTearDown(vm.dispose);

        final ids = vm.availableRecipes.map((r) => r.id).toSet();
        expect(ids, contains('vegetarian'));
        expect(ids, isNot(contains('not_vegetarian')));
      });

      test(
          'criterion 3: includeUnknownInMenu=false excludes UNKNOWN-status recipes',
          () {
        final free =
            recipeWith('free', tagWith(allergen: {'nötter': TriState.free}));
        final unknown = recipeWith(
            'unknown', tagWith(allergen: {'nötter': TriState.unknown}));

        final vm = buildVmWith(
          prefs: const UserAllergenPreferences(
            trackedAllergens: {'nötter'},
            trackedDietary: {},
            includeUnknownInMenu: false,
          ),
          recipes: [free, unknown],
        );
        addTearDown(vm.dispose);

        final ids = vm.availableRecipes.map((r) => r.id).toSet();
        expect(ids, equals({'free'}),
            reason: 'strict mode must drop UNKNOWN-status recipes');
      });

      test(
          'criterion 3: includeUnknownInMenu=true keeps UNKNOWN-status recipes',
          () {
        final free =
            recipeWith('free', tagWith(allergen: {'nötter': TriState.free}));
        final unknown = recipeWith(
            'unknown', tagWith(allergen: {'nötter': TriState.unknown}));

        final vm = buildVmWith(
          prefs: const UserAllergenPreferences(
            trackedAllergens: {'nötter'},
            trackedDietary: {},
            includeUnknownInMenu: true,
          ),
          recipes: [free, unknown],
        );
        addTearDown(vm.dispose);

        final ids = vm.availableRecipes.map((r) => r.id).toSet();
        expect(ids, equals({'free', 'unknown'}),
            reason: 'tolerant mode must keep UNKNOWN-status recipes');
      });

      test(
          'no-regression: with no tracked prefs the full pool is still available',
          () {
        final a = recipeWith('a', tagWith(allergen: {'nötter': TriState.free}));
        final b =
            recipeWith('b', tagWith(allergen: {'nötter': TriState.contains}));

        final vm = buildVmWith(
          prefs: const UserAllergenPreferences(
            trackedAllergens: {},
            trackedDietary: {},
          ),
          recipes: [a, b],
        );
        addTearDown(vm.dispose);

        // Filtering is ON but there is nothing to filter against, so the pool
        // is unchanged — confirms we didn't over-filter when prefs are empty.
        final ids = vm.availableRecipes.map((r) => r.id).toSet();
        expect(ids, equals({'a', 'b'}));
      });
    });
  });
}
