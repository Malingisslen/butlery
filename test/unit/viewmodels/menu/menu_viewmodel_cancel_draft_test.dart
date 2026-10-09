/// BUT-2157 on the real MenuViewModel.
///
/// Avbryt planeringen: the call returns at once, a result that lands later
/// is dropped, the earlier suggestion comes back, and an old run's ending
/// never ends a newer run. The draft: written after a generation and its
/// edits, never for a loaded menu or a cancelled run, deleted at clear and
/// save, and restored only through the allergen-safe household pool.
///
/// The fakes sit at the edges: MenuService (the computation, held open by a
/// Completer), the recipe library, the user's settings, analytics and
/// SharedPreferences.
library;

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_draft.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/analytics/trackers/menu_events_tracker.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

/// The computation edge: [hold] keeps a call open until the test completes
/// it; each call returns what [next] holds at the moment it is answered.
class _HeldMenuService extends Mock implements MenuService {
  Map<String, List<Recipe>> next = const {};
  Completer<void>? hold;
  int calls = 0;

  @override
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String input,
    List<Recipe> allRecipes, {
    Set<String> recentlyUsedRecipeIds = const {},
    MenuScoringContext scoringContext = MenuScoringContext.empty,
  }) async {
    calls++;
    final gate = hold;
    final answer = next;
    if (gate != null) await gate.future;
    return answer;
  }

  @override
  Future<ParsedMenuRequest?> parsePrompt(String input) async => null;
}

class _Analytics extends Fake implements AnalyticsService {
  final MockMenuEventsTracker _menu = MockMenuEventsTracker();
  final List<String> events = [];

  /// Holds the success log open, which is after the menu is on screen.
  Completer<void>? holdGenerated;

  @override
  MenuEventsTracker get menu => _menu;

  @override
  Future<void> logMenuGenerated({
    required int recipeCount,
    required String method,
  }) async {
    final gate = holdGenerated;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async => events.add(name);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

Recipe _dinner(String id, {TagResult? tags}) {
  final builder = RecipeBuilder()
      .withId(id)
      .withTitle(id)
      .withMealType(
        'Middag',
      );
  return (tags == null ? builder : builder.withTagResult(tags)).build();
}

Recipe _dish(String id, String title) => RecipeBuilder()
    .withId(id)
    .withTitle(title)
    .withMealType('Middag')
    .withTagResult(_nuts(TriState.free))
    .build();

TagResult _nuts(TriState status) => TagResult(
  tags: const {},
  allergenStatus: {'nötter': status},
  dietaryStatus: const {},
  coverage: 1.0,
  generatedAt: DateTime(2026, 10, 1),
  generatorVersion: kTagGeneratorVersion,
);

const _noPrefs = UserAllergenPreferences(
  trackedAllergens: {},
  trackedDietary: {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HeldMenuService menuService;
  late MockUnifiedRecipeService recipes;
  late MockUserService users;
  late _Analytics analytics;
  late MenuViewModel vm;

  final nutCake = _dinner('nut-cake', tags: _nuts(TriState.free));
  final soup = _dinner('soup', tags: _nuts(TriState.free));
  final stew = _dinner('stew', tags: _nuts(TriState.free));

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(
      SharedMenu.create(
        sharedByUserId: 'u1',
        sharedByDisplayName: 'T',
        sharedToUserIds: const ['f'],
        menuTitle: 'F',
        menuSnapshot: const {},
        shareMessage: '',
      ),
    );
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    menuService = _HeldMenuService();
    recipes = MockFactory.createUnifiedRecipeService()
      ..setRecipeState(
        recipes: [nutCake, soup, stew],
        currentUserId: 'u1',
        currentUserDisplayName: 'T',
        isInitialized: true,
        isLoading: false,
        error: null,
      );
    users = MockUserService();
    stubOwnPreferences(users, _noPrefs);
    when(() => users.attributionDisplayName).thenReturn('T');
    analytics = _Analytics();
    TestServiceLocator.registerMock<UserService>(users);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipes);
    TestServiceLocator.registerMock<MenuService>(menuService);
    TestServiceLocator.registerMock<AnalyticsService>(analytics);
    vm = MenuViewModel(
      recipeService: recipes,
      menuService: menuService,
      analyticsService: analytics,
    );
  });

  tearDown(() => vm.dispose());

  Future<WeeklyMenuDraft?> storedDraftObject() async {
    await pumpEventQueue();
    return WeeklyMenuDraftStore().load('u1');
  }

  Future<String?> storedDraft() async {
    await pumpEventQueue();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(WeeklyMenuDraftStore.keyFor('u1'));
  }

  /// Past the generator's own short wait, into the held computation.
  Future<void> reachComputation() =>
      Future<void>.delayed(const Duration(milliseconds: 400));

  Future<void> generate(String prompt, Map<String, List<Recipe>> menu) async {
    menuService.next = menu;
    expect(await vm.generateMenu(prompt), MenuGenerationEnd.completed);
  }

  group('Avbryt planeringen', () {
    test('returns at once, drops the late result and brings the earlier '
        'suggestion back', () async {
      await generate('en middag', {
        'Middag': [soup],
      });

      menuService
        ..next = {
          'Middag': [stew],
        }
        ..hold = Completer<void>();
      final run = vm.generateMenu('en annan middag');
      await reachComputation();
      expect(vm.isGenerating, isTrue);
      expect(menuService.calls, 2, reason: 'the run reached the computation');

      vm.cancelGeneration();

      expect(vm.isGenerating, isFalse);
      expect(await run, MenuGenerationEnd.cancelled);
      expect(vm.menu['Middag'], [soup]);
      expect(vm.lastPrompt, 'en middag');
      expect(analytics.events, contains('menu_generation_cancelled'));

      menuService.hold!.complete();
      await pumpEventQueue();
      expect(vm.menu['Middag'], [soup], reason: 'the late result is dropped');
      expect(await storedDraft(), contains('soup'));
      expect(await storedDraft(), isNot(contains('stew')));
    });

    test('a cancel after the menu is on screen still cancels: nothing is '
        'kept as the draft and the run is not reported done', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      final before = await storedDraft();

      menuService.next = {
        'Middag': [stew],
      };
      analytics.holdGenerated = Completer<void>();
      final run = vm.generateMenu('en annan middag');
      await reachComputation();
      expect(vm.menu['Middag'], [stew], reason: 'the run set its menu');
      expect(vm.isGenerating, isTrue);

      vm.cancelGeneration();
      analytics.holdGenerated!.complete();

      expect(await run, MenuGenerationEnd.cancelled);
      expect(vm.menu['Middag'], [soup]);
      expect(await storedDraft(), before);
    });

    test('a cancel before the computation never computes', () async {
      final run = vm.generateMenu('en middag');
      vm.cancelGeneration();

      expect(await run, MenuGenerationEnd.cancelled);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(menuService.calls, 0);
      expect(vm.hasMenu, isFalse);
      expect(await storedDraft(), isNull);
    });

    test("the old run's ending does not end a newer run", () async {
      menuService
        ..next = {
          'Middag': [soup],
        }
        ..hold = Completer<void>();
      final first = vm.generateMenu('en middag');
      await reachComputation();
      expect(menuService.calls, 1);
      vm.cancelGeneration();
      final firstHold = menuService.hold!;

      menuService
        ..next = {
          'Middag': [stew],
        }
        ..hold = Completer<void>();
      final second = vm.generateMenu('en annan middag');
      await reachComputation();
      expect(menuService.calls, 2);

      firstHold.complete();
      expect(await first, MenuGenerationEnd.cancelled);
      await pumpEventQueue();
      expect(vm.isGenerating, isTrue, reason: 'the second run is still busy');

      menuService.hold!.complete();
      expect(await second, MenuGenerationEnd.completed);
      expect(vm.isGenerating, isFalse);
      expect(vm.menu['Middag'], [stew]);
    });

    test('a cancelled re-roll keeps the section as it was', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      menuService
        ..next = {
          'Middag': [stew],
        }
        ..hold = Completer<void>();

      final reroll = vm.regenerateSection('Middag');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      vm.cancelGeneration();
      menuService.hold!.complete();
      await reroll;

      expect(vm.isGenerating, isFalse);
      expect(vm.menu['Middag'], [soup]);
    });

    test('closing the screen mid-run ends it without touching the '
        'disposed state', () async {
      menuService.hold = Completer<void>();
      final run = vm.generateMenu('en middag');
      await reachComputation();

      vm.dispose();
      expect(await run, MenuGenerationEnd.cancelled);
      menuService.hold!.complete();
      await pumpEventQueue();

      // tearDown disposes again; rebuild so it has a live one.
      vm = MenuViewModel(
        recipeService: recipes,
        menuService: menuService,
        analyticsService: analytics,
      );
    });
  });

  group('the pool hint after a cancel', () {
    const trackNuts = UserAllergenPreferences(
      trackedAllergens: {'nötter'},
      trackedDietary: {},
    );
    final nutCakeBlocked = _dinner('nut-cake', tags: _nuts(TriState.contains));
    final nutBunBlocked = _dinner('nut-bun', tags: _nuts(TriState.contains));

    void library(List<Recipe> all) => recipes.setRecipeState(
      recipes: all,
      currentUserId: 'u1',
      currentUserDisplayName: 'T',
      isInitialized: true,
      isLoading: false,
      error: null,
    );

    setUp(() {
      stubOwnPreferences(users, trackNuts);
      library([nutCakeBlocked, soup, stew]);
    });

    test('a cancelled run gives back the hidden count of the suggestion '
        'that stays on screen', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      expect(vm.hiddenByFamilyCount, 1);

      // The second run reads a pool where two recipes are hidden.
      library([nutCakeBlocked, nutBunBlocked, soup, stew]);
      menuService
        ..next = {
          'Middag': [stew],
        }
        ..hold = Completer<void>();
      final run = vm.generateMenu('en annan middag');
      await reachComputation();
      expect(
        vm.hiddenByFamilyCount,
        2,
        reason: 'the cancelled run read its own pool before it was cancelled',
      );

      vm.cancelGeneration();

      expect(await run, MenuGenerationEnd.cancelled);
      expect(vm.menu['Middag'], [soup]);
      expect(vm.hiddenByFamilyCount, 1);
      menuService.hold!.complete();
    });

    test('clearing the menu forgets the hidden count', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      expect(vm.hiddenByFamilyCount, 1);

      vm.clearMenu();

      expect(vm.hiddenByFamilyCount, 0);
    });

    test('loading a saved menu forgets the hidden count of the generated '
        'one', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      expect(vm.hiddenByFamilyCount, 1);
      expect(await vm.saveMenuWithNameAndComment('Veckan', ''), isTrue);
      final saved = await prod.ServiceLocator.get<FirestoreRepository>()
          .collection(FirestoreCollections.menus)
          .get();
      expect(saved.docs, isNotEmpty);

      expect(await vm.loadSavedMenu(saved.docs.first.id), isTrue);

      expect(vm.menu['Middag']!.map((r) => r.id), ['soup']);
      expect(vm.hiddenByFamilyCount, 0);
    });
  });

  group('the cancel event', () {
    test('goes through the analytics service the view model was given, '
        'not the one in the locator', () async {
      final injected = _Analytics();
      vm.dispose();
      vm = MenuViewModel(
        recipeService: recipes,
        menuService: menuService,
        analyticsService: injected,
      );
      menuService.hold = Completer<void>();
      final run = vm.generateMenu('en middag');
      await reachComputation();

      vm.cancelGeneration();

      expect(await run, MenuGenerationEnd.cancelled);
      expect(injected.events, [AnalyticsEvents.menuGenerationCancelled]);
      expect(
        analytics.events,
        isNot(contains(AnalyticsEvents.menuGenerationCancelled)),
      );
      menuService.hold!.complete();
    });
  });

  group('the draft', () {
    test('a generation is kept as the draft; a swap updates it', () async {
      await generate('två middagar', {
        'Middag': [soup, nutCake],
      });
      expect(
        await storedDraft(),
        allOf(contains('soup'), contains('nut-cake')),
      );

      final swapped = await vm.swapRecipe(nutCake, 'Middag');
      expect(swapped.recipe, stew);
      expect(
        await storedDraft(),
        allOf(contains('stew'), isNot(contains('nut'))),
      );
    });

    test('a section re-roll updates the draft', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      expect(await storedDraft(), contains('soup'));

      menuService.next = {
        'Middag': [stew],
      };
      await vm.regenerateSection('Middag');

      expect(vm.menu['Middag'], [stew]);
      expect(
        await storedDraft(),
        allOf(contains('stew'), isNot(contains('soup'))),
      );
    });

    test('saving the menu under a name deletes the draft', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      expect(await storedDraft(), isNotNull);

      expect(await vm.saveMenuWithNameAndComment('Veckan', ''), isTrue);

      expect(await storedDraft(), isNull);
    });

    test('a loaded shared menu is never written, even after a '
        'generation', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      final generated = await storedDraft();
      expect(generated, contains('soup'));

      vm.loadFromSharedMenu(
        SharedMenu.create(
          sharedByUserId: 'f',
          sharedByDisplayName: 'F',
          sharedToUserIds: const ['u1'],
          menuTitle: 'Delad',
          menuSnapshot: {
            'Middag': [nutCake],
          },
          shareMessage: '',
        ),
      );
      final swapped = await vm.swapRecipe(nutCake, 'Middag');
      expect(swapped.recipe, isNotNull);

      expect(await storedDraft(), generated);
    });

    test('clearing the menu and placing it delete the draft', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      expect(await storedDraft(), isNotNull);
      vm.clearMenu();
      expect(await storedDraft(), isNull);

      await generate('en middag', {
        'Middag': [soup],
      });
      expect(await storedDraft(), isNotNull);
      await vm.markDraftSaved();
      expect(await storedDraft(), isNull);
    });

    test('restore drops and counts a dish that is now unsafe for the '
        'household and one that was deleted', () async {
      final gone = _dinner('gone', tags: _nuts(TriState.free));
      recipes.setRecipeState(
        recipes: [nutCake, soup, stew, gone],
        currentUserId: 'u1',
        currentUserDisplayName: 'T',
        isInitialized: true,
        isLoading: false,
        error: null,
      );
      await generate('fyra middagar', {
        'Middag': [nutCake, soup, gone, stew],
      });
      await pumpEventQueue();
      vm.dispose();

      // Since then: the cake is tagged with nuts, the household tracks nuts,
      // and "gone" was deleted.
      final nutCakeNow = _dinner('nut-cake', tags: _nuts(TriState.contains));
      recipes.setRecipeState(
        recipes: [nutCakeNow, soup, stew],
        currentUserId: 'u1',
        currentUserDisplayName: 'T',
        isInitialized: true,
        isLoading: false,
        error: null,
      );
      stubOwnPreferences(
        users,
        const UserAllergenPreferences(
          trackedAllergens: {'nötter'},
          trackedDietary: {},
        ),
      );
      vm = MenuViewModel(
        recipeService: recipes,
        menuService: menuService,
        analyticsService: analytics,
      );

      await vm.checkForDraft();
      expect(vm.pendingDraft?.recipeCount, 4);

      final dropped = await vm.restoreDraft();

      expect(dropped, 2);
      expect(vm.menu['Middag']!.map((r) => r.id), ['soup', 'stew']);
      expect(vm.lastPrompt, 'fyra middagar');
      expect(vm.pendingDraft, isNull);
    });

    test('a draft with nothing safe left is deleted on restore', () async {
      // An earlier session kept a one-dish draft.
      await WeeklyMenuDraftStore().save(
        'u1',
        WeeklyMenuDraft(
          prompt: 'en middag',
          recipeIdsByMealType: const {
            'Middag': ['nut-cake'],
          },
          requestedByMealType: const {'middag': 1},
          lastModifiedAt: clock.now(),
        ),
      );
      // Since then the cake carries nuts and the household tracks nuts.
      stubOwnPreferences(
        users,
        const UserAllergenPreferences(
          trackedAllergens: {'nötter'},
          trackedDietary: {},
        ),
      );
      recipes.setRecipeState(
        recipes: [
          _dinner('nut-cake', tags: _nuts(TriState.contains)),
          soup,
        ],
        currentUserId: 'u1',
        currentUserDisplayName: 'T',
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      await vm.checkForDraft();
      expect(await vm.restoreDraft(), 1);
      expect(vm.hasMenu, isFalse);
      expect(await storedDraft(), isNull);
    });

    test('a discard committed after a newer generation leaves the newer '
        'draft', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      await pumpEventQueue();
      vm.dispose();
      vm = MenuViewModel(
        recipeService: recipes,
        menuService: menuService,
        analyticsService: analytics,
      );
      await vm.checkForDraft();
      final hidden = vm.hideDraft()!;
      expect(vm.pendingDraft, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await generate('en annan middag', {
        'Middag': [stew],
      });
      await pumpEventQueue();
      await vm.discardDraft(hidden);

      expect(await storedDraft(), contains('stew'));
    });

    test('a discard of the offered draft deletes it; undo offers it '
        'again', () async {
      await generate('en middag', {
        'Middag': [soup],
      });
      await pumpEventQueue();
      vm.dispose();
      vm = MenuViewModel(
        recipeService: recipes,
        menuService: menuService,
        analyticsService: analytics,
      );
      await vm.checkForDraft();

      final hidden = vm.hideDraft()!;
      vm.undoDiscardDraft(hidden);
      expect(vm.pendingDraft, same(hidden));

      vm.hideDraft();
      await vm.discardDraft(hidden);
      expect(await storedDraft(), isNull);
    });
  });

  group('the draft carries dish names for the resume card', () {
    final soupDish = _dish('r-soup', 'Ärtsoppa');
    final stewDish = _dish('r-stew', 'Oxgryta');
    final nameless = _dish('r-nameless', '');

    setUp(() {
      recipes.setRecipeState(
        recipes: [soupDish, stewDish, nameless],
        currentUserId: 'u1',
        currentUserDisplayName: 'T',
        isInitialized: true,
        isLoading: false,
        error: null,
      );
    });

    test('a generation keeps the title of each recorded dish under its id '
        'and leaves out an empty title', () async {
      await generate('tre middagar', {
        'Middag': [soupDish, nameless, stewDish],
      });

      final draft = await storedDraftObject();

      expect(draft!.recipeNames, {'r-soup': 'Ärtsoppa', 'r-stew': 'Oxgryta'});
      expect(
        draft.recipeIdsByMealType['Middag'],
        [
          'r-soup',
          'r-nameless',
          'r-stew',
        ],
        reason: 'the nameless dish is still in the draft, only unnamed',
      );

      // The reader drops an empty name too, so only the stored JSON can say
      // the writer left it out.
      final stored = jsonDecode((await storedDraft())!) as Map<String, Object?>;
      expect(stored['names'], {'r-soup': 'Ärtsoppa', 'r-stew': 'Oxgryta'});
    });

    test('a swap rewrites the names to the dishes now in the menu', () async {
      recipes.setRecipeState(
        recipes: [soupDish, stewDish],
        currentUserId: 'u1',
        currentUserDisplayName: 'T',
        isInitialized: true,
        isLoading: false,
        error: null,
      );
      await generate('en middag', {
        'Middag': [soupDish],
      });
      expect((await storedDraftObject())!.recipeNames, {
        'r-soup': 'Ärtsoppa',
      });

      final swapped = await vm.swapRecipe(soupDish, 'Middag');
      expect(swapped.recipe, stewDish);

      expect((await storedDraftObject())!.recipeNames, {
        'r-stew': 'Oxgryta',
      });
    });

    test('a restore that dropped a dish writes back the names of the kept '
        'ones only', () async {
      await generate('två middagar', {
        'Middag': [soupDish, stewDish],
      });
      await pumpEventQueue();
      vm.dispose();

      // The stew was deleted since.
      recipes.setRecipeState(
        recipes: [soupDish, nameless],
        currentUserId: 'u1',
        currentUserDisplayName: 'T',
        isInitialized: true,
        isLoading: false,
        error: null,
      );
      vm = MenuViewModel(
        recipeService: recipes,
        menuService: menuService,
        analyticsService: analytics,
      );
      await vm.checkForDraft();
      expect(vm.pendingDraft!.recipeNames, {
        'r-soup': 'Ärtsoppa',
        'r-stew': 'Oxgryta',
      });

      expect(await vm.restoreDraft(), 1);

      final rewritten = await storedDraftObject();
      expect(rewritten!.recipeIdsByMealType['Middag'], ['r-soup']);
      expect(rewritten.recipeNames, {'r-soup': 'Ärtsoppa'});
    });
  });
}
