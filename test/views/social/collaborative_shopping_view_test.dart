/// Behaviour tests for [CollaborativeShoppingView] — the real-time shared
/// shopping-list surface.
///
/// The view builds its OWN production [CollaborativeShoppingViewModel] inside a
/// `ChangeNotifierProvider(create:)`, passing `shoppingService:
/// ServiceLocator.get()`. We register a [MockUnifiedShoppingService] through the
/// prod↔test ServiceLocator bridge so that real VM resolves OUR mock and seed
/// the mock's `lists` per scenario.
///
/// Test strategy (mirrors the group_detail_view_test template — drive the real
/// VM / real sub-widgets, not topology):
///   • The LOADED body (item list, claim/check affordances) is exercised
///     through the real production sub-widget [CollaborativeShoppingItems]
///     driven by the REAL VM, inside a width-bounded Scaffold.
///   • The absent-list outcome is asserted at the VM level: a missing list
///     drives the VM into its error state (the view's LoadingStateBuilder shows
///     that error before it ever reaches the not-found empty branch).
///
/// Why not pump the full view for the loaded/absent states? Its loaded body
/// puts an `Expanded(TextField) + FilledButton` add-item Row directly under a
/// `Center`, which the bare test Scaffold leaves horizontally unbounded → an
/// "infinite width" layout assertion (a real layout fragility of the view
/// shell, surfaced by the harness; see the closing note). And `_loadList`
/// rethrows the not-found exception out of the fire-and-forget `_initialize()`,
/// which the test zone reports as an uncaught error. Both are properties of the
/// shell, orthogonal to the per-item behaviour under test.
///
/// Rebuilt for BUT-1180 — replaces a ~30-test ULTRATHINK smoke-suite of
/// `find.byType(ChangeNotifierProvider<...>) findsOneWidget` topology asserts
/// and Stopwatch "performance" checks (17 of which failed).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_items.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/shopping_list_factory.dart';
import '../helpers/view_test_helpers.dart';

// Swedish copy the view renders (app_sv.arb). Captured here so a behaviour
// regression — not a copy tweak — is what fails the assertion.
// executeAsync's catch routes the thrown exception through
// sanitizeErrorForUser, which collapses it to this generic Swedish message.
const _sanitizedError = 'Ett fel uppstod. Försök igen.';
const _noItemsTitle = 'Inga varor ännu'; // l10n.collaborativeNoItemsYet

const _testListId = 'collaborative_list_123';

void main() {
  late MockUnifiedShoppingService shoppingService;
  late MockOfflineService offlineService;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();

    // The view's top sliver is LayoutComponents.offlineIndicator(), whose
    // OfflineIndicator.initState resolves OfflineService and reads `isOnline`.
    // Register an online mock so it builds collapsed without exploding.
    offlineService = MockOfflineService();
    when(() => offlineService.isOnline).thenReturn(true);
    when(() => offlineService.addListener(any())).thenReturn(null);
    when(() => offlineService.removeListener(any())).thenReturn(null);
    TestServiceLocator.registerMock<OfflineService>(offlineService);

    // The production VM resolves UnifiedShoppingService from the locator.
    // Replace the default factory mock with one we control so we can seed
    // `lists` per test. MockUnifiedShoppingService.stateStream is a BROADCAST
    // controller that emits nothing by default — no re-entrant sync emit
    // during the VM's `stateStream.listen(...)` in its constructor.
    shoppingService = MockUnifiedShoppingService();
    when(() => shoppingService.loadLists()).thenAnswer((_) async {});
    TestServiceLocator.registerMock<UnifiedShoppingService>(shoppingService);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Widget localize(Widget home) {
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
    );
  }

  // A collaborative list with the given items, owned by the current test user
  // ('test-user-123' from MockFactory.createPermissionService) so canEdit is
  // true and items render their claim/check affordances.
  UnifiedShoppingList listWith(List<UnifiedShoppingItem> items) {
    return ShoppingListFactory.build(
      id: _testListId,
      name: 'Gemensam handlingslista',
      type: ListType.collaborative,
      items: items,
    );
  }

  // amount:0 → UnifiedShoppingItem.displayText == name, so we can assert on the
  // plain Swedish grocery name without an amount/unit prefix.
  UnifiedShoppingItem item(String name,
      {String? id, bool bought = false, String category = 'Mejeri'}) {
    return ShoppingListFactory.buildItem(
      id: id ?? 'item-$name',
      name: name,
      amount: 0,
      unit: '',
      category: category,
      bought: bought,
    );
  }

  // Build the REAL production VM against the seeded mock service, run its async
  // _loadList to completion, then return it ready to drive a sub-widget.
  Future<CollaborativeShoppingViewModel> loadedViewModel(
      WidgetTester tester) async {
    final vm = CollaborativeShoppingViewModel(
      listId: _testListId,
      shoppingService: shoppingService,
    );
    addTearDown(vm.dispose);
    // The constructor kicks off _initialize()/_loadList() asynchronously; pump
    // the microtask queue so currentList settles before we render.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return vm;
  }

  // Render the real CollaborativeShoppingItems sub-widget inside a width-bounded
  // Scaffold (avoids the view shell's unbounded add-item Row).
  Future<void> pumpItems(
    WidgetTester tester,
    CollaborativeShoppingViewModel vm,
    void Function(String itemId) onToggle,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      localize(
        Scaffold(
          body: SizedBox(
            width: 600,
            child: CollaborativeShoppingItems(
              viewModel: vm,
              onToggleItem: onToggle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('CollaborativeShoppingView — absent list', () {
    test(
        'a missing target list drives the VM into its error state with a '
        'Swedish error message', () async {
      // Construct with the list PRESENT so the ctor's fire-and-forget
      // _initialize() succeeds (no uncaught rejection). Then remove the list
      // and refresh(): _loadList can't find it → throws → executeAsync sets the
      // error and rethrows. refresh() routes through the SAME path the view
      // uses, so this pins the user-visible error the LoadingStateBuilder shows
      // before it could reach the not-found empty branch.
      shoppingService.setShoppingState(
        lists: [listWith(const [])],
        isInitialized: true,
      );

      final vm = CollaborativeShoppingViewModel(
        listId: _testListId,
        shoppingService: shoppingService,
      );
      addTearDown(vm.dispose);
      await Future<void>.delayed(Duration.zero); // drain ctor _initialize()
      expect(vm.currentList, isNotNull,
          reason: 'sanity: initial load found it');

      // The list is now gone.
      shoppingService.setShoppingState(lists: const [], isInitialized: true);

      // executeAsync rethrows after setError; swallow the rethrow and assert
      // the resulting user-visible error state.
      try {
        await vm.refresh();
      } catch (_) {
        // expected — _loadList throws on a missing list
      }

      expect(vm.hasError, isTrue);
      expect(vm.error, _sanitizedError);
    });
  });

  group('CollaborativeShoppingItems — loaded body (real VM)', () {
    testWidgets('renders each seeded list item by its Swedish name',
        (tester) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Mjölk'), item('Bröd'), item('Ägg')]),
        ],
        isInitialized: true,
      );

      final vm = await loadedViewModel(tester);
      expect(vm.currentList, isNotNull,
          reason: 'VM should have resolved the seeded list');
      expect(vm.totalItems, 3);

      await pumpItems(tester, vm, (_) {});

      expect(find.text('Mjölk'), findsOneWidget);
      expect(find.text('Bröd'), findsOneWidget);
      expect(find.text('Ägg'), findsOneWidget);

      // Not the empty-items state.
      expect(find.text(_noItemsTitle), findsNothing);
    });

    testWidgets(
        'shows the Swedish empty-items state when the list has no items',
        (tester) async {
      shoppingService.setShoppingState(
        lists: [listWith(const [])],
        isInitialized: true,
      );

      final vm = await loadedViewModel(tester);
      expect(vm.currentList, isNotNull);
      expect(vm.totalItems, 0);

      await pumpItems(tester, vm, (_) {});

      expect(find.text(_noItemsTitle), findsOneWidget);
    });

    testWidgets(
        'tapping an item checkbox dispatches the toggle for that item id',
        (tester) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Mjölk', id: 'item-milk')]),
        ],
        isInitialized: true,
      );

      final vm = await loadedViewModel(tester);

      String? toggledId;
      await pumpItems(tester, vm, (id) => toggledId = id);

      final checkbox = find.descendant(
        of: find.byKey(const ValueKey('collab-item-item-milk')),
        matching: find.byType(Checkbox),
      );
      expect(checkbox, findsOneWidget);

      await tester.tap(checkbox);
      await tester.pump();

      expect(toggledId, 'item-milk',
          reason: 'Checking an item must dispatch onToggleItem with its id');
    });

    testWidgets('a bought item renders its name with a strikethrough title',
        (tester) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Smör', id: 'item-butter', bought: true)]),
        ],
        isInitialized: true,
      );

      final vm = await loadedViewModel(tester);
      await pumpItems(tester, vm, (_) {});

      final titleFinder = find.text('Smör');
      expect(titleFinder, findsOneWidget);

      final titleText = tester.widget<Text>(titleFinder);
      expect(
        titleText.style?.decoration,
        TextDecoration.lineThrough,
        reason: 'Bought items must render with a strikethrough title',
      );
    });
  });
}
