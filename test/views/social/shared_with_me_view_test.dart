/// Behaviour tests for [SharedWithMeView] — the "shared with me" inbox.
///
/// The view resolves its [SharedContentCoordinatorViewModel] from the
/// production [ServiceLocator] in `initState`. We register a mocktail mock of
/// that coordinator through the prod↔test ServiceLocator bridge, drive its
/// public state getters (the same ones `_buildContent` branches on), and
/// assert the user-visible Swedish state the view renders for each.
///
/// The coordinator is the view's SINGLE dependency, so each test pins one
/// state → one rendered outcome (input → output). The tabs and the rows of
/// each kind are covered below the state group.
///
/// Rebuilt for BUT-1180 — replaces a ~25-test ULTRATHINK smoke-suite of
/// `findsOneWidget` / `takeException isNull` structural asserts that threw
/// "ServiceLocator not initialized" because they never wired the bridge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_search_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_tabs.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_lists.dart';
import 'package:butlery/views/social/shared_with_me_view.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/core/constants/routes.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../helpers/view_test_helpers.dart';

// Swedish labels the view renders (from app_sv.arb). Captured here so a
// behaviour regression — not a copy tweak — is what fails the assertion.
const _appBarTitle = 'Delat med mig'; // l10n.profileSharedWithMe
const _loadingText = 'Laddar delat innehåll …'; // l10n.sharedLoadingContent
const _emptyTitle = 'Inga delade recept än'; // l10n.sharedNoContentYet
const _oldEmptyCta = 'Dela ett recept';
const _findFriendsCta = 'Hitta vänner'; // l10n.socialFindFriends
const _retryLabel = 'Försök igen'; // l10n.commonRetry

class _MockSocialRecipeCoordinator extends Mock
    implements SocialRecipeCoordinator {}

void main() {
  late MockSharedContentCoordinatorViewModel coordinator;
  late MockOfflineService offlineService;
  late List<String?> pushedRoutes;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // The view's top sliver is LayoutComponents.offlineIndicator(), whose
    // initState resolves OfflineService and reads `isOnline`. Register an
    // online mock so the indicator builds (collapsed) without exploding.
    offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);

    pushedRoutes = [];
    coordinator = MockSharedContentCoordinatorViewModel();

    // The view's post-frame callback awaits `initialize()` — stub it to a
    // completed Future so the await doesn't trip on a null return.
    when(() => coordinator.initialize()).thenAnswer((_) async {});
    // ChangeNotifierProvider.value subscribes/unsubscribes; the view disposes
    // the VM. These are void no-ops on the mock.
    when(() => coordinator.addListener(any())).thenReturn(null);
    when(() => coordinator.removeListener(any())).thenReturn(null);
    when(() => coordinator.dispose()).thenReturn(null);
    when(() => coordinator.refreshAllContent()).thenAnswer((_) async {});

    // Register through the prod↔test bridge so the view's
    // `ServiceLocator.get<SharedContentCoordinatorViewModel>()` returns OURS.
    TestServiceLocator.registerMock<SharedContentCoordinatorViewModel>(
      coordinator,
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget testApp({Widget home = const SharedWithMeView()}) {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: home,
      onGenerateRoute: (settings) {
        pushedRoutes.add(settings.name);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('route-stub')),
        );
      },
    );
  }

  // Drive the three `_buildContent` branch getters in one place. The search
  // bars short-circuit on `hasAnyContent == false`, so the loading/empty/
  // error states never touch the child specialized ViewModels.
  void stubGlobalState({
    required bool loading,
    required bool hasError,
    String? error,
    required bool hasContent,
  }) {
    when(() => coordinator.isGloballyLoading).thenReturn(loading);
    when(() => coordinator.hasGlobalError).thenReturn(hasError);
    when(() => coordinator.globalError).thenReturn(error);
    when(() => coordinator.hasAnyContent).thenReturn(hasContent);
  }

  // Pump the real view on a tall surface. `mainMenu` introduces a real
  // Scaffold + bottom nav; on a short surface those plus the centred state
  // illustration overflow vertically. The overflow is a layout artifact of
  // the surrounding scaffold, orthogonal to the state-rendering behaviour
  // under test — so we ignore RenderFlex-overflow FlutterErrors ONLY, letting
  // every other error fail the test as normal.
  //
  // [settle] is false for the loading state: its LoadingIndicator wraps a
  // CircularProgressIndicator whose perpetual animation makes pumpAndSettle
  // time out, so we pump discrete frames instead.
  Future<void> pumpView(
    WidgetTester tester, {
    bool settle = true,
    Widget home = const SharedWithMeView(),
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // String-matches the framework's exact 'A RenderFlex overflowed'
      // wording; if a future Flutter SDK rewords it, this filter stops
      // matching and the overflow resurfaces as a failure.
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(testApp(home: home));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Pump twice: once to build, once to flush the post-frame initialize().
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('SharedWithMeView — state rendering', () {
    testWidgets(
      'global loading shows the Swedish loading text and a progress indicator',
      (tester) async {
        stubGlobalState(
          loading: true,
          hasError: false,
          error: null,
          hasContent: false,
        );

        await pumpView(tester, settle: false);

        // The app bar renders regardless of content state.
        expect(find.text(_appBarTitle), findsOneWidget);

        // Loading branch: Swedish copy + the canonical loading indicator.
        expect(find.text(_loadingText), findsOneWidget);
        expect(find.byType(PlateLine), findsOneWidget);

        // Not the empty/error branches.
        expect(find.text(_emptyTitle), findsNothing);
      },
    );

    testWidgets(
      'no content (not loading, no error) shows the empty-state title and '
      'explanation and a Hitta vänner action',
      (tester) async {
        stubGlobalState(
          loading: false,
          hasError: false,
          error: null,
          hasContent: false,
        );

        await pumpView(tester);

        expect(find.text(_emptyTitle), findsOneWidget);
        // The empty-state explanation subtitle renders too.
        expect(
          find.textContaining('När du eller dina vänner delar recept'),
          findsOneWidget,
        );
        // The old "share a recipe" button that led to Hem is gone.
        expect(find.text(_oldEmptyCta), findsNothing);
        expect(find.text(_findFriendsCta), findsOneWidget);

        // The loading indicator is gone in the empty state.
        expect(find.byType(PlateLine), findsNothing);
      },
    );

    testWidgets('the Hitta vänner action on the empty state opens the friends '
        'page', (tester) async {
      stubGlobalState(
        loading: false,
        hasError: false,
        error: null,
        hasContent: false,
      );

      await pumpView(tester);
      await tester.tap(find.text(_findFriendsCta));
      await tester.pumpAndSettle();

      expect(pushedRoutes, [Routes.friends]);
    });

    testWidgets('global error shows the error message and a retry action', (
      tester,
    ) async {
      const errorMessage = 'Kunde inte ladda delat innehåll';
      stubGlobalState(
        loading: false,
        hasError: true,
        error: errorMessage,
        hasContent: false,
      );

      await pumpView(tester);

      // The error branch surfaces the coordinator's globalError verbatim.
      expect(find.text(errorMessage), findsOneWidget);
      // A retry action is offered (StateWidget.error resolves a Retry label
      // because onAction == refreshAllContent is non-null).
      expect(find.text(_retryLabel), findsOneWidget);

      // Not the empty or loading branches.
      expect(find.text(_emptyTitle), findsNothing);
      expect(find.byType(PlateLine), findsNothing);
    });

    testWidgets(
      'tapping retry in the error state invokes refreshAllContent on the coordinator',
      (tester) async {
        stubGlobalState(
          loading: false,
          hasError: true,
          error: 'Något gick fel',
          hasContent: false,
        );

        await pumpView(tester);

        await tester.tap(find.text(_retryLabel));
        await tester.pumpAndSettle();

        verify(() => coordinator.refreshAllContent()).called(1);
      },
    );
  });

  group('SharedWithMeView — tabs', () {
    testWidgets('Recept, Menyer and Listor are offered with their counts, '
        'Recept first', (tester) async {
      stubGlobalState(
        loading: false,
        hasError: false,
        error: null,
        hasContent: true,
      );
      final recipes = MockSharedRecipeVm();
      final menus = MockSharedMenuVm();
      final lists = MockSharedShoppingVm();
      stubKinds(recipes, menus, lists);
      when(() => coordinator.recipeViewModel).thenReturn(recipes);
      when(() => coordinator.menuViewModel).thenReturn(menus);
      when(() => coordinator.shoppingViewModel).thenReturn(lists);
      when(() => coordinator.showImported).thenReturn(false);
      final search = MockSearchVm();
      when(() => search.hasSearchQuery).thenReturn(false);
      when(() => coordinator.searchViewModel).thenReturn(search);

      await pumpView(tester);

      for (final label in ['Recept · 0', 'Menyer · 0', 'Listor · 0']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // There is no "Allt": the first tab is the recipes.
      expect(find.text('Allt'), findsNothing);
      expect(find.text('Inga delade recept'), findsOneWidget);
    });
  });

  group('SharedWithMeView — filtered lists', () {
    late MockSharedRecipeVm recipes;
    late MockSharedMenuVm menus;
    late MockSharedShoppingVm lists;
    late MockSearchVm search;

    // Content exists overall (so the tabs render) but only [recipe] is listed.
    void stubContent({
      List<SharedRecipe> recipeList = const [],
      bool hasSearchQuery = false,
    }) {
      stubGlobalState(
        loading: false,
        hasError: false,
        error: null,
        hasContent: true,
      );
      recipes = MockSharedRecipeVm();
      menus = MockSharedMenuVm();
      lists = MockSharedShoppingVm();
      search = MockSearchVm();
      stubKinds(recipes, menus, lists);
      when(() => recipes.filteredContent).thenReturn(recipeList);
      when(() => recipes.isRecipeViewed(any())).thenReturn(true);
      when(() => recipes.isRecipeImported(any())).thenReturn(false);
      when(() => recipes.isOperating).thenReturn(false);
      when(() => coordinator.recipeViewModel).thenReturn(recipes);
      when(() => coordinator.menuViewModel).thenReturn(menus);
      when(() => coordinator.shoppingViewModel).thenReturn(lists);
      when(() => coordinator.showImported).thenReturn(false);
      when(() => search.hasSearchQuery).thenReturn(hasSearchQuery);
      when(() => coordinator.searchViewModel).thenReturn(search);
    }

    final recipe = SharedRecipe(
      id: 'r1',
      sharedByUserId: 'u',
      sharedByDisplayName: 'Anna',
      sharedAt: DateTime(2026, 1, 1),
      originalRecipeId: 'o',
      recipeTitle: 'Köttbullar',
    );

    testWidgets('tapping Menyer swaps the recipe list for the menus empty '
        'state, and tapping Recept brings the recipe back', (tester) async {
      stubContent(recipeList: [recipe]);
      await pumpView(tester);

      expect(find.text('Köttbullar'), findsOneWidget);

      await tester.tap(find.text('Menyer · 0'));
      await tester.pumpAndSettle();

      expect(find.text('Inga delade menyer'), findsOneWidget);
      expect(find.text(_findFriendsCta), findsOneWidget);
      expect(find.text('Köttbullar'), findsNothing);

      await tester.tap(find.text('Recept · 1'));
      await tester.pumpAndSettle();

      expect(find.text('Köttbullar'), findsOneWidget);
      expect(find.text('Inga delade menyer'), findsNothing);
    });

    testWidgets('each tab with nothing of its kind names that kind in the '
        'empty state', (tester) async {
      stubContent();
      await pumpView(tester);

      expect(find.text('Inga delade recept'), findsOneWidget);

      await tester.tap(find.text('Listor · 0'));
      await tester.pumpAndSettle();
      expect(find.text('Inga delade inköpslistor'), findsOneWidget);
      expect(find.text('Inga delade recept'), findsNothing);

      await tester.tap(find.text('Menyer · 0'));
      await tester.pumpAndSettle();
      expect(find.text('Inga delade menyer'), findsOneWidget);
      expect(find.text('Inga delade inköpslistor'), findsNothing);
    });

    testWidgets('a recipe row names who shared it and offers Spara', (
      tester,
    ) async {
      stubContent(recipeList: [recipe]);
      await pumpView(tester);

      expect(find.text('Köttbullar'), findsOneWidget);
      expect(find.textContaining('från Anna'), findsOneWidget);
      expect(find.text('Spara'), findsOneWidget);
      expect(find.text('SPARAD'), findsNothing);
    });

    testWidgets('a recipe already saved shows the Sparad badge and no Spara', (
      tester,
    ) async {
      stubContent(recipeList: [recipe]);
      when(() => recipes.isRecipeImported(any())).thenReturn(true);
      await pumpView(tester);

      expect(find.text('SPARAD'), findsOneWidget);
      expect(find.text('Spara'), findsNothing);
    });

    testWidgets('a recipe not yet opened is marked "ny" after its name', (
      tester,
    ) async {
      stubContent(recipeList: [recipe]);
      when(() => recipes.isRecipeViewed(any())).thenReturn(false);
      await pumpView(tester);

      expect(find.text('Köttbullar · ny', findRichText: true), findsOneWidget);
    });

    testWidgets('long-pressing a row offers Svara, Dölj and Sluta dela', (
      tester,
    ) async {
      stubContent(recipeList: [recipe]);
      await pumpView(tester);

      await tester.longPress(find.text('Köttbullar'));
      await tester.pumpAndSettle();

      expect(find.text('Svara'), findsOneWidget);
      expect(find.text('Dölj'), findsOneWidget);
      expect(find.text('Sluta dela'), findsOneWidget);
    });

    testWidgets('Spara imports that recipe once', (tester) async {
      stubContent(recipeList: [recipe]);
      when(
        () => recipes.importSharedRecipe(any()),
      ).thenAnswer((_) async => 'new-id');
      await pumpView(tester);

      await tester.tap(find.text('Spara'));
      await tester.pump();

      verify(() => recipes.importSharedRecipe(recipe)).called(1);
    });

    testWidgets('Spara is disabled while an import is running', (tester) async {
      stubContent(recipeList: [recipe]);
      when(() => recipes.isOperating).thenReturn(true);
      await pumpView(tester);

      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Spara'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Sluta dela in the sheet asks before unsharing, and Avbryt '
        'closes the question', (tester) async {
      stubContent(recipeList: [recipe]);
      await pumpView(tester);

      await tester.longPress(find.text('Köttbullar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sluta dela'));
      await tester.pumpAndSettle();

      expect(find.text('Sluta dela recept?'), findsOneWidget);
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(find.text('Sluta dela recept?'), findsNothing);
    });

    testWidgets('confirming Sluta dela unshares the recipe', (tester) async {
      final recipeCoordinator = _MockSocialRecipeCoordinator();
      when(
        () => recipeCoordinator.unshareRecipe(any()),
      ).thenAnswer((_) async => true);
      TestServiceLocator.registerMock<SocialRecipeCoordinator>(
        recipeCoordinator,
      );
      stubContent(recipeList: [recipe]);
      await pumpView(tester);

      await tester.longPress(find.text('Köttbullar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sluta dela'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Sluta dela'),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => recipeCoordinator.unshareRecipe(recipe.originalRecipeId),
      ).called(1);
      expect(find.text('Sluta dela recept?'), findsNothing);
    });

    testWidgets('the search is the shared search box: typing searches, the '
        'import filter sits inside it, and its clear clears the search', (
      tester,
    ) async {
      stubContent(recipeList: [recipe]);
      when(
        () => coordinator.performUnifiedSearch(any()),
      ).thenAnswer((_) async {});
      await pumpView(tester);

      final box = find.byType(ButlerySearchBox);
      expect(box, findsOneWidget);
      expect(
        find.descendant(of: box, matching: find.byTooltip('Visa importerade')),
        findsOneWidget,
      );

      await tester.enterText(
        find.descendant(of: box, matching: find.byType(TextField)),
        'kött',
      );
      await tester.pump();
      verify(() => coordinator.performUnifiedSearch('kött')).called(1);

      await tester.tap(find.byIcon(ButleryIcons.x));
      await tester.pump();
      verify(() => coordinator.clearAllSearch()).called(1);
    });

    testWidgets('an active search with no matches offers Rensa sökning, which '
        'clears the search on the coordinator', (tester) async {
      stubContent(hasSearchQuery: true);
      await pumpView(tester);

      await tester.tap(find.text('Rensa sökning'));
      await tester.pumpAndSettle();

      verify(() => coordinator.clearAllSearch()).called(1);
    });
  });

  group('SharedWithMeView — top bar', () {
    testWidgets('shows a back control to Mer and no refresh action', (
      tester,
    ) async {
      stubGlobalState(
        loading: false,
        hasError: false,
        error: null,
        hasContent: false,
      );

      // The back control only exists when the route can pop, so open the view
      // from a launcher page the way Mer does.
      await pumpView(
        tester,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SharedWithMeView()),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(_appBarTitle), findsOneWidget);
      expect(find.byTooltip('Tillbaka till Mer'), findsOneWidget);
      expect(find.byTooltip('Uppdatera'), findsNothing);
    });
  });

  group('SharedContentLists.rowsFor', () {
    late MockSharedRecipeVm recipes;
    late MockSharedMenuVm menus;
    late MockSharedShoppingVm lists;

    setUp(() {
      recipes = MockSharedRecipeVm();
      menus = MockSharedMenuVm();
      lists = MockSharedShoppingVm();
      when(() => recipes.filteredContent).thenReturn([
        SharedRecipe(
          id: 'r1',
          sharedByUserId: 'u',
          sharedByDisplayName: 'U',
          sharedAt: DateTime(2026, 1, 1),
          originalRecipeId: 'o',
          recipeTitle: 'Recept',
        ),
      ]);
      when(() => menus.filteredContent).thenReturn([
        SharedMenu(
          id: 'm1',
          sharedByUserId: 'u',
          sharedByDisplayName: 'U',
          sharedAt: DateTime(2026, 3, 1),
          menuTitle: 'Meny',
          menuSnapshot: const {},
        ),
      ]);
      when(() => lists.filteredContent).thenReturn([
        SharedShoppingList(
          id: 's1',
          sharedByUserId: 'u',
          sharedByDisplayName: 'U',
          sharedAt: DateTime(2026, 2, 1),
          listName: 'Lista',
          itemCount: 1,
          originalOwnerId: 'u',
          originalOwnerDisplayName: 'U',
        ),
      ]);
      when(() => coordinator.recipeViewModel).thenReturn(recipes);
      when(() => coordinator.menuViewModel).thenReturn(menus);
      when(() => coordinator.shoppingViewModel).thenReturn(lists);
    });

    Iterable<Object?> keysOf(SharedContentFilter filter) =>
        SharedContentLists.rowsFor(
          coordinator,
          filter,
        ).map((row) => (row.key! as ValueKey).value);

    test('Recept shows only recipes', () {
      expect(keysOf(SharedContentFilter.recipes), ['recipe_r1']);
    });

    test('Menyer and Listor each show only their own kind', () {
      expect(keysOf(SharedContentFilter.menus), ['menu_m1']);
      expect(keysOf(SharedContentFilter.shoppingLists), ['list_s1']);
    });
  });
}

class MockSharedRecipeVm extends Mock implements SharedRecipeViewModel {}

class MockSharedMenuVm extends Mock implements SharedMenuViewModel {}

class MockSharedShoppingVm extends Mock implements SharedShoppingViewModel {}

class MockSearchVm extends Mock implements SharedContentSearchViewModel {}

void stubKinds(
  MockSharedRecipeVm recipes,
  MockSharedMenuVm menus,
  MockSharedShoppingVm lists,
) {
  when(() => recipes.filteredContent).thenReturn(const []);
  when(() => menus.filteredContent).thenReturn(const []);
  when(() => lists.filteredContent).thenReturn(const []);
  when(() => recipes.hasMoreContent).thenReturn(false);
  when(() => menus.hasMoreContent).thenReturn(false);
  when(() => lists.hasMoreContent).thenReturn(false);
}
