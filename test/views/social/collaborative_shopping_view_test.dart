/// Behaviour tests for [CollaborativeShoppingView] — the real-time shared
/// shopping-list surface.
///
/// The view's State owns its production [CollaborativeShoppingViewModel]
/// (created in initState, exposed via `ChangeNotifierProvider.value` —
/// BUT-1226), passing `shoppingService: ServiceLocator.get()`. We register a
/// [MockUnifiedShoppingService] through the prod↔test ServiceLocator bridge so
/// that real VM resolves OUR mock and seed the mock's `lists` per scenario.
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
/// The per-item behaviour tests still drive the real sub-widget directly (it's
/// the tighter, faster harness). But the SHELL is now testable: BUT-1184 made
/// the add-item Row width-robust by wrapping its FilledButton in `Flexible`.
/// Previously that bare non-flex `FilledButton.icon` was measured by RenderFlex
/// at an UNBOUNDED main-axis width (Flex._constraintsForNonFlexChild leaves the
/// main axis unconstrained for non-flex children), so its min-tap-target
/// asserted "BoxConstraints forces an infinite width" on EVERY pump of the full
/// shell. As a flex child it now gets bounded space, so the full
/// `CollaborativeShoppingView` lays out cleanly — see the `full shell renders
/// its loaded body` test below, the regression guard for that fix. (`_loadList`
/// still rethrows the not-found exception out of the fire-and-forget
/// `_initialize()`, so the absent-list case stays a VM-level assertion.)
///
/// Rebuilt for BUT-1180 — replaces a ~30-test ULTRATHINK smoke-suite of
/// `find.byType(ChangeNotifierProvider<...>) findsOneWidget` topology asserts
/// and Stopwatch "performance" checks (17 of which failed).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/social/collaborative_shopping_view.dart';
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
import '../../infrastructure/helpers/announce_channel.dart';
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

  group('CollaborativeShoppingView — full shell (BUT-1184)', () {
    // The full view's State creates its own VM in initState via
    // ServiceLocator.get() (BUT-1226), which lands on the mock registered in
    // setUp. We pump the WHOLE view (AppBar + responsive body + add-item Row +
    // items) — the thing the old suite couldn't do.
    Future<void> pumpFullView(WidgetTester tester) async {
      await tester.pumpWidget(
        localize(const CollaborativeShoppingView(listId: _testListId)),
      );
      // Let the VM's fire-and-forget _loadList settle and the view rebuild.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets(
        'the full shell renders its loaded body without a layout exception',
        (tester) async {
      // Before BUT-1184 the full view could NOT be pumped at all: the add-item
      // Row's bare non-flex FilledButton.icon was measured by RenderFlex at an
      // UNBOUNDED main-axis width (Flex._constraintsForNonFlexChild leaves the
      // main axis unconstrained), so its min-tap-target asserted "BoxConstraints
      // forces an infinite width" on every pump. Wrapping that button in
      // Flexible routes it through the flex-child layout path (bounded space),
      // so the whole shell — AppBar + responsive body + add-item Row + items —
      // now lays out cleanly. This is the regression guard for that fix.

      // Tall surface so the loaded ListView body has room and the assertions
      // below find the seeded items.
      tester.view.physicalSize = const Size(420, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // A benign vertical RenderFlex overflow can surface on a short surface;
      // swallow ONLY that so a genuine "infinite width" assertion (the thing
      // BUT-1184 fixed) would still surface via takeException().
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
          return;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      shoppingService.setShoppingState(
        lists: [
          listWith([item('Mjölk'), item('Bröd')]),
        ],
        isInitialized: true,
      );

      await pumpFullView(tester);

      // No "infinite width" (or any non-overflow) layout assertion escaped.
      expect(tester.takeException(), isNull);

      // The view's key content rendered: the add-item action (the formerly
      // crash-inducing FilledButton, by its Swedish label) and the seeded items.
      expect(find.text('Lägg till'), findsOneWidget); // l10n.collaborativeAdd
      expect(find.text('Mjölk'), findsOneWidget);
      expect(find.text('Bröd'), findsOneWidget);
    });

    testWidgets(
        'typing a name and tapping Lägg till adds the item through the '
        'service (BUT-1212 regression)', (tester) async {
      // Drives the FULL shell add path: enterText → tap → State handler →
      // real VM.addItem → mock service.addItemToActiveList. The handler reads
      // the State-owned `_vm` field directly (BUT-1226); a re-introduced
      // `context.read<CollaborativeShoppingViewModel>()` inside _addItem would
      // throw ProviderNotFoundException (the State's context sits ABOVE the
      // provider its build creates), surface via takeException, and never
      // reach the service — failing both assertions below.
      tester.view.physicalSize = const Size(420, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      shoppingService.setShoppingState(
        lists: [listWith(const [])],
        isInitialized: true,
      );
      when(() => shoppingService.addItemToActiveList(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
          )).thenAnswer((_) async {
        // The post-add refresh re-reads the list — show the added item.
        shoppingService.setShoppingState(
          lists: [
            listWith([item('Havregryn', id: 'item-oats')]),
          ],
          isInitialized: true,
        );
        return true;
      });

      await pumpFullView(tester);

      await tester.enterText(find.byType(TextField), 'Havregryn');
      await tester.tap(find.text('Lägg till'));
      // Drain _addItem's async chain (service add → list refresh → clear).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull,
          reason: 'add must not throw (e.g. ProviderNotFoundException from a '
              'context.read against the above-provider State context)');
      verify(() => shoppingService.addItemToActiveList(
            name: 'Havregryn',
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
          )).called(1);
      // Success path clears the input — the draft text is gone.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });
  });

  group('CollaborativeShoppingView — bought/unbought announce (BUT-1212)', () {
    // The announce lives in the VIEW's _toggleItem (BUT-1201), so these pump
    // the full shell: tap → real VM.toggleItemCompletion → mock service →
    // list refresh → SemanticsService.announce on the REAL a11y channel
    // (AnnounceChannel intercepts the channel, not the service).

    Future<void> pumpFullView(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        localize(const CollaborativeShoppingView(listId: _testListId)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> tapItemCheckbox(WidgetTester tester, String itemId) async {
      final checkbox = find.descendant(
        of: find.byKey(ValueKey('collab-item-$itemId')),
        matching: find.byType(Checkbox),
      );
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      // Drain _toggleItem's async chain (toggle → refresh → announce).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)));

    testWidgets('checking an item announces the bought state', (tester) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Mjölk', id: 'item-milk')]),
        ],
        isInitialized: true,
      );
      // After the service-side toggle succeeds, the refreshed list shows the
      // item bought — what the view's nowBought re-read observes.
      when(() => shoppingService.toggleItemBought('item-milk'))
          .thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [
            listWith([item('Mjölk', id: 'item-milk', bought: true)]),
          ],
          isInitialized: true,
        );
        return true;
      });

      final announces = AnnounceChannel.arm(tester);
      await pumpFullView(tester);
      await tapItemCheckbox(tester, 'item-milk');

      final l10n = l10nOf(tester);
      expect(announces.messages, contains(l10n.a11yItemBought));
      expect(announces.messages, isNot(contains(l10n.a11yItemUnbought)));
    });

    testWidgets('un-checking a bought item announces the un-bought state',
        (tester) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Smör', id: 'item-butter', bought: true)]),
        ],
        isInitialized: true,
      );
      when(() => shoppingService.toggleItemBought('item-butter'))
          .thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [
            listWith([item('Smör', id: 'item-butter', bought: false)]),
          ],
          isInitialized: true,
        );
        return true;
      });

      final announces = AnnounceChannel.arm(tester);
      await pumpFullView(tester);
      await tapItemCheckbox(tester, 'item-butter');

      final l10n = l10nOf(tester);
      expect(announces.messages, contains(l10n.a11yItemUnbought));
      expect(announces.messages, isNot(contains(l10n.a11yItemBought)));
    });

    testWidgets('a failed toggle announces nothing', (tester) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Ägg', id: 'item-eggs')]),
        ],
        isInitialized: true,
      );
      when(() => shoppingService.toggleItemBought('item-eggs'))
          .thenAnswer((_) async => false);

      final announces = AnnounceChannel.arm(tester);
      await pumpFullView(tester);
      await tapItemCheckbox(tester, 'item-eggs');

      expect(announces.count, 0,
          reason: 'a failed toggle must not announce a state change');
    });
  });
}
