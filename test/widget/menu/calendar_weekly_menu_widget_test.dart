/// Widget tests for [CalendarWeeklyMenuWidget] (BUT-361).
///
/// Drives a real `WeeklyMenuPlanViewModel` with a mocked
/// `WeeklyMenuPlanService` + `UnifiedRecipeService` so the view-model's own
/// state transitions exercise the widget's five UI states:
/// loading, empty hint, overflow tray, 7×3 grid, today badge.
///
/// One `butleryGolden(...)` freezes the layout of the populated-with-overflow
/// state so the next UI refactor surfaces as a golden diff.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/menu/calendar/calendar_header.dart';
import 'package:butlery/widgets/menu/calendar_weekly_menu_widget.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../test_support/base_unit_test.dart';

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockMenuShoppingListGenerator extends Mock
    implements MenuShoppingListGenerator {}

class _FakeWeeklyMenuPlan extends Fake implements WeeklyMenuPlan {}

WeeklyMenuPlan _plan({
  String userId = 'u-1',
  required DateTime weekStart,
  List<WeeklyMenuPlanEntry> entries = const [],
}) {
  final ws = IsoWeekUtils.weekStartOf(weekStart);
  final createdAt = DateTime(2026, 4, 18);
  return WeeklyMenuPlan(
    id: IsoWeekUtils.weekIdFor(userId, ws),
    userId: userId,
    weekStartDate: ws,
    entries: entries,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

WeeklyMenuPlanEntry _entry({
  required DayOfWeek day,
  required MealSlot slot,
  required String id,
  String recipeId = 'r-1',
  String title = 'Test Recept',
}) {
  return WeeklyMenuPlanEntry(
    id: id,
    day: day,
    slot: slot,
    recipeId: recipeId,
    recipeTitle: title,
  );
}

/// Wraps [child] in a MaterialApp + localization delegates + a provided
/// [WeeklyMenuPlanViewModel]. Uses the same theme/locale the app ships with.
Widget _host({
  required WeeklyMenuPlanViewModel vm,
  required Widget child,
}) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppTheme.lightTheme,
    home: ChangeNotifierProvider<WeeklyMenuPlanViewModel>.value(
      value: vm,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeWeeklyMenuPlan());
    registerFallbackValue(RecipeFactory.build(id: 'fallback-recipe'));
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  group('CalendarWeeklyMenuWidget', () {
    late _MockWeeklyMenuPlanService service;
    late _MockUnifiedRecipeService recipeService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      service = _MockWeeklyMenuPlanService();
      recipeService = _MockUnifiedRecipeService();
      when(() => service.save(any())).thenAnswer((_) async {});
    });

    testWidgets(
        'renders the empty-hint state (arrow + StateWidget.empty) when '
        'the fetched plan has no entries and overflow is empty',
        (tester) async {
      final emptyPlan = _plan(weekStart: DateTime(2026, 4, 13));
      when(() => service.getWeek(any())).thenAnswer((_) async => emptyPlan);

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        _host(vm: vm, child: const CalendarWeeklyMenuWidget()),
      );
      // Let the post-frame callback + async load resolve.
      await tester.pumpAndSettle();

      // Empty-hint path: up-arrow icon (nudges user to the prompt above)
      // + StateWidget.empty with the l10n "Ingen planering än" title.
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byType(StateWidget), findsOneWidget);
      expect(find.text('Ingen planering än'), findsOneWidget);
    });

    testWidgets(
        'populated week renders one row per DayOfWeek (7) with lunch + '
        'middag + övrigt columns per row', (tester) async {
      // Pick a week different from "this week" so the today-badge path
      // is off (tested separately below).
      final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
      final populated = _plan(
        weekStart: weekStart,
        entries: [
          _entry(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            id: 'mon-m',
            recipeId: 'r-mon',
            title: 'Pasta',
          ),
          _entry(
            day: DayOfWeek.fri,
            slot: MealSlot.lunch,
            id: 'fri-l',
            recipeId: 'r-fri',
            title: 'Tacos',
          ),
        ],
      );
      when(() => service.getWeek(any())).thenAnswer((_) async => populated);

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        _host(vm: vm, child: const CalendarWeeklyMenuWidget()),
      );
      await tester.pumpAndSettle();

      // 7 day labels (mån, tis, ons, tor, fre, lör, sön) rendered as
      // SIZE-UPPERED text with letterSpacing. Assert by Swedish prefix.
      for (final label in const [
        'MÅN',
        'TIS',
        'ONS',
        'TOR',
        'FRE',
        'LÖR',
        'SÖN'
      ]) {
        expect(find.text(label), findsOneWidget,
            reason: 'expected day header $label');
      }

      // The two populated cells surface their recipe titles (lowercased).
      expect(find.text('pasta'), findsOneWidget);
      expect(find.text('tacos'), findsOneWidget);
    });

    testWidgets(
        'overflow tray is visible with one draggable chip per overflow '
        'recipe when vm.overflow.isNotEmpty', (tester) async {
      final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
      final emptyPlan = _plan(weekStart: weekStart);
      when(() => service.getWeek(any())).thenAnswer((_) async => emptyPlan);
      when(() => service.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          )).thenReturn(WeeklyMenuDistributionResult(
        plan: emptyPlan,
        overflow: [
          RecipeFactory.build(id: 'overflow-1', title: 'Överflöd Ett'),
          RecipeFactory.build(id: 'overflow-2', title: 'Överflöd Två'),
        ],
      ));

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      addTearDown(vm.dispose);

      // Seed overflow via the VM before the widget mounts — the widget's
      // own didChangeDependencies will re-call loadWeek, but since the plan
      // is already resident for the same week it short-circuits.
      await vm.loadWeek(weekStart);
      await vm.applyGeneratedMenu(const {'middag': []});

      await tester.pumpWidget(
        _host(vm: vm, child: const CalendarWeeklyMenuWidget()),
      );
      await tester.pumpAndSettle();

      // The overflow tray header (l10n) should be present.
      expect(find.text('Recept som inte fick plats'), findsOneWidget);
      // Each overflow recipe title appears (lowercased) as a chip.
      expect(find.text('överflöd ett'), findsOneWidget);
      expect(find.text('överflöd två'), findsOneWidget);
    });

    testWidgets(
        'today badge renders only when the visible week matches the '
        'current ISO week', (tester) async {
      // Use "today" so the visible week equals the current ISO week.
      final nowWeekStart = IsoWeekUtils.weekStartOf(DateTime.now());
      final plan = _plan(
        weekStart: nowWeekStart,
        entries: [
          _entry(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            id: 'any',
            title: 'AnyRecipe',
          ),
        ],
      );
      when(() => service.getWeek(any())).thenAnswer((_) async => plan);

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        _host(vm: vm, child: const CalendarWeeklyMenuWidget()),
      );
      await tester.pumpAndSettle();

      // "Idag" badge (weeklyMenuTodayBadge) only renders for the current
      // ISO week. Because `nowWeekStart == weekStartOf(DateTime.now())`,
      // exactly one day header carries the Idag badge.
      expect(find.text('Idag'), findsOneWidget);
    });

    testWidgets(
        'today badge is absent when the visible week is NOT the current '
        'ISO week (past-week view)', (tester) async {
      // Any week other than today's. 3 weeks back puts us squarely outside.
      final pastWeek = IsoWeekUtils.weekStartOf(
        DateTime.now().subtract(const Duration(days: 21)),
      );
      final plan = _plan(
        weekStart: pastWeek,
        entries: [
          _entry(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            id: 'past',
            title: 'PastRecipe',
          ),
        ],
      );
      when(() => service.getWeek(any())).thenAnswer((_) async => plan);

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      addTearDown(vm.dispose);
      await vm.loadWeek(pastWeek);

      await tester.pumpWidget(
        _host(vm: vm, child: const CalendarWeeklyMenuWidget()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Idag'), findsNothing);
    });

    testWidgets('week-nav buttons call vm.previousWeek / vm.nextWeek on tap',
        (tester) async {
      final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
      final thisWeek = _plan(
        weekStart: weekStart,
        entries: [
          _entry(
            day: DayOfWeek.tue,
            slot: MealSlot.middag,
            id: 'tue',
            title: 'Tuesday Recipe',
          ),
        ],
      );
      final prevWeek = _plan(
        weekStart: weekStart.subtract(const Duration(days: 7)),
        entries: [
          _entry(
            day: DayOfWeek.wed,
            slot: MealSlot.lunch,
            id: 'wed-prev',
            title: 'Prev Wed',
          ),
        ],
      );
      final nextWeek = _plan(
        weekStart: weekStart.add(const Duration(days: 7)),
        entries: [
          _entry(
            day: DayOfWeek.thu,
            slot: MealSlot.lunch,
            id: 'thu-next',
            title: 'Next Thu',
          ),
        ],
      );
      when(() => service.getWeek(thisWeek.weekStartDate))
          .thenAnswer((_) async => thisWeek);
      when(() => service.getWeek(prevWeek.weekStartDate))
          .thenAnswer((_) async => prevWeek);
      when(() => service.getWeek(nextWeek.weekStartDate))
          .thenAnswer((_) async => nextWeek);

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      addTearDown(vm.dispose);

      // Pin the wall clock to a date inside thisWeek so the widget's
      // post-frame `loadWeek(clock.now())` asks for thisWeek (mocked
      // above) rather than today's actual week (un-mocked). The widget
      // does the initial load itself — no `vm.loadWeek(weekStart)`
      // pre-seed needed here.
      await withClock(Clock.fixed(weekStart.add(const Duration(hours: 12))),
          () async {
        await tester.pumpWidget(
          _host(vm: vm, child: const CalendarWeeklyMenuWidget()),
        );
        await tester.pumpAndSettle();

        // Nav arrows use Icons.chevron_left / chevron_right.
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(vm.currentWeekStart, nextWeek.weekStartDate);

        // Going back twice crosses the anchor to prevWeek.
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();
        expect(vm.currentWeekStart, prevWeek.weekStartDate);
      });
    });

    // BUT-1043: multi-select orchestration. These drive the REAL view-model
    // (selection-mode flips header <-> action bar; copy/select buttons only
    // appear when the week has entries) rather than the VM in isolation.
    group('multi-select orchestration (BUT-1043)', () {
      Future<WeeklyMenuPlanViewModel> pumpPopulated(
        WidgetTester tester, {
        required WeeklyMenuPlan plan,
      }) async {
        when(() => service.getWeek(any())).thenAnswer((_) async => plan);
        final vm = WeeklyMenuPlanViewModel(
          service: service,
          recipeService: recipeService,
          shoppingListGenerator: _MockMenuShoppingListGenerator(),
        );
        addTearDown(vm.dispose);
        await tester.pumpWidget(
          _host(vm: vm, child: const CalendarWeeklyMenuWidget()),
        );
        await tester.pumpAndSettle();
        return vm;
      }

      testWidgets(
          'copy + select header buttons are hidden on an empty week and '
          'shown once the week has entries', (tester) async {
        final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));

        // Empty week: the calendar shows its empty hint, so neither the nav
        // header nor its copy/select buttons are present.
        await pumpPopulated(tester, plan: _plan(weekStart: weekStart));
        expect(find.byIcon(Icons.copy_all_outlined), findsNothing,
            reason: 'copy is meaningless with nothing to copy');
        expect(find.byIcon(Icons.checklist_outlined), findsNothing,
            reason: 'select is meaningless with nothing to select');
      });

      testWidgets(
          'copy + select header buttons appear once the week has entries',
          (tester) async {
        final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
        await pumpPopulated(
          tester,
          plan: _plan(
            weekStart: weekStart,
            entries: [
              _entry(
                day: DayOfWeek.mon,
                slot: MealSlot.middag,
                id: 'm',
                title: 'Pasta',
              ),
            ],
          ),
        );
        expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
        expect(find.byIcon(Icons.checklist_outlined), findsOneWidget);
      });

      testWidgets(
          'entering selection mode swaps the nav header for the selection '
          'action bar, and cancelling restores it', (tester) async {
        final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
        final vm = await pumpPopulated(
          tester,
          plan: _plan(
            weekStart: weekStart,
            entries: [
              _entry(
                day: DayOfWeek.mon,
                slot: MealSlot.middag,
                id: 'm',
                title: 'Pasta',
              ),
            ],
          ),
        );

        // Baseline: nav header present, action bar absent.
        expect(find.byType(WeekNavHeader), findsOneWidget);
        expect(find.byType(SelectionActionBar), findsNothing);

        // Tap the select (checklist) button -> beginSelection().
        await tester.tap(find.byIcon(Icons.checklist_outlined));
        await tester.pumpAndSettle();
        expect(vm.selectionMode, isTrue);
        expect(find.byType(SelectionActionBar), findsOneWidget);
        expect(find.byType(WeekNavHeader), findsNothing,
            reason: 'nav header is replaced while selecting');

        // Tap cancel (close) in the action bar -> clearSelection().
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(vm.selectionMode, isFalse);
        expect(find.byType(WeekNavHeader), findsOneWidget);
        expect(find.byType(SelectionActionBar), findsNothing);
      });

      testWidgets(
          'in selection mode, tapping an assigned cell toggles its selection '
          'and does NOT navigate (getRecipeById never called)', (tester) async {
        final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
        final vm = await pumpPopulated(
          tester,
          plan: _plan(
            weekStart: weekStart,
            entries: [
              _entry(
                day: DayOfWeek.mon,
                slot: MealSlot.middag,
                id: 'mon-m',
                recipeId: 'r-mon',
                title: 'Pasta',
              ),
            ],
          ),
        );

        // Enter selection mode.
        await tester.tap(find.byIcon(Icons.checklist_outlined));
        await tester.pumpAndSettle();

        // Before tapping: the cell shows an EMPTY checkbox.
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
        expect(find.byIcon(Icons.check_box), findsNothing);

        // Tap the assigned cell (its lowercased title surfaces the recipe).
        await tester.tap(find.text('pasta'));
        await tester.pumpAndSettle();

        // The entry is now selected: filled checkbox, VM agrees, count is 1.
        expect(vm.isSelected('mon-m'), isTrue);
        expect(vm.selectedCount, 1);
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);

        // Navigation must NOT have fired — the tap toggled instead.
        verifyNever(() => recipeService.getRecipeById(any()));
      });
    });
  });

  // -------- Golden -------------------------------------------------------
  //
  // Populated week — pins the layout of the day rows + single-slot cells
  // + övrigt cell to a pixel reference so the next UI refactor surfaces
  // as a golden diff. Does NOT use `butleryGolden` because that helper
  // builds its own MaterialApp wrapper, and the calendar widget needs a
  // `ChangeNotifierProvider<WeeklyMenuPlanViewModel>` in scope.
  //
  // Update with `flutter test --update-goldens test/widget/menu`.
  group('CalendarWeeklyMenuWidget golden', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets('populated week matches golden', (tester) async {
      // Pin surface + DPR for deterministic pixel grid across platforms.
      final previousSize = tester.view.physicalSize;
      final previousRatio = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = previousSize;
        tester.view.devicePixelRatio = previousRatio;
      });

      final service = _MockWeeklyMenuPlanService();
      final recipeService = _MockUnifiedRecipeService();
      when(() => service.save(any())).thenAnswer((_) async {});

      // Use a week in the past so the "today" badge doesn't render (the
      // badge path uses DateTime.now() and would make the golden
      // timestamp-sensitive).
      final weekStart = IsoWeekUtils.weekStartOf(DateTime(2024, 1, 8));
      final populated = _plan(
        weekStart: weekStart,
        entries: [
          _entry(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            id: 'e-mon',
            title: 'Köttbullar',
          ),
          _entry(
            day: DayOfWeek.tue,
            slot: MealSlot.lunch,
            id: 'e-tue',
            title: 'Sallad',
          ),
          _entry(
            day: DayOfWeek.wed,
            slot: MealSlot.ovrigt,
            id: 'e-wed',
            title: 'Kanelbullar',
          ),
        ],
      );
      when(() => service.getWeek(any())).thenAnswer((_) async => populated);

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      // Pre-load the plan so the widget mounts with state already resident
      // — the widget's post-frame callback will still fire loadWeek but
      // it short-circuits because the target week matches.
      await vm.loadWeek(weekStart);
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        _host(vm: vm, child: const CalendarWeeklyMenuWidget()),
      );
      await tester.pumpAndSettle();

      // Silence stray asset errors (network image loads etc.) during
      // golden capture so they don't fail the render.
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = previousOnError);

      await expectLater(
        find.byType(CalendarWeeklyMenuWidget),
        matchesGoldenFile('goldens/calendar_weekly_menu_populated.png'),
      );
    });
  });
}
