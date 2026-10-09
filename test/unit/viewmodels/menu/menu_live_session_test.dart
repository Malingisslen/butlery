/// MenuLiveSession and MenuViewModel in live mode (BUT-1499): a shared menu
/// in realtime_resources opens on the weekly-menu screen, edits are written
/// to it, and the user's personal draft never captures it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/analytics/trackers/menu_events_tracker.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/weekly_menu_draft_store.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/menu_live_session.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/own_preferences_stub.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockService extends Mock implements RealtimeMenuService {}

class _MockMenuService extends Mock implements MenuService {}

class _FakeLiveMenu extends Fake implements RealtimeMenu {}

/// The watching view model's edge: what it holds is set by the test.
class _FakeRealtimeVm extends ChangeNotifier
    with Fake
    implements RealtimeMenuViewModel {
  RealtimeMenu? menu;
  Map<String, List<Recipe>> snapshot = {};
  bool editable = true;
  final List<String> watched = [];
  int stopped = 0;
  int disposed = 0;

  @override
  RealtimeMenu? get currentMenu => menu;

  @override
  Map<String, List<Recipe>> get menuWithOptimisticChanges => snapshot;

  @override
  bool get canEdit => menu != null && editable;

  @override
  Future<void> startWatching(String menuId) async => watched.add(menuId);

  @override
  Future<void> stopWatching() async => stopped++;

  void deliver(Map<String, List<Recipe>> next, {bool canEdit = true}) {
    menu = _FakeLiveMenu();
    snapshot = next;
    editable = canEdit;
    notifyListeners();
  }

  @override
  void dispose() {
    if (disposed++ == 0) super.dispose();
  }
}

class _Analytics extends Fake implements AnalyticsService {
  final MockMenuEventsTracker _menu = MockMenuEventsTracker();

  @override
  MenuEventsTracker get menu => _menu;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

Recipe _dinner(String id) =>
    RecipeBuilder().withId(id).withTitle(id).withMealType('Middag').build();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final soup = _dinner('soup');
  final stew = _dinner('stew');
  final pie = _dinner('pie');

  late _FakeRealtimeVm realtime;
  late _MockService service;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    prod.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(soup);
    registerFallbackValue(MenuScoringContext.empty);
    registerFallbackValue(const <String>{});
    registerFallbackValue(<Recipe>[]);
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    realtime = _FakeRealtimeVm();
    service = _MockService();
    when(
      () => service.replaceRecipeInCategory(
        resourceId: any(named: 'resourceId'),
        categoryName: any(named: 'categoryName'),
        recipeIndex: any(named: 'recipeIndex'),
        newRecipe: any(named: 'newRecipe'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => service.updateWholeCategory(
        resourceId: any(named: 'resourceId'),
        categoryName: any(named: 'categoryName'),
        recipes: any(named: 'recipes'),
      ),
    ).thenAnswer((_) async {});
  });

  group('MenuLiveSession', () {
    late List<Map<String, List<Recipe>>> pushed;
    late MenuLiveSession session;

    setUp(() {
      pushed = [];
      session = MenuLiveSession(
        onMenu: pushed.add,
        realtime: realtime,
        service: service,
      );
    });

    test('is not live and cannot edit before it starts', () {
      expect(session.isLive, isFalse);
      expect(session.resourceId, isNull);
      expect(session.canEdit, isFalse);
    });

    test('watches the id, cannot edit until the menu has loaded, then '
        'pushes every change', () async {
      await session.start('m1');

      expect(realtime.watched, ['m1']);
      expect(session.isLive, isTrue);
      expect(session.resourceId, 'm1');
      expect(session.canEdit, isFalse, reason: 'nothing has loaded yet');
      expect(pushed, isEmpty);

      realtime.deliver({
        'Middag': [soup],
      });
      expect(session.canEdit, isTrue);
      expect(pushed.single['Middag'], [soup]);

      realtime.deliver({
        'Middag': [stew],
      }, canEdit: false);
      expect(session.canEdit, isFalse, reason: 'a viewer');
      expect(pushed.last['Middag'], [stew]);
    });

    test('writes a dish and a whole section to the resource', () async {
      await session.start('m1');

      await session.replaceRecipe('Middag', 2, stew);
      await session.writeSection('Middag', [soup, pie]);

      verify(
        () => service.replaceRecipeInCategory(
          resourceId: 'm1',
          categoryName: 'Middag',
          recipeIndex: 2,
          newRecipe: stew,
        ),
      ).called(1);
      verify(
        () => service.updateWholeCategory(
          resourceId: 'm1',
          categoryName: 'Middag',
          recipes: [soup, pie],
        ),
      ).called(1);
    });

    test('stop stops watching and ignores later changes', () async {
      await session.start('m1');
      await session.stop();

      expect(realtime.stopped, 1);
      expect(session.isLive, isFalse);
      realtime.deliver({
        'Middag': [soup],
      });
      expect(pushed, isEmpty);
    });

    test(
      'dispose stops watching and disposes the realtime view model',
      () async {
        await session.start('m1');
        session.dispose();
        await pumpEventQueue();

        expect(realtime.stopped, 1);
        expect(realtime.disposed, 1);
      },
    );
  });

  group('MenuViewModel in live mode', () {
    late MenuViewModel vm;
    late _MockMenuService menuService;
    late MockUnifiedRecipeService recipes;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      menuService = _MockMenuService();
      recipes = MockFactory.createUnifiedRecipeService()
        ..setRecipeState(
          recipes: [soup, stew, pie],
          currentUserId: 'u1',
          currentUserDisplayName: 'T',
          isInitialized: true,
          isLoading: false,
          error: null,
        );
      final users = MockUserService();
      stubOwnPreferences(
        users,
        const UserAllergenPreferences(
          trackedAllergens: {},
          trackedDietary: {},
        ),
      );
      final analytics = _Analytics();
      TestServiceLocator.registerMock<UserService>(users);
      TestServiceLocator.registerMock<UnifiedRecipeService>(recipes);
      TestServiceLocator.registerMock<MenuService>(menuService);
      TestServiceLocator.registerMock<AnalyticsService>(analytics);
      when(
        () => menuService.generateMenuFromPrompt(
          any(),
          any(),
          recentlyUsedRecipeIds: any(named: 'recentlyUsedRecipeIds'),
          scoringContext: any(named: 'scoringContext'),
        ),
      ).thenAnswer(
        (_) async => {
          'Middag': [pie],
        },
      );
      vm = MenuViewModel(
        recipeService: recipes,
        menuService: menuService,
        analyticsService: analytics,
        draftOwnerId: () => 'u1',
        liveSessionFactory: (sink) =>
            MenuLiveSession(onMenu: sink, realtime: realtime, service: service),
      );
    });

    var vmDisposed = false;
    tearDown(() {
      if (!vmDisposed) vm.dispose();
      vmDisposed = false;
    });

    Future<void> openLive({bool canEdit = true}) async {
      await vm.startLiveMenu('m1');
      realtime.deliver({
        'Middag': [soup],
      }, canEdit: canEdit);
    }

    Future<String?> storedDraft() async {
      await pumpEventQueue();
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(WeeklyMenuDraftStore.keyFor('u1'));
    }

    test('a personal menu is always editable', () {
      expect(vm.isLiveMenu, isFalse);
      expect(vm.liveMenuId, isNull);
      expect(vm.canEditMenu, isTrue);
    });

    test('shows the live menu and follows it', () async {
      await vm.startLiveMenu('m1');
      expect(vm.isLiveMenu, isTrue);
      expect(vm.liveMenuId, 'm1');
      expect(vm.canEditMenu, isFalse, reason: 'not loaded yet');

      realtime.deliver({
        'Middag': [soup],
      });
      expect(vm.menu['Middag'], [soup]);
      expect(vm.canEditMenu, isTrue);

      realtime.deliver({
        'Middag': [stew],
      });
      expect(vm.menu['Middag'], [stew]);
    });

    test('swap writes the replacement at the dish index', () async {
      await vm.startLiveMenu('m1');
      realtime.deliver({
        'Middag': [pie, soup],
      });

      final result = await vm.swapRecipe(soup, 'Middag');

      expect(result.recipe, isNotNull);
      verify(
        () => service.replaceRecipeInCategory(
          resourceId: 'm1',
          categoryName: 'Middag',
          recipeIndex: 1,
          newRecipe: result.recipe!,
        ),
      ).called(1);
      expect(vm.hasError, isFalse);
    });

    test('regenerate writes the new section', () async {
      await openLive();

      await vm.regenerateSection('Middag');

      final written =
          verify(
                () => service.updateWholeCategory(
                  resourceId: 'm1',
                  categoryName: 'Middag',
                  recipes: captureAny(named: 'recipes'),
                ),
              ).captured.single
              as List<Recipe>;
      expect(written.map((r) => r.id), ['pie']);
    });

    test('a viewer can neither swap nor regenerate', () async {
      await openLive(canEdit: false);

      final result = await vm.swapRecipe(soup, 'Middag');
      await vm.regenerateSection('Middag');

      expect(result.recipe, isNull);
      expect(vm.menu['Middag'], [soup]);
      verifyNever(
        () => service.replaceRecipeInCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipeIndex: any(named: 'recipeIndex'),
          newRecipe: any(named: 'newRecipe'),
        ),
      );
      verifyNever(
        () => service.updateWholeCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipes: any(named: 'recipes'),
        ),
      );
      verifyNever(
        () => menuService.generateMenuFromPrompt(
          any(),
          any(),
          recentlyUsedRecipeIds: any(named: 'recentlyUsedRecipeIds'),
          scoringContext: any(named: 'scoringContext'),
        ),
      );
    });

    test('a failed swap puts the old dish back and shows the error', () async {
      when(
        () => service.replaceRecipeInCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipeIndex: any(named: 'recipeIndex'),
          newRecipe: any(named: 'newRecipe'),
        ),
      ).thenThrow(Exception('boom'));
      await openLive();

      await vm.swapRecipe(soup, 'Middag');

      expect(vm.menu['Middag'], [soup]);
      expect(vm.hasError, isTrue);
    });

    test('a failed section write shows the error', () async {
      when(
        () => service.updateWholeCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipes: any(named: 'recipes'),
        ),
      ).thenThrow(Exception('boom'));
      await openLive();

      await vm.regenerateSection('Middag');

      expect(vm.hasError, isTrue);
      expect(vm.menu['Middag'], [soup]);
      expect(vm.isGenerating, isFalse);
    });

    test('records no personal draft, even after a generated menu', () async {
      await vm.generateMenu('en middag');
      final before = await storedDraft();
      expect(before, contains('pie'), reason: 'the draft is being tracked');
      await openLive();

      await vm.swapRecipe(soup, 'Middag');
      await vm.regenerateSection('Middag');

      expect(await storedDraft(), before);
    });

    test('putting another menu on screen ends the live session, so a swap '
        'no longer writes to the shared menu', () async {
      await openLive();

      vm.loadFromSharedMenu(
        SharedMenu(
          id: 's1',
          sharedByUserId: 'u2',
          sharedByDisplayName: 'A',
          menuTitle: 'Annan',
          menuSnapshot: {
            'Middag': [stew],
          },
        ),
      );
      await pumpEventQueue();

      expect(vm.isLiveMenu, isFalse);
      expect(realtime.stopped, 1);

      final result = await vm.swapRecipe(stew, 'Middag');
      expect(result.recipe, isNotNull);
      verifyNever(
        () => service.replaceRecipeInCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipeIndex: any(named: 'recipeIndex'),
          newRecipe: any(named: 'newRecipe'),
        ),
      );

      final shown = vm.menu['Middag'];
      realtime.deliver({
        'Middag': [soup],
      });
      expect(vm.menu['Middag'], same(shown));
    });

    test('dispose stops watching', () async {
      await openLive();

      vm.dispose();
      vmDisposed = true;
      await pumpEventQueue();

      expect(realtime.stopped, 1);
      expect(realtime.disposed, 1);
    });
  });
}
