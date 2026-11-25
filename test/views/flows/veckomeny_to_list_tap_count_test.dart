/// Measures what the week menu costs a user today, from an empty week to the
/// shopping list route, by tapping the real controls. Numbers are printed as
/// BASELINE lines and pinned so a change in the flow shows up as a diff.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/menu/menu_scoring.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/veckomeny_view.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/menu/shopping_merge_sheet.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../unit/services/shopping/personal_merge_stub.dart';
import 'veckomeny_flow_harness.dart';

class _Pantry extends Mock implements PantryService {
  @override
  Stream<List<PantryItem>> watchAll(String userId) =>
      Stream.value(const <PantryItem>[]);
}

class _Surfaces extends NavigatorObserver {
  _Surfaces(this.log);
  final List<String> log;
  final List<String> pushedNames = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushedNames.add(name);
    if (previousRoute == null) return;
    log.add(name ?? route.runtimeType.toString());
  }
}

final _sv = AppLocalizationsSv();
const _generateKey = ValueKey('test-veckomeny-generate');
final _wishPrompt = _sv.menuWishSavePrompt;
final _quickWeek = _sv.menuQuickFastTitle;
const _surfacesOnPath = [
  'ModalBottomSheetRoute<MenuShoppingMergePreview>',
  Routes.shoppingList,
];

class _RecordingMenu extends HeldMenuService {
  final List<String> prompts = [];

  @override
  Future<Map<String, List<Recipe>>> generateMenuFromPrompt(
    String input,
    List<Recipe> allRecipes, {
    Set<String> recentlyUsedRecipeIds = const {},
    MenuScoringContext scoringContext = MenuScoringContext.empty,
  }) {
    prompts.add(input);
    return super.generateMenuFromPrompt(
      input,
      allRecipes,
      recentlyUsedRecipeIds: recentlyUsedRecipeIds,
      scoringContext: scoringContext,
    );
  }
}

class _Counted {
  _Counted(this.tester, this.surfaces);
  final WidgetTester tester;
  final List<String> surfaces;
  int taps = 0;
  int typed = 0;
  final List<String> steps = [];
  final List<String> seenTexts = [];

  Future<void> _settle() async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(String label, Finder finder) async {
    expect(finder, findsOneWidget, reason: 'control "$label" not found');
    taps++;
    steps.add('tap:$label');
    await tester.tap(finder);
    await _settle();
    if (find.text(_wishPrompt).evaluate().isNotEmpty &&
        !seenTexts.contains(_wishPrompt)) {
      seenTexts.add(_wishPrompt);
    }
    for (final w in tester.widgetList<SnackBar>(find.byType(SnackBar))) {
      final c = w.content;
      final t = c is Text ? c.data : c.runtimeType.toString();
      if (!seenTexts.contains('snackbar:$t')) seenTexts.add('snackbar:$t');
    }
  }

  Future<void> type(String label, Finder finder, String text) async {
    typed++;
    steps.add('type:$label');
    await tester.enterText(finder, text);
    await tester.pump();
  }

  void report(String path) {
    // ignore: avoid_print
    print('BASELINE $path: taps=$taps typed=$typed surfaces=$surfaces');
  }
}

void main() {
  late VeckomenyFlowHarness h;
  late MockUnifiedShoppingService shopping;
  late List<UnifiedShoppingList> writes;
  late _Surfaces observer;
  late _RecordingMenu menu;
  late List<String> surfaces;

  setUpAll(registerPersonalMergeFallbacks);

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
    menu = _RecordingMenu()
      ..next = {
        'Middag': [flowDinner(1), flowDinner(2), flowDinner(3)],
      };
    TestServiceLocator.registerMock<MenuService>(menu);
    TestServiceLocator.registerMock<PantryService>(_Pantry());
    shopping = MockUnifiedShoppingService();
    TestServiceLocator.registerMock<UnifiedShoppingService>(shopping);
    writes = [];
    stubPersonalMerge(shopping, writes);
    when(() => shopping.createPersonalList(any())).thenAnswer((inv) async {
      final list = UnifiedShoppingList(
        name: inv.positionalArguments[0] as String,
        ownerId: flowUserId,
        ownerDisplayName: 'Test',
      );
      shopping.setShoppingState(lists: [list], personalLists: [list]);
      return list.id;
    });
    when(() => shopping.setActiveList(any())).thenAnswer((_) async => true);
    surfaces = [];
    observer = _Surfaces(surfaces);
  });

  tearDown(() => h.tearDown());

  Future<_Counted> open(WidgetTester tester, {String? mode}) async {
    if (mode != null) await PersistenceService().setVeckomenyViewMode(mode);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        navigatorObservers: [observer],
        onGenerateRoute: (s) => s.name == Routes.shoppingList
            ? MaterialPageRoute<void>(
                settings: s,
                builder: (_) => const Scaffold(body: Text('shopping-list')),
              )
            : null,
        home: const VeckomenyView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return _Counted(tester, surfaces);
  }

  Finder generateButton() => find.descendant(
    of: find.byKey(_generateKey),
    matching: find.text(_sv.menuGenerate),
  );

  Future<void> confirmMerge(_Counted c) =>
      c.tap('sheet confirm', find.byKey(ShoppingMergeSheet.confirmKey));

  void verifyEnd(_Counted c) {
    expect(observer.pushedNames, contains(Routes.shoppingList));
    expect(writes, isNotEmpty, reason: 'merge was applied to a list');
    expect(surfaces, _surfacesOnPath);
  }

  Future<void> placeAndShop(_Counted c) async {
    await c.tap('Placera automatiskt', find.text(_sv.menuPlaceAutoButton));
    await c.tap('Till inköpslista', find.text(_sv.menuToShoppingList));
    await confirmMerge(c);
    await c.tester.pumpAndSettle();
  }

  testWidgets('A shortest path, list mode', (tester) async {
    await withClock(Clock.fixed(flowMonday), () async {
      final c = await open(tester, mode: 'lista');
      await c.tap('Snabb vecka', find.text(_quickWeek));
      await c.tap('Generera meny', generateButton());
      await c.tap('Till inköpslista', find.text(_sv.menuToShoppingList));
      await confirmMerge(c);
      await tester.pumpAndSettle();
      verifyEnd(c);
      expect(h.repository.saves, isEmpty);
      expect(h.repository.plans, isEmpty);
      c.report('A-shortest-list-mode');
      expect(c.taps, 4);
      expect(c.typed, 0);
    });
  });

  testWidgets('B placed in the calendar', (tester) async {
    await withClock(Clock.fixed(flowMonday), () async {
      final c = await open(tester, mode: 'lista');
      await c.tap('Snabb vecka', find.text(_quickWeek));
      await c.tap('Generera meny', generateButton());
      await placeAndShop(c);
      verifyEnd(c);
      expect(h.repository.saves, hasLength(1));
      c.report('B-placed-in-calendar');
      expect(c.taps, 5);
      expect(c.typed, 0);
    });
  });

  testWidgets('C own wish typed', (tester) async {
    await withClock(Clock.fixed(flowMonday), () async {
      final c = await open(tester, mode: 'lista');
      await c.type('prompt', find.byType(TextField).first, '3 middagar');
      await c.tap('Generera meny', generateButton());
      expect(menu.prompts, ['3 middagar']);
      expect(c.seenTexts, contains(_wishPrompt));
      await placeAndShop(c);
      verifyEnd(c);
      expect(h.repository.saves, hasLength(1));
      c.report('C-own-wish');
      expect(c.taps, 4);
      expect(c.typed, 1);
    });
  });

  testWidgets('D default mode is list mode', (tester) async {
    await withClock(Clock.fixed(flowMonday), () async {
      final c = await open(tester);
      expect(find.text(_quickWeek), findsOneWidget);
      expect(find.text(_sv.weeklyMenuEmptyTitle), findsNothing);
      await c.tap('Snabb vecka', find.text(_quickWeek));
      await c.tap('Generera meny', generateButton());
      await placeAndShop(c);
      verifyEnd(c);
      expect(h.repository.saves, hasLength(1));
      c.report('D-default-mode');
      expect(c.taps, 5);
      expect(c.typed, 0);
    });
  });

  testWidgets('D2 starting in Kalender mode', (tester) async {
    await withClock(Clock.fixed(flowMonday), () async {
      final c = await open(tester, mode: 'kalender');
      expect(find.text(_quickWeek), findsOneWidget);
      expect(find.text(_sv.weeklyMenuEmptyTitle), findsOneWidget);
      expect(find.byKey(_generateKey), findsOneWidget);
      await c.tap('Snabb vecka', find.text(_quickWeek));
      await c.tap('Generera meny', generateButton());
      expect(find.text(_sv.menuPlaceAutoButton), findsNothing);
      expect(find.text(_sv.menuToShoppingList), findsOneWidget);
      await c.tap('Till inköpslista', find.text(_sv.menuToShoppingList));
      await confirmMerge(c);
      await tester.pumpAndSettle();
      verifyEnd(c);
      expect(h.repository.saves, hasLength(1));
      c.report('D2-kalender-mode');
      expect(c.taps, 4);
      expect(c.typed, 0);
    });
  });

  testWidgets('merge sheet defaults: all three switches on', (tester) async {
    await withClock(Clock.fixed(flowMonday), () async {
      final c = await open(tester, mode: 'lista');
      await c.tap('Snabb vecka', find.text(_quickWeek));
      await c.tap('Generera meny', generateButton());
      await c.tap('Till inköpslista', find.text(_sv.menuToShoppingList));
      await tester.tap(find.byKey(ShoppingMergeSheet.detailsToggleKey));
      await tester.pump(const Duration(milliseconds: 300));
      for (final which in ShoppingMergeSwitch.values) {
        final box = find.descendant(
          of: find.byKey(ShoppingMergeSheet.switchKey(which)),
          matching: find.byType(ButleryCheckbox),
        );
        expect(
          tester.widget<ButleryCheckbox>(box).value,
          isTrue,
          reason: '$which',
        );
      }
      expect(find.text(_sv.shoppingMergeDuplicatesTitle), findsOneWidget);
      expect(find.text(_sv.shoppingMergeConvertTitle), findsOneWidget);
      expect(find.text(_sv.shoppingMergePantryTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ShoppingMergeSheet.confirmKey),
          matching: find.text(_sv.shoppingMergeAdd(1)),
        ),
        findsOneWidget,
      );
    });
  });
}
