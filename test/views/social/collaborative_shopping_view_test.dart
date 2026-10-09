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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/views/social/collaborative_shopping_view.dart';
import 'package:butlery/views/social/collaborative_shopping/collaborative_shopping_items.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
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

  Widget localize(Widget home, {ThemeData? theme}) {
    return MaterialApp(
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme ?? AppTheme.lightTheme,
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
  UnifiedShoppingItem item(
    String name, {
    String? id,
    bool bought = false,
    String category = 'Mejeri',
  }) {
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
    WidgetTester tester,
  ) async {
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
    test('a missing target list drives the VM into its error state with a '
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
      expect(
        vm.currentList,
        isNotNull,
        reason: 'sanity: initial load found it',
      );

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
    testWidgets('renders each seeded list item by its Swedish name', (
      tester,
    ) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Mjölk'), item('Bröd'), item('Ägg')]),
        ],
        isInitialized: true,
      );

      final vm = await loadedViewModel(tester);
      expect(
        vm.currentList,
        isNotNull,
        reason: 'VM should have resolved the seeded list',
      );
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
      },
    );

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

        expect(
          toggledId,
          'item-milk',
          reason: 'Checking an item must dispatch onToggleItem with its id',
        );
      },
    );

    testWidgets('a bought item renders its name with a strikethrough title', (
      tester,
    ) async {
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

    testWidgets('the full shell renders its loaded body without a layout exception', (
      tester,
    ) async {
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

    testWidgets('typing a name and tapping Lägg till adds the item through the '
        'service (BUT-1212 regression)', (tester) async {
      // Drives the FULL shell add path: enterText → tap → State handler →
      // real VM.addItem → mock service.addItemToActiveListWithId. The handler reads
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
      when(
        () => shoppingService.addItemToActiveListWithId(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
        ),
      ).thenAnswer((_) async {
        // The post-add refresh re-reads the list — show the added item.
        shoppingService.setShoppingState(
          lists: [
            listWith([item('Havregryn', id: 'item-oats')]),
          ],
          isInitialized: true,
        );
        return 'item-oats';
      });

      await pumpFullView(tester);

      await tester.enterText(find.byType(TextField), 'Havregryn');
      await tester.tap(find.text('Lägg till'));
      // Drain _addItem's async chain (service add → list refresh → clear).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        tester.takeException(),
        isNull,
        reason:
            'add must not throw (e.g. ProviderNotFoundException from a '
            'context.read against the above-provider State context)',
      );
      verify(
        () => shoppingService.addItemToActiveListWithId(
          name: 'Havregryn',
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
        ),
      ).called(1);
      // Success path clears the input — the draft text is gone.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });

    testWidgets('an added item offers Ångra, which removes exactly that row '
        '(BUT-2145)', (tester) async {
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
      when(
        () => shoppingService.addItemToActiveListWithId(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
        ),
      ).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [
            listWith([item('Havregryn', id: 'item-oats')]),
          ],
          isInitialized: true,
        );
        return 'item-oats';
      });
      when(
        () => shoppingService.removeItemFromActiveList(any()),
      ).thenAnswer((_) async => true);

      await pumpFullView(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );

      await tester.enterText(find.byType(TextField), 'Havregryn');
      await tester.tap(find.text('Lägg till'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(l10n.shoppingItemAdded('Havregryn')), findsOneWidget);
      verifyNever(() => shoppingService.removeItemFromActiveList(any()));
      // Let the snackbar finish sliding in before tapping its action.
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text(l10n.commonUndo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verify(
        () => shoppingService.removeItemFromActiveList('item-oats'),
      ).called(1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(l10n.shoppingItemRemoveError('Havregryn')),
        findsNothing,
      );
    });

    testWidgets('an Ångra the list refuses says the row could not be removed '
        '(BUT-2145)', (tester) async {
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
      when(
        () => shoppingService.addItemToActiveListWithId(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
        ),
      ).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [
            listWith([item('Havregryn', id: 'item-oats')]),
          ],
          isInitialized: true,
        );
        return 'item-oats';
      });
      when(
        () => shoppingService.removeItemFromActiveList(any()),
      ).thenAnswer((_) async => false);

      await pumpFullView(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );

      await tester.enterText(find.byType(TextField), 'Havregryn');
      await tester.tap(find.text('Lägg till'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(l10n.shoppingItemAdded('Havregryn')), findsOneWidget);
      verifyNever(() => shoppingService.removeItemFromActiveList(any()));
      // Let the snackbar finish sliding in before tapping its action.
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text(l10n.commonUndo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verify(
        () => shoppingService.removeItemFromActiveList('item-oats'),
      ).called(1);
      // The failure takes the snackbar's place once Ångra's has gone.
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(l10n.shoppingItemRemoveError('Havregryn')),
        findsOneWidget,
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
      tester.element(find.byType(CollaborativeShoppingView)),
    );

    testWidgets('checking an item announces the bought state', (tester) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Mjölk', id: 'item-milk')]),
        ],
        isInitialized: true,
      );
      // After the service-side toggle succeeds, the refreshed list shows the
      // item bought — what the view's nowBought re-read observes.
      when(() => shoppingService.toggleItemBought('item-milk')).thenAnswer((
        _,
      ) async {
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

    testWidgets('un-checking a bought item announces the un-bought state', (
      tester,
    ) async {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Smör', id: 'item-butter', bought: true)]),
        ],
        isInitialized: true,
      );
      when(() => shoppingService.toggleItemBought('item-butter')).thenAnswer((
        _,
      ) async {
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
      when(
        () => shoppingService.toggleItemBought('item-eggs'),
      ).thenAnswer((_) async => false);

      final announces = AnnounceChannel.arm(tester);
      await pumpFullView(tester);
      await tapItemCheckbox(tester, 'item-eggs');

      expect(
        announces.count,
        0,
        reason: 'a failed toggle must not announce a state change',
      );
    });
  });

  group('CollaborativeShoppingView — a refused edit says why (BUT-1722)', () {
    // The collaborative ShoppingItemOperationsManager captured the service's
    // specific refusal (`consumeMutationError`) into its own `error` field —
    // and nothing read it. The view checked the ViewModel's `error`, which only
    // ever carries a LOAD failure, so a member without edit rights tapped a
    // checkbox, watched it flick back, and was told nothing at all.

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    void seedRefusedToggle(String itemId, {String? reason}) {
      shoppingService.setShoppingState(
        lists: [
          listWith([item('Ägg', id: itemId)]),
        ],
        isInitialized: true,
      );
      when(
        () => shoppingService.toggleItemBought(itemId),
      ).thenAnswer((_) async => false);
      if (reason != null) {
        when(() => shoppingService.consumeMutationError()).thenReturn(reason);
      }
    }

    testWidgets("the service's specific reason reaches the shopper", (
      tester,
    ) async {
      const denied = 'Du har inte behörighet att ändra i den här listan.';
      seedRefusedToggle('item-eggs', reason: denied);

      await pumpFullView(tester);
      await tapItemCheckbox(tester, 'item-eggs');

      expect(
        find.text(denied),
        findsOneWidget,
        reason: 'the permission-denied sentence must be shown, not swallowed',
      );
    });

    testWidgets('with no specific reason the generic Swedish sentence is '
        'shown', (tester) async {
      seedRefusedToggle('item-eggs');

      await pumpFullView(tester);
      await tapItemCheckbox(tester, 'item-eggs');

      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );
      expect(find.text(l10n.errorCouldNotUpdateItem), findsOneWidget);
    });

    testWidgets('a refused edit does NOT replace the list with a full-screen '
        'error', (tester) async {
      // The reason must never travel through the ViewModel's `error`: that slot
      // drives the body's LoadingStateBuilder, and BUT-1696 established that a
      // failed mutation keeps the loaded list on screen.
      const denied = 'Du har inte behörighet att ändra i den här listan.';
      seedRefusedToggle('item-eggs', reason: denied);

      await pumpFullView(tester);
      await tapItemCheckbox(tester, 'item-eggs');

      expect(
        find.text('Ägg'),
        findsOneWidget,
        reason: 'the shopping list itself must still be on screen',
      );
      expect(find.text(_sanitizedError), findsNothing);
    });

    testWidgets('a VIEW-ONLY member who ticks the box is told they lack '
        'permission — the case the fix is named after', (tester) async {
      // The three tests above all run as the list OWNER and stage a SERVER
      // refusal, so they only cover the stale-rights path where the service
      // supplies the sentence. The scenario BUT-1722 was written for is local:
      // `collaborative_shopping_items.dart` gates the Checkbox and the row
      // `onTap` on `canView`, while the mutation is gated on `canEdit`, so a
      // member holding `view` CAN tap and never reaches the service at all.
      // Before the manager set a reason on its own `!canEdit` branch this tap
      // produced no snackbar whatsoever.
      final viewOnly = FakePermissionService();
      viewOnly.setPermissionState(
        currentUserId: 'test-user-123',
        userDisplayName: 'Test User',
        defaultHasPermission: false,
        permissions: {
          _testListId: {
            ResourcePermission.viewer: true,
            ResourcePermission.editor: false,
          },
        },
      );
      TestServiceLocator.registerMock<PermissionService>(viewOnly);

      shoppingService.setShoppingState(
        lists: [
          listWith([item('Ägg', id: 'item-eggs')]),
        ],
        isInitialized: true,
      );

      await pumpFullView(tester);
      await tapItemCheckbox(tester, 'item-eggs');

      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );
      expect(
        find.text(l10n.shoppingNoEditPermissionShared),
        findsOneWidget,
        reason:
            'a view-only member must be told why the tick did not stay — this '
            'is the exact sentence the doc comments promise',
      );
      verifyNever(() => shoppingService.toggleItemBought(any()));
    });

    testWidgets(
      'a failed ADD is told why, through the sibling call site to the '
      'checkbox fix above',
      (tester) async {
        // The five tests above all drive `_toggleItem` → `toggleItemCompletion`.
        // `_addItem` → `addItem` has its own separate `setError` call in
        // `ShoppingItemOperationsManager`, and nothing here proved
        // `_showFailureReason()` fires from THAT call site.
        //
        // Not a view-only scenario: `CollaborativeShoppingActions
        // .buildAddItemSection` replaces the whole input row with a read-only
        // banner when `!canEdit` — there is no TextField in the tree for a
        // viewer to reach, so that permission case is enforced at the UI
        // layer and cannot drive `addItem`'s local `!canEdit` branch from a
        // widget test. This test instead covers the editor whose add is
        // refused by the SERVICE — the other branch through the same reader.
        shoppingService.setShoppingState(
          lists: [listWith(const [])],
          isInitialized: true,
        );
        when(
          () => shoppingService.addItemToActiveListWithId(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
          ),
        ).thenAnswer((_) async => null);

        await pumpFullView(tester);
        await tester.enterText(find.byType(TextField), 'Havregryn');
        await tester.tap(find.text('Lägg till'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CollaborativeShoppingView)),
        );
        expect(
          find.text(l10n.errorCouldNotAddItem),
          findsOneWidget,
          reason:
              'a refused add must say why, the same as the checkbox case — '
              'this call site was untested before',
        );
      },
    );
  });

  // P6-U05 (flows-roles-budget.md:83, :132): the role on the list drops to
  // read-only while it is open. The add field goes at once; a snackbar says
  // why, and an item typed but not added is shown and can be copied, so it is
  // not lost without a word. Nothing is written to the list.
  group('CollaborativeShoppingView — role lowered while open (P6-U05)', () {
    Future<FakePermissionService> openWithTyped(
      WidgetTester tester,
      String typed, {
      ThemeData? theme,
    }) async {
      tester.view.physicalSize = const Size(420, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final permissions =
          TestServiceLocator.get<PermissionService>() as FakePermissionService;
      final list = listWith([item('Mjölk')]);
      shoppingService.setShoppingState(lists: [list], isInitialized: true);
      await tester.pumpWidget(
        localize(
          const CollaborativeShoppingView(listId: _testListId),
          theme: theme,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // The first live update: the user can edit.
      shoppingService.emitState(ShoppingStateData(lists: [list]));
      await tester.pump();
      if (typed.isNotEmpty) {
        await tester.enterText(find.byType(TextField), typed);
        await tester.pump();
      }
      // The owner lowers the role; the next live update carries it.
      permissions.setPermissionState(
        currentUserId: 'test-user-123',
        defaultHasPermission: false,
      );
      shoppingService.emitState(ShoppingStateData(lists: [list]));
      await tester.pump();
      // The notice is posted after the frame; let the snackbar slide in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      return permissions;
    }

    testWidgets('typed but not added: the notice shows it and offers a copy', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await openWithTyped(tester, 'Havregryn');
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );

      final notice = find.byKey(
        const ValueKey('collaborativeShopping.unaddedText'),
      );
      expect(find.text('Lägg till'), findsNothing);
      // The snackbar is short and says why; the typed text is in a notice in
      // the view, not in the snackbar, so it is never cut off.
      expect(find.text(l10n.roleLoweredShoppingList), findsOneWidget);
      expect(notice, findsOneWidget);
      expect(
        find.descendant(
          of: notice,
          matching: find.text(l10n.roleLoweredShoppingUnsaved),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: notice, matching: find.text('Havregryn')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: notice,
          matching: find.text(l10n.roleLoweredCopyText),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(copied, ['Havregryn']);

      // No timeout takes it away: it stays until the user closes it.
      await tester.pump(const Duration(seconds: 30));
      expect(notice, findsOneWidget);
      await tester.tap(
        find.descendant(of: notice, matching: find.text(l10n.commonClose)),
      );
      await tester.pump();
      expect(notice, findsNothing);
      verifyNever(
        () => shoppingService.addItemToActiveListWithId(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
        ),
      );
    });

    // B83-2e: a notice box like the updated-by strip — surface.tint.warning
    // fill, no border, the control radius.
    for (final (name, theme, tint) in [
      ('light', AppTheme.lightTheme, const Color(0xFFF0EEE2)),
      ('dark', AppTheme.darkTheme, const Color(0xFF2F4437)),
    ]) {
      testWidgets(
        '$name: a surface.tint.warning fill with no border (B83-2e)',
        (
          tester,
        ) async {
          await openWithTyped(tester, 'Havregryn', theme: theme);

          final box = tester.widget<Material>(
            find
                .descendant(
                  of: find.byKey(
                    const ValueKey('collaborativeShopping.unaddedText'),
                  ),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(box.color, tint);
          final shape = box.shape! as RoundedRectangleBorder;
          expect(shape.side, BorderSide.none);
          expect(
            shape.borderRadius,
            BorderRadius.circular(AppDimensions.radiusControl),
          );
        },
      );
    }

    testWidgets('nothing typed: the notice says why, with Stäng', (
      tester,
    ) async {
      await openWithTyped(tester, '');
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );
      expect(find.text(l10n.roleLoweredShoppingList), findsOneWidget);
      expect(find.text(l10n.commonClose), findsOneWidget);
      expect(
        find.byKey(const ValueKey('collaborativeShopping.unaddedText')),
        findsNothing,
      );
    });
  });

  // BUT-2187: "Listan uppdaterades av namn" (produktregler.md) — read
  // from lastActivityAt/lastActivityByUserId/lastActivityByDisplayName
  // ([UnifiedShoppingList]), no new Firestore field.
  group('CollaborativeShoppingView — updated-by notice (BUT-2187)', () {
    final noticeKey = find.byKey(
      const ValueKey('collaborativeShopping.updatedByNotice'),
    );

    Future<void> pumpFullView(WidgetTester tester, {ThemeData? theme}) async {
      tester.view.physicalSize = const Size(420, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        localize(
          const CollaborativeShoppingView(listId: _testListId),
          theme: theme,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets("shows the updater's name for another user's update", (
      tester,
    ) async {
      final list = listWith([item('Mjölk')]);
      shoppingService.setShoppingState(lists: [list], isInitialized: true);
      await pumpFullView(tester);
      expect(noticeKey, findsNothing);

      shoppingService.emitState(
        ShoppingStateData(
          lists: [
            list.copyWith(
              lastActivityAt: DateTime.now(),
              lastActivityByUserId: 'u-other',
              lastActivityByDisplayName: 'Anna',
            ),
          ],
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );
      expect(noticeKey, findsOneWidget);
      expect(
        find.text(l10n.shoppingListUpdatedByNotice('Anna')),
        findsOneWidget,
      );
    });

    // B83-2d: a notice box — surface.tint.warning fill, no border lines.
    for (final (name, theme, tint) in [
      ('light', AppTheme.lightTheme, const Color(0xFFF0EEE2)),
      ('dark', AppTheme.darkTheme, const Color(0xFF2F4437)),
    ]) {
      testWidgets(
        '$name: a surface.tint.warning fill with no border (B83-2d)',
        (
          tester,
        ) async {
          final list = listWith([item('Mjölk')]);
          shoppingService.setShoppingState(lists: [list], isInitialized: true);
          await pumpFullView(tester, theme: theme);

          shoppingService.emitState(
            ShoppingStateData(
              lists: [
                list.copyWith(
                  lastActivityAt: DateTime(2026, 10, 1),
                  lastActivityByUserId: 'u-other',
                  lastActivityByDisplayName: 'Anna',
                ),
              ],
            ),
          );
          await tester.pump();

          expect(noticeKey, findsOneWidget);
          final box = tester.widget<Container>(
            find
                .descendant(of: noticeKey, matching: find.byType(Container))
                .first,
          );
          final decoration = box.decoration! as BoxDecoration;
          expect(decoration.color, tint);
          expect(decoration.border, isNull);
          expect(
            decoration.borderRadius,
            BorderRadius.circular(AppDimensions.radiusControl),
          );
        },
      );
    }

    testWidgets("shows nothing for the signed-in user's own update", (
      tester,
    ) async {
      // listWith's owner is 'test-user-123' — ViewTestHelpers' default
      // signed-in user (matches the BUT-1722 view-only test above).
      final list = listWith([item('Mjölk')]);
      shoppingService.setShoppingState(lists: [list], isInitialized: true);
      await pumpFullView(tester);

      shoppingService.emitState(
        ShoppingStateData(
          lists: [
            list.copyWith(
              lastActivityAt: DateTime.now(),
              lastActivityByUserId: 'test-user-123',
              lastActivityByDisplayName: 'Malin',
            ),
          ],
        ),
      );
      await tester.pump();

      expect(noticeKey, findsNothing);
    });

    testWidgets('can be dismissed', (tester) async {
      final list = listWith([item('Mjölk')]);
      shoppingService.setShoppingState(lists: [list], isInitialized: true);
      await pumpFullView(tester);

      shoppingService.emitState(
        ShoppingStateData(
          lists: [
            list.copyWith(
              lastActivityAt: DateTime.now(),
              lastActivityByUserId: 'u-other',
              lastActivityByDisplayName: 'Anna',
            ),
          ],
        ),
      );
      await tester.pump();
      expect(noticeKey, findsOneWidget);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );
      await tester.tap(find.byTooltip(l10n.a11yShoppingListUpdatedByDismiss));
      await tester.pump();

      expect(noticeKey, findsNothing);
    });

    testWidgets('uses the neutral fallback when the display name is missing', (
      tester,
    ) async {
      final list = listWith([item('Mjölk')]);
      shoppingService.setShoppingState(lists: [list], isInitialized: true);
      await pumpFullView(tester);

      shoppingService.emitState(
        ShoppingStateData(
          lists: [
            list.copyWith(
              lastActivityAt: DateTime.now(),
              lastActivityByUserId: 'u-other',
              lastActivityByDisplayName: '',
            ),
          ],
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(CollaborativeShoppingView)),
      );
      expect(find.text(l10n.shoppingListUpdatedByUnknown), findsOneWidget);
    });
  });

  // BUT-2183: the list header is surface.raised, so its status badge stands on
  // surface.base with no border, and the text carries the status colour.
  group('CollaborativeShoppingView — status badge (BUT-2183)', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      for (final done in [false, true]) {
        testWidgets(
          '$name, ${done ? 'completed' : 'in progress'}: base fill, no border, '
          'the status text token',
          (tester) async {
            tester.view.physicalSize = const Size(420, 3000);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });
            shoppingService.setShoppingState(
              lists: [
                listWith([
                  item('Mjölk', bought: done),
                  item('Bröd', bought: true),
                ]),
              ],
              isInitialized: true,
            );
            await tester.pumpWidget(
              localize(
                const CollaborativeShoppingView(listId: _testListId),
                theme: theme,
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));

            final context = tester.element(
              find.byType(CollaborativeShoppingView),
            );
            final l10n = AppLocalizations.of(context);
            final badge = find.text(
              done ? l10n.statusCompleted : l10n.statusInProgress,
            );
            expect(badge, findsOneWidget);
            final box = tester.widget<Container>(
              find.ancestor(of: badge, matching: find.byType(Container)).first,
            );
            final decoration = box.decoration! as BoxDecoration;
            expect(decoration.color, theme.colorScheme.surface);
            expect(decoration.border, isNull);
            expect(
              tester.widget<Text>(badge).style?.color,
              done
                  ? context.modeColors.success
                  : AppModeColors.textWarning(theme.brightness),
            );
          },
        );
      }
    }
  });
}
