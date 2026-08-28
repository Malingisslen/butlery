/// Widget tests for [CalendarWeeklyMenuWidget] (BUT-361).
///
/// Drives a real `WeeklyMenuPlanViewModel` with a mocked
/// `WeeklyMenuPlanService` + `UnifiedRecipeService` so the view-model's own
/// state transitions exercise the widget.
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

    testWidgets('renders the empty-hint state (arrow + StateWidget.empty) when '
        'the fetched plan has no entries and overflow is empty', (
      tester,
    ) async {
      final emptyPlan = _plan(weekStart: DateTime(2026, 4, 13));
      when(() => service.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: emptyPlan, readFailed: false),
      );

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
      'a failed read offers a retry, and it retries the REQUESTED week '
      '(BUT-1939)',
      (tester) async {
        // The error state replaces the whole calendar, week navigation
        // included, so the "Försök igen" the message names has to be a real
        // control here — and it must not silently retry today's week.
        final requested = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 20));
        final plan = _plan(weekStart: requested);
        var failNext = true;
        when(() => service.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: failNext),
        );

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
        await vm.loadWeek(requested);
        await tester.pumpAndSettle();

        expect(find.text('Försök igen'), findsOneWidget);

        failNext = false;
        // Without this the verify below is already satisfied by the two loads
        // that happen BEFORE the tap, so it would say nothing about the tap.
        clearInteractions(service);
        await tester.tap(find.text('Försök igen'));
        await tester.pumpAndSettle();

        verify(() => service.readWeek(requested)).called(1);
        expect(vm.plan, isNotNull);
        expect(vm.currentWeekStart, equals(requested));
      },
    );

    testWidgets('populated week renders one row per DayOfWeek (7) with lunch + '
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
      when(() => service.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: populated, readFailed: false),
      );

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
        'SÖN',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'expected day header $label',
        );
      }

      // The two populated cells surface their recipe titles (lowercased).
      expect(find.text('pasta'), findsOneWidget);
      expect(find.text('tacos'), findsOneWidget);
    });

    testWidgets('overflow tray is visible with one draggable chip per overflow '
        'recipe when vm.overflow.isNotEmpty', (tester) async {
      final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
      final emptyPlan = _plan(weekStart: weekStart);
      when(() => service.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: emptyPlan, readFailed: false),
      );
      when(
        () => service.distributeFromGeneratedMenu(
          generated: any(named: 'generated'),
          weekStart: any(named: 'weekStart'),
          existing: any(named: 'existing'),
          now: any(named: 'now'),
          dayPins: any(named: 'dayPins'),
        ),
      ).thenReturn(
        WeeklyMenuDistributionResult(
          plan: emptyPlan,
          overflow: [
            RecipeFactory.build(id: 'overflow-1', title: 'Överflöd Ett'),
            RecipeFactory.build(id: 'overflow-2', title: 'Överflöd Två'),
          ],
        ),
      );

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      addTearDown(vm.dispose);

      // Seed overflow via the VM before the widget mounts.
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

    testWidgets('today badge renders only when the visible week matches the '
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
      when(() => service.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
      );

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
      'ISO week (past-week view)',
      (tester) async {
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
        when(() => service.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
        );

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
      },
    );

    testWidgets('week-nav buttons call vm.previousWeek / vm.nextWeek on tap', (
      tester,
    ) async {
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
      when(
        () => service.readWeek(thisWeek.weekStartDate),
      ).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: thisWeek, readFailed: false),
      );
      when(
        () => service.readWeek(prevWeek.weekStartDate),
      ).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: prevWeek, readFailed: false),
      );
      when(
        () => service.readWeek(nextWeek.weekStartDate),
      ).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: nextWeek, readFailed: false),
      );

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
      await withClock(
        Clock.fixed(weekStart.add(const Duration(hours: 12))),
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
        },
      );
    });

    // BUT-1043: multi-select orchestration. These drive the REAL view-model
    // (selection-mode flips header <-> action bar; copy/select buttons only
    // appear when the week has entries) rather than the VM in isolation.
    group('multi-select orchestration (BUT-1043)', () {
      Future<WeeklyMenuPlanViewModel> pumpPopulated(
        WidgetTester tester, {
        required WeeklyMenuPlan plan,
      }) async {
        when(() => service.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
        );
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
        'shown once the week has entries',
        (tester) async {
          final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));

          // Empty week: the calendar shows its empty hint, so neither the nav
          // header nor its copy/select buttons are present.
          await pumpPopulated(tester, plan: _plan(weekStart: weekStart));
          expect(
            find.byIcon(Icons.copy_all_outlined),
            findsNothing,
            reason: 'copy is meaningless with nothing to copy',
          );
          expect(
            find.byIcon(Icons.checklist_outlined),
            findsNothing,
            reason: 'select is meaningless with nothing to select',
          );
        },
      );

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
        },
      );

      testWidgets(
        'entering selection mode swaps the nav header for the selection '
        'action bar, and cancelling restores it',
        (tester) async {
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
          expect(
            find.byType(WeekNavHeader),
            findsNothing,
            reason: 'nav header is replaced while selecting',
          );

          // Tap cancel (close) in the action bar -> clearSelection().
          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
          expect(vm.selectionMode, isFalse);
          expect(find.byType(WeekNavHeader), findsOneWidget);
          expect(find.byType(SelectionActionBar), findsNothing);
        },
      );

      testWidgets(
        'in selection mode, tapping an assigned cell toggles its selection '
        'and does NOT navigate (getRecipeById never called)',
        (tester) async {
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
        },
      );
    });

    // BUT-1280: the bulk-move target-picker flow. Drives the full UI path the
    // user takes after selecting entries: open the "Flytta till" bottom sheet
    // from the selection action bar, pick a (day, slot) target -> the move is
    // persisted via the service + a success snackbar is shown; and the
    // dismiss-without-picking path -> no move, sheet just closes.
    group('bulk-move target picker (BUT-1280)', () {
      /// Pump a one-entry week, enter selection mode, and select the single
      /// entry so the move action becomes enabled. Returns the live VM.
      Future<WeeklyMenuPlanViewModel> pumpSelectedOneEntry(
        WidgetTester tester, {
        required WeeklyMenuPlan plan,
      }) async {
        when(() => service.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
        );
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

        // Enter selection mode and select the one populated cell.
        await tester.tap(find.byIcon(Icons.checklist_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.text('pasta'));
        await tester.pumpAndSettle();
        expect(vm.selectedCount, 1);
        return vm;
      }

      WeeklyMenuPlan oneEntryWeek() {
        final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
        return _plan(
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
        );
      }

      testWidgets(
        'tapping move opens the target sheet, picking a (day, slot) fires '
        'bulkMoveEntries and shows the success snackbar',
        (tester) async {
          final plan = oneEntryWeek();
          // The bulk move re-reads the same week afterwards (_fetchWeek), so
          // readWeek is already stubbed by pumpSelectedOneEntry to return `plan`.
          when(
            () => service.bulkMoveEntries(
              weekStart: any(named: 'weekStart'),
              entryIds: any(named: 'entryIds'),
              toDay: any(named: 'toDay'),
              toSlot: any(named: 'toSlot'),
            ),
          ).thenAnswer((_) async => 1);

          final vm = await pumpSelectedOneEntry(tester, plan: plan);

          // The action bar's move button (drive_file_move_outline) opens the
          // "Flytta till" target sheet.
          await tester.tap(find.byIcon(Icons.drive_file_move_outline));
          await tester.pumpAndSettle();
          expect(
            find.text('Flytta till'),
            findsOneWidget,
            reason: 'the bulk-move target sheet header',
          );
          // 7 days × 3 slots = 21 target rows in the sheet.
          expect(find.byType(ListTile), findsNWidgets(21));

          // Pick "mån · lunch" — the first tile in the sheet (guaranteed
          // on-screen at the default 800x600 surface) and a unique title.
          await tester.tap(find.text('mån · lunch'));
          await tester.pumpAndSettle();

          // The move was persisted to the target the user picked.
          verify(
            () => service.bulkMoveEntries(
              weekStart: any(named: 'weekStart'),
              entryIds: ['mon-m'],
              toDay: DayOfWeek.mon,
              toSlot: MealSlot.lunch,
            ),
          ).called(1);
          // Success snackbar: "1 recept flyttat" (singular plural form).
          expect(find.text('1 recept flyttat'), findsOneWidget);
          // Selection mode is exited after a successful move.
          expect(vm.selectionMode, isFalse);
          expect(find.byType(SelectionActionBar), findsNothing);
        },
      );

      testWidgets(
        'a failed bulk move (service returns null path) shows the error '
        'snackbar instead of the success one',
        (tester) async {
          final plan = oneEntryWeek();
          // Throwing makes the VM's executeAsyncVoid fail, so bulkMoveSelected
          // returns null and the view shows the error snackbar.
          when(
            () => service.bulkMoveEntries(
              weekStart: any(named: 'weekStart'),
              entryIds: any(named: 'entryIds'),
              toDay: any(named: 'toDay'),
              toSlot: any(named: 'toSlot'),
            ),
          ).thenThrow(StateError('move failed'));

          await pumpSelectedOneEntry(tester, plan: plan);

          await tester.tap(find.byIcon(Icons.drive_file_move_outline));
          await tester.pumpAndSettle();
          await tester.tap(find.text('mån · lunch'));
          await tester.pumpAndSettle();

          // The failure surfaces the error copy (in the snackbar, and also in
          // the VM's error-state body via the errorPrefix) — at least once, and
          // never the success copy.
          expect(find.text('Kunde inte flytta recepten'), findsWidgets);
          expect(find.text('1 recept flyttat'), findsNothing);
        },
      );

      testWidgets(
        'dismissing the target sheet without picking leaves the selection '
        'intact and never calls bulkMoveEntries',
        (tester) async {
          final plan = oneEntryWeek();
          final vm = await pumpSelectedOneEntry(tester, plan: plan);

          await tester.tap(find.byIcon(Icons.drive_file_move_outline));
          await tester.pumpAndSettle();
          expect(find.text('Flytta till'), findsOneWidget);

          // Dismiss by tapping the modal barrier (no target chosen).
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();

          // Sheet is gone, no move happened, and the selection survives so the
          // user can re-open the picker.
          expect(find.text('Flytta till'), findsNothing);
          verifyNever(
            () => service.bulkMoveEntries(
              weekStart: any(named: 'weekStart'),
              entryIds: any(named: 'entryIds'),
              toDay: any(named: 'toDay'),
              toSlot: any(named: 'toSlot'),
            ),
          );
          expect(vm.selectionMode, isTrue);
          expect(vm.selectedCount, 1);
        },
      );
    });

    // BUT-1962: the ViewModel's `clearWeek()` bool is pinned in the VM suite,
    // but nothing pinned the VIEW consuming it — reverting the `!cleared` gate
    // in `_onClearWeek` reddened no test at any layer, and that gate IS the
    // user-visible half: a refused clear used to announce "Veckan rensad" over
    // the error state, offering an "Ångra" that arms nothing.
    group('clear-week announcement is gated on the outcome', () {
      Future<WeeklyMenuPlanViewModel> pumpWeekWithOneEntry(
        WidgetTester tester,
      ) async {
        final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
        final plan = _plan(
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
        );
        when(() => service.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
        );
        when(
          () => service.clearWeek(any()),
        ).thenReturn(_plan(weekStart: weekStart));
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

      testWidgets('a REFUSED clear shows no success snackbar', (tester) async {
        await pumpWeekWithOneEntry(tester);
        when(() => service.save(any())).thenThrow(Exception('denied'));

        await tester.tap(find.byTooltip('Rensa veckan'));
        await tester.pumpAndSettle();

        expect(find.text('Veckan rensad'), findsNothing);
      });

      // The control: without it the assertion above would pass against a view
      // that never shows the snackbar at all.
      testWidgets('a successful clear does show it', (tester) async {
        await pumpWeekWithOneEntry(tester);
        when(() => service.save(any())).thenAnswer((_) async {});

        await tester.tap(find.byTooltip('Rensa veckan'));
        await tester.pumpAndSettle();

        expect(find.text('Veckan rensad'), findsOneWidget);
      });
    });

    // BUT-1280 follow-up: the copy-week affordance's widget-layer wiring. The
    // VM's copyWeekToNext is unit-tested in isolation, but the dialog gate +
    // the three-way result snackbar (N copied / nothing-to-copy / failure)
    // live only in _onCopyWeek and were previously asserted only by icon
    // presence. These drive the real tap -> confirm -> snackbar path.
    group('copy-week affordance', () {
      Future<WeeklyMenuPlanViewModel> pumpOneEntryWeek(
        WidgetTester tester,
      ) async {
        final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));
        final plan = _plan(
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
        );
        when(() => service.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
        );
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

      final from = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));

      testWidgets('tapping copy opens a confirm dialog; confirming calls '
          'service.copyWeek(from -> +7d) and shows the count snackbar', (
        tester,
      ) async {
        when(
          () => service.copyWeek(
            fromWeekStart: any(named: 'fromWeekStart'),
            toWeekStart: any(named: 'toWeekStart'),
          ),
        ).thenAnswer((_) async => 2);

        await pumpOneEntryWeek(tester);

        await tester.tap(find.byIcon(Icons.copy_all_outlined));
        await tester.pumpAndSettle();
        // Confirm dialog header (l10n weeklyMenuCopyToNextConfirmTitle).
        expect(find.text('Kopiera veckan?'), findsOneWidget);

        // Continue (commonContinue) fires the copy.
        await tester.tap(find.text('Fortsätt'));
        await tester.pumpAndSettle();

        verify(
          () => service.copyWeek(
            fromWeekStart: from,
            toWeekStart: from.add(const Duration(days: 7)),
          ),
        ).called(1);
        // Plural-form result: 2 -> "2 recept kopierade till nästa vecka".
        expect(
          find.text('2 recept kopierade till nästa vecka'),
          findsOneWidget,
        );
      });

      testWidgets('a copy that touches nothing (count 0) shows the '
          '"already there" snackbar, not a numbered one', (tester) async {
        when(
          () => service.copyWeek(
            fromWeekStart: any(named: 'fromWeekStart'),
            toWeekStart: any(named: 'toWeekStart'),
          ),
        ).thenAnswer((_) async => 0);

        await pumpOneEntryWeek(tester);

        await tester.tap(find.byIcon(Icons.copy_all_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fortsätt'));
        await tester.pumpAndSettle();

        // =0 plural branch — distinct copy from the numbered success.
        expect(
          find.text('Inget kopierades – allt finns redan nästa vecka'),
          findsOneWidget,
        );
      });

      testWidgets(
        'a failed copy (service throws) shows the error snackbar and no '
        'success copy',
        (tester) async {
          when(
            () => service.copyWeek(
              fromWeekStart: any(named: 'fromWeekStart'),
              toWeekStart: any(named: 'toWeekStart'),
            ),
          ).thenThrow(StateError('copy failed'));

          await pumpOneEntryWeek(tester);

          await tester.tap(find.byIcon(Icons.copy_all_outlined));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Fortsätt'));
          await tester.pumpAndSettle();

          // errorPrefix + snackbar both surface this copy.
          expect(find.text('Kunde inte kopiera veckan'), findsWidgets);
          expect(
            find.textContaining('kopierade till nästa vecka'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'cancelling the confirm dialog never calls service.copyWeek',
        (tester) async {
          await pumpOneEntryWeek(tester);

          await tester.tap(find.byIcon(Icons.copy_all_outlined));
          await tester.pumpAndSettle();
          expect(find.text('Kopiera veckan?'), findsOneWidget);

          // Cancel (commonCancel) — dialog closes, no copy fires.
          await tester.tap(find.text('Avbryt'));
          await tester.pumpAndSettle();

          expect(find.text('Kopiera veckan?'), findsNothing);
          verifyNever(
            () => service.copyWeek(
              fromWeekStart: any(named: 'fromWeekStart'),
              toWeekStart: any(named: 'toWeekStart'),
            ),
          );
        },
      );
    });
  });

  // -------- Golden -------------------------------------------------------
  //
  // Populated week.
  //
  // The blanket `FlutterError.onError` below is the pattern
  // `test/widget/golden/golden_helper_redness_test.dart` pins as broken:
  // `matchesGoldenFile` runs its comparator inside `binding.runAsync`, so a
  // mismatch is routed to that handler and the matcher completes with `null`,
  // which it reads as a match. Every pixel difference and every wrong-size
  // render passes. (A MISSING golden file still fails — that error surfaces
  // through the matcher itself, not through the handler.)
  //
  // Not hypothetical: `failures/` carries master/test images from green runs.
  // This golden is the only one outside `butleryGolden`, which is where the
  // error filter and the platform pin live. Repair: BUT-1978.
  //
  // Update with `flutter test --update-goldens test/widget/menu`.
  group('CalendarWeeklyMenuWidget golden', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets('populated week matches golden', (tester) async {
      // Surface + DPR are pinned so the render is at least stable within one
      // platform. It does NOT make the bytes portable — BUT-1931 measured 7 of
      // 8 goldens differing on ubuntu and 6 of 7 on macOS.
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
      when(() => service.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(plan: populated, readFailed: false),
      );

      final vm = WeeklyMenuPlanViewModel(
        service: service,
        recipeService: recipeService,
        shoppingListGenerator: _MockMenuShoppingListGenerator(),
      );
      // Pre-load the plan so the widget mounts with state already resident.
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
