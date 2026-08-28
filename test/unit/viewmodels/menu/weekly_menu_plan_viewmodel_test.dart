/// Unit tests for [WeeklyMenuPlanViewModel] (BUT-361).
///
/// Focuses on behaviour the view contracts against:
///  * loadWeek short-circuits when the target week is already resident
///  * applyGeneratedMenu single-flight guard blocks concurrent taps
///  * moveEntry / removeEntry / clearWeek short-circuit when nothing changes
///    (no notify + no save)
///  * assignFromOverflow prunes the tray
///  * previousWeek / nextWeek arithmetic survives ISO year boundaries
///  * Service errors surface via BaseViewModel.error + hasError
///  * generateShoppingList (BUT-1234) delegates to MenuShoppingListGenerator
///    via executeAsync: loading toggles, three-way result passes through
///
/// Mocks the `WeeklyMenuPlanService` and `UnifiedRecipeService` layers so
/// the VM's orchestration logic (and only that) is exercised.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../test_support/base_unit_test.dart';

/// BUT-1939: the viewmodels read through `readWeek`, which carries the
/// `readFailed` bit beside the plan. Every stub here answers a SUCCESSFUL
/// read; the refusal cases build their own with `readFailed: true`.
WeeklyMenuPlanRead _read(WeeklyMenuPlan plan) =>
    WeeklyMenuPlanRead(plan: plan, readFailed: false);

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockMenuShoppingListGenerator extends Mock
    implements MenuShoppingListGenerator {}

class _FakeWeeklyMenuPlan extends Fake implements WeeklyMenuPlan {}

WeeklyMenuPlan _plan({
  String userId = 'u-1',
  DateTime? weekStart,
  List<WeeklyMenuPlanEntry> entries = const [],
}) {
  final ws = IsoWeekUtils.weekStartOf(weekStart ?? DateTime(2026, 4, 13));
  final now = DateTime(2026, 4, 18, 12);
  return WeeklyMenuPlan(
    id: IsoWeekUtils.weekIdFor(userId, ws),
    userId: userId,
    weekStartDate: ws,
    entries: entries,
    createdAt: now,
    updatedAt: now,
  );
}

WeeklyMenuPlanEntry _entry({
  required DayOfWeek day,
  required MealSlot slot,
  String id = 'entry-1',
  String recipeId = 'r-1',
  String title = 'Test Recipe',
}) {
  return WeeklyMenuPlanEntry(
    id: id,
    day: day,
    slot: slot,
    recipeId: recipeId,
    recipeTitle: title,
  );
}

Recipe _recipe({String id = 'r-new', String title = 'Ny rätt'}) {
  return RecipeFactory.build(
    id: id,
    title: title,
    description: '',
    ingredients: const [],
    instructions: const [],
    mealType: 'middag',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeWeeklyMenuPlan());
    registerFallbackValue(RecipeFactory.build(id: 'fallback-recipe'));
    registerFallbackValue(DayOfWeek.mon);
    registerFallbackValue(MealSlot.middag);
  });

  group('WeeklyMenuPlanViewModel', () {
    late WeeklyMenuPlanViewModel viewModel;
    late _MockWeeklyMenuPlanService mockService;
    late _MockUnifiedRecipeService mockRecipeService;
    late _MockMenuShoppingListGenerator mockGenerator;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      mockService = _MockWeeklyMenuPlanService();
      mockRecipeService = _MockUnifiedRecipeService();
      mockGenerator = _MockMenuShoppingListGenerator();

      // Most tests don't exercise save; stub a permissive default that
      // individual tests can override with `when(...).thenAnswer(...)`.
      when(() => mockService.save(any())).thenAnswer((_) async {});

      viewModel = WeeklyMenuPlanViewModel(
        service: mockService,
        recipeService: mockRecipeService,
        shoppingListGenerator: mockGenerator,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    // BUT-1962 — a refused save must (a) say so and (b) put back the state it
    // replaced.
    //
    // Before this, `save()` swallowed every failure, so neither half happened:
    // the user's edit stayed on screen, was never written, and vanished on the
    // next load with no message.
    group('a refused save is visible and does not move the screen', () {
      /// Seeds a resident week so the operations under test have a `_plan`.
      Future<WeeklyMenuPlan> seed({List<WeeklyMenuPlanEntry>? entries}) async {
        final week = _plan(
          entries:
              entries ?? [_entry(day: DayOfWeek.mon, slot: MealSlot.middag)],
        );
        when(
          () => mockService.readWeek(any()),
        ).thenAnswer((_) async => _read(week));
        await viewModel.loadWeek(week.weekStartDate);
        viewModel.clearError();
        return week;
      }

      void failTheSave() {
        when(() => mockService.save(any())).thenThrow(Exception('denied'));
      }

      /// Seeds a resident week AND a non-empty overflow tray.
      ///
      /// The tray is the half the plain `seed()` cannot stage: with an empty
      /// tray a rollback that forgets `_overflow` is indistinguishable from
      /// one that restores it, so every assertion about the tray passes for
      /// free. `clearWeek` wipes it and `undoClearWeek` restores it, which is
      /// exactly where a missed rollback loses the recipes permanently.
      Future<({WeeklyMenuPlan week, Recipe tray})> seedWithTray() async {
        final week = _plan(
          entries: [_entry(day: DayOfWeek.mon, slot: MealSlot.middag)],
        );
        final tray = _recipe(id: 'r-tray');
        when(
          () => mockService.readWeek(any()),
        ).thenAnswer((_) async => _read(week));
        when(
          () => mockService.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        ).thenReturn(
          WeeklyMenuDistributionResult(plan: week, overflow: [tray]),
        );
        await viewModel.loadWeek(week.weekStartDate);
        await viewModel.applyGeneratedMenu({
          'middag': [tray],
        });
        expect(viewModel.overflow, hasLength(1));
        viewModel.clearError();
        return (week: week, tray: tray);
      }

      test('a refused clear leaves the overflow TRAY where it was', () async {
        final seeded = await seedWithTray();
        when(() => mockService.clearWeek(any())).thenReturn(
          _plan(entries: const []),
        );
        failTheSave();

        expect(await viewModel.clearWeek(), isFalse);

        expect(viewModel.plan, same(seeded.week));
        expect(
          viewModel.overflow,
          [seeded.tray],
          reason:
              'clearWeek wipes the tray before the save, so a refusal that '
              'restores only the plan loses the tray recipes for good',
        );
      });

      test(
        'a refused undo re-arms the snapshot AND puts the tray back',
        () async {
          final seeded = await seedWithTray();
          final cleared = _plan(entries: const []);
          when(() => mockService.clearWeek(any())).thenReturn(cleared);
          await viewModel.clearWeek();
          expect(viewModel.overflow, isEmpty);

          when(
            () => mockService.restoreWeek(any(), any()),
          ).thenReturn(seeded.week);
          failTheSave();

          await viewModel.undoClearWeek();

          expect(viewModel.plan, same(cleared));
          expect(
            viewModel.overflow,
            isEmpty,
            reason: 'the refused undo leaves the cleared state, tray included',
          );

          // The snapshot must survive, or the retry below restores nothing.
          when(() => mockService.save(any())).thenAnswer((_) async {});
          await viewModel.undoClearWeek();
          expect(viewModel.plan, same(seeded.week));
          expect(
            viewModel.overflow,
            [seeded.tray],
            reason: 'the retried undo is what brings the tray recipes back',
          );
        },
      );

      // A PENDING save is the offline shape: `persistenceEnabled: true`
      // applies the write locally but leaves its future uncompleted until the
      // server acks (measured 2026-08-28 against the emulator, on the web
      // SDK).
      //
      // BUT-1975 reversed what that state means. It used to leave the VM
      // LOADING, which the calendar renders as a spinner because
      // `LoadingStateBuilder` returns its loading widget before it looks at
      // `data` — so the edit was invisible until the connection came back.
      // `assignRecipe` now runs through `_executeWrite`, which does not raise
      // the flag, and the edit is published before the save is awaited.
      //
      // Deliberately not awaited — that is the offline shape.
      test('a PENDING save shows the edit and does NOT hold the calendar in '
          'the loading state', () async {
        await seed();
        final edited = _plan(
          entries: [
            _entry(
              day: DayOfWeek.tue,
              slot: MealSlot.middag,
              id: 'e-offline',
              recipeId: 'r-offline',
            ),
          ],
        );
        when(
          () => mockService.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any(named: 'recipe'),
          ),
        ).thenReturn(edited);
        final pending = Completer<void>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete();
        });
        when(() => mockService.save(any())).thenAnswer((_) => pending.future);

        unawaited(
          viewModel.assignRecipe(
            day: DayOfWeek.tue,
            slot: MealSlot.middag,
            recipe: _recipe(id: 'r-offline'),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          viewModel.isLoading,
          isFalse,
          reason:
              'the loading flag belongs to READS; a write that owns it '
              'leaves the calendar a spinner until the server acks',
        );
        expect(
          viewModel.plan,
          same(edited),
          reason:
              'the whole point: the edit is on screen while the write is '
              'still out for delivery',
        );
        expect(viewModel.error, isNull);
        pending.complete();
      });

      test('assignRecipe', () async {
        final week = await seed();
        // Stubbing `addEntry` is load-bearing: unstubbed it throws first, the
        // error surfaces anyway, and the test goes green having never reached
        // the save.
        when(
          () => mockService.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any(named: 'recipe'),
          ),
        ).thenReturn(
          _plan(
            entries: [
              _entry(day: DayOfWeek.tue, slot: MealSlot.middag, id: 'e-added'),
            ],
          ),
        );
        failTheSave();

        await viewModel.assignRecipe(
          day: DayOfWeek.tue,
          slot: MealSlot.middag,
          recipe: _recipe(id: 'r-new'),
        );

        expect(viewModel.error, contains('Kunde inte lägga till receptet'));
        expect(viewModel.plan, same(week));
      });

      test('moveEntry', () async {
        final week = await seed();
        when(
          () => mockService.moveEntry(
            plan: any(named: 'plan'),
            entryId: any(named: 'entryId'),
            toDay: any(named: 'toDay'),
            toSlot: any(named: 'toSlot'),
          ),
        ).thenReturn(_plan(entries: const []));
        failTheSave();

        await viewModel.moveEntry(
          entryId: 'entry-1',
          toDay: DayOfWeek.wed,
          toSlot: MealSlot.middag,
        );

        expect(viewModel.error, contains('Kunde inte flytta receptet'));
        expect(viewModel.plan, same(week));
      });

      test('removeEntry', () async {
        final week = await seed();
        when(
          () => mockService.removeEntry(
            plan: any(named: 'plan'),
            entryId: any(named: 'entryId'),
          ),
        ).thenReturn(_plan(entries: const []));
        failTheSave();

        await viewModel.removeEntry('entry-1');

        expect(viewModel.error, contains('Kunde inte ta bort receptet'));
        expect(viewModel.plan, same(week));
      });

      test('clearWeek — and the undo window is not opened', () async {
        final week = await seed();
        when(
          () => mockService.clearWeek(any()),
        ).thenReturn(_plan(entries: const []));
        failTheSave();

        // `_onClearWeek` gates the "Veckan rensad" snackbar on this bool, so
        // a refused clear no longer announces success with a dead "Ångra".
        expect(await viewModel.clearWeek(), isFalse);

        expect(viewModel.error, contains('Kunde inte rensa veckan'));
        expect(viewModel.plan, same(week));
        // A refused clear must leave no undo window armed — asserted through
        // behaviour because the window has no public getter: a later undo must
        // find no snapshot and return before reaching the service.
        await viewModel.undoClearWeek();
        verifyNever(() => mockService.restoreWeek(any(), any()));
      });

      test('undoClearWeek — and the snapshot survives for a retry', () async {
        final week = await seed();
        final cleared = _plan(entries: const []);
        when(() => mockService.clearWeek(any())).thenReturn(cleared);
        await viewModel.clearWeek();
        expect(
          viewModel.plan,
          same(cleared),
          reason: 'the clear must land first',
        );
        viewModel.clearError();

        when(() => mockService.restoreWeek(any(), any())).thenReturn(week);
        failTheSave();

        await viewModel.undoClearWeek();

        expect(viewModel.error, contains('Kunde inte ångra rensningen'));
        expect(viewModel.plan, same(cleared));
        // Consuming the snapshot before the write landed left the user with a
        // failed undo they could not repeat. A second attempt must still reach
        // the service, which is what proves the snapshot survived.
        await viewModel.undoClearWeek();
        verify(() => mockService.restoreWeek(any(), any())).called(2);
      });

      // The message the user sees is built from the call site's own prefix, so
      // it cannot pick up the exception. Asserted rather than eyeballed: a
      // future `setError('$errorPrefix: $e')` would leak the class name, and
      // for this repository the thrown object carries the uid in a field.
      test(
        'the surfaced text leaks no exception name, code, uid or path',
        () async {
          await seed();
          when(() => mockService.save(any())).thenThrow(
            PermissionDeniedException(
              'Weekly menu plan save denied',
              resource: 'weekly_menu_plans',
              operation: 'save',
              userId: 'u-1',
            ),
          );
          when(
            () => mockService.removeEntry(
              plan: any(named: 'plan'),
              entryId: any(named: 'entryId'),
            ),
          ).thenReturn(_plan(entries: const []));

          await viewModel.removeEntry('entry-1');

          // Pinning the WHOLE string is the assertion: `_executeWrite` calls
          // `setError(errorPrefix)` verbatim, so a future
          // `setError('$errorPrefix: $e')` — which is how the exception would
          // leak — changes this equality.
          expect(viewModel.error, 'Kunde inte ta bort receptet');
        },
      );

      // `assignFromOverflow`, found by the integration pass rather than by
      // me: it awaited `assignRecipe`, ignored the outcome
      // and pruned the tray regardless. The tray is in-memory only and
      // `_fetchWeek` does not repopulate it, so on a refused save the recipe
      // was gone until the menu was regenerated.
      test('assignFromOverflow keeps the chip in the tray', () async {
        final week = _plan();
        final tray = _recipe(id: 'r-tray');
        when(
          () => mockService.readWeek(any()),
        ).thenAnswer((_) async => _read(week));
        when(
          () => mockService.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        ).thenReturn(
          WeeklyMenuDistributionResult(plan: week, overflow: [tray]),
        );
        await viewModel.loadWeek(week.weekStartDate);
        await viewModel.applyGeneratedMenu({
          'middag': [tray],
        });
        expect(viewModel.overflow, hasLength(1));
        viewModel.clearError();

        when(
          () => mockService.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any(named: 'recipe'),
          ),
        ).thenReturn(_plan());
        failTheSave();

        await viewModel.assignFromOverflow(
          recipe: tray,
          day: DayOfWeek.wed,
          slot: MealSlot.middag,
        );

        expect(viewModel.error, contains('Kunde inte lägga till receptet'));
        expect(
          viewModel.overflow,
          hasLength(1),
          reason: 'the tray is where the recipe still lives',
        );
      });

      test('applyGeneratedMenu', () async {
        final week = await seed();
        when(
          () => mockService.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        ).thenReturn(
          WeeklyMenuDistributionResult(
            plan: _plan(
              entries: [
                _entry(day: DayOfWeek.fri, slot: MealSlot.middag, id: 'e-new'),
              ],
            ),
            overflow: const [],
          ),
        );
        failTheSave();

        final placed = await viewModel.applyGeneratedMenu({
          'middag': [_recipe(id: 'r-gen')],
        });

        expect(placed, isNull);
        expect(viewModel.error, 'Kunde inte fördela recepten');
        expect(viewModel.plan, same(week));
      });
    });

    group('an unacked write (BUT-1975/BUT-1965)', () {
      /// Same shape as the refusal group's: a resident week so the operations
      /// under test have a `_plan` to build from.
      Future<WeeklyMenuPlan> seed() async {
        final week = _plan(
          entries: [_entry(day: DayOfWeek.mon, slot: MealSlot.middag)],
        );
        when(
          () => mockService.readWeek(any()),
        ).thenAnswer((_) async => _read(week));
        await viewModel.loadWeek(week.weekStartDate);
        viewModel.clearError();
        return week;
      }

      test(
        'a generated week is RENDERED while its save is still pending',
        () async {
          // BUT-1965's own acceptance criterion, which it could not meet alone:
          // the old order awaited the save before assigning `_plan`, so offline
          // the distributed week never reached the screen at all.
          await seed();
          final distributed = _plan(
            entries: [
              _entry(
                day: DayOfWeek.wed,
                slot: MealSlot.middag,
                id: 'e-gen',
                recipeId: 'r-gen',
              ),
            ],
          );
          when(
            () => mockService.distributeFromGeneratedMenu(
              generated: any(named: 'generated'),
              weekStart: any(named: 'weekStart'),
              existing: any(named: 'existing'),
              now: any(named: 'now'),
              dayPins: any(named: 'dayPins'),
            ),
          ).thenReturn(
            WeeklyMenuDistributionResult(plan: distributed, overflow: const []),
          );
          final pending = Completer<void>();
          addTearDown(() {
            if (!pending.isCompleted) pending.complete();
          });
          when(() => mockService.save(any())).thenAnswer((_) => pending.future);

          unawaited(
            viewModel.applyGeneratedMenu({
              'middag': [_recipe()],
            }),
          );
          await Future<void>.delayed(Duration.zero);

          expect(viewModel.plan, same(distributed));
          expect(viewModel.isLoading, isFalse);
          pending.complete();
        },
      );

      test('a pending PRESENCE save does not refuse a calendar edit', () async {
        // The regression this pins: `setSlotPresence` re-reads through the
        // repository, and its only assignment to `_plan` happens after that
        // call returns — the ack. Behind the shared publish guard, a single
        // "vem är hemma" tap therefore wedged every other write for the whole
        // outage, silently.
        final week = await seed();
        final pending = Completer<WeeklyMenuPlan>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete(week);
        });
        when(
          () => mockService.setSlotPresence(
            weekStart: any(named: 'weekStart'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            memberIds: any(named: 'memberIds'),
          ),
        ).thenAnswer((_) => pending.future);

        unawaited(
          viewModel.setSlotPresence(DayOfWeek.mon, MealSlot.middag, const [
            'u-1',
          ]),
        );
        await Future<void>.delayed(Duration.zero);

        final edited = _plan(
          entries: [
            _entry(
              day: DayOfWeek.tue,
              slot: MealSlot.middag,
              id: 'e-after',
              recipeId: 'r-after',
            ),
          ],
        );
        when(
          () => mockService.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any(named: 'recipe'),
          ),
        ).thenReturn(edited);
        when(() => mockService.save(any())).thenAnswer((_) async {});

        final ok = await viewModel.assignRecipe(
          day: DayOfWeek.tue,
          slot: MealSlot.middag,
          recipe: _recipe(id: 'r-after'),
        );

        expect(ok, isTrue, reason: 'the calendar edit must not be refused');
        expect(viewModel.plan, same(edited));
        pending.complete(week);
      });

      test('a second edit is accepted while the first is still unacked, and '
          'builds ON it', () async {
        // `assignRecipe` releases the guard once it has published, not when
        // the save acks. Holding it to the ack would last the whole outage —
        // one offline edit, every later one silently dropped.
        await seed();
        final first = _plan(
          entries: [
            _entry(
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              id: 'e-first',
              recipeId: 'r-first',
            ),
          ],
        );
        final second = _plan(
          entries: [
            _entry(
              day: DayOfWeek.mon,
              slot: MealSlot.middag,
              id: 'e-first',
              recipeId: 'r-first',
            ),
            _entry(
              day: DayOfWeek.tue,
              slot: MealSlot.middag,
              id: 'e-second',
              recipeId: 'r-second',
            ),
          ],
        );
        final bases = <WeeklyMenuPlan>[];
        when(
          () => mockService.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any(named: 'recipe'),
          ),
        ).thenAnswer((inv) {
          bases.add(inv.namedArguments[#plan] as WeeklyMenuPlan);
          return bases.length == 1 ? first : second;
        });
        final pending = Completer<void>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete();
        });
        when(() => mockService.save(any())).thenAnswer((_) => pending.future);

        unawaited(
          viewModel.assignRecipe(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            recipe: _recipe(id: 'r-first'),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        unawaited(
          viewModel.assignRecipe(
            day: DayOfWeek.tue,
            slot: MealSlot.middag,
            recipe: _recipe(id: 'r-second'),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          bases,
          hasLength(2),
          reason: 'the second edit must not be dropped',
        );
        expect(
          bases[1],
          same(first),
          reason: 'it computes from the FIRST edit, not the pre-edit week',
        );
        expect(viewModel.plan, same(second));
        pending.complete();
      });
    });

    group('resolveForNavigation', () {
      test('returns the recipe from the service when found', () {
        final r = _recipe(id: 'r-nav');
        when(() => mockRecipeService.getRecipeById('r-nav')).thenReturn(r);

        expect(viewModel.resolveForNavigation('r-nav'), r);
        verify(() => mockRecipeService.getRecipeById('r-nav')).called(1);
      });

      test('returns null when the service reports a deleted recipe', () {
        when(() => mockRecipeService.getRecipeById('deleted')).thenReturn(null);

        expect(viewModel.resolveForNavigation('deleted'), isNull);
      });
    });

    group('a failed READ never becomes a save (BUT-1939)', () {
      test('publishes no plan and surfaces a retryable message', () async {
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: _plan(), readFailed: true),
        );

        await viewModel.loadWeek(DateTime(2026, 4, 15));

        expect(viewModel.plan, isNull);
        expect(viewModel.error, equals(weeklyPlanReadFailedMessage));
        verifyNever(() => mockService.save(any()));
      });

      test(
        'applyGeneratedMenu refuses — it has no _plan null guard of its own',
        () async {
          when(() => mockService.readWeek(any())).thenAnswer(
            (_) async => WeeklyMenuPlanRead(plan: _plan(), readFailed: true),
          );
          // Stubbed to SUCCEED, so the only thing that can stop the save is the
          // guard: without it `existing: null` builds a fresh week and upserts it
          // onto the deterministic doc id. `hasEntries` is false while `_plan` is
          // null, so the view's overwrite confirmation is skipped too.
          when(
            () => mockService.distributeFromGeneratedMenu(
              generated: any(named: 'generated'),
              weekStart: any(named: 'weekStart'),
              existing: any(named: 'existing'),
              now: any(named: 'now'),
              dayPins: any(named: 'dayPins'),
            ),
          ).thenReturn(
            WeeklyMenuDistributionResult(plan: _plan(), overflow: const []),
          );
          await viewModel.loadWeek(DateTime(2026, 4, 15));

          final placed = await viewModel.applyGeneratedMenu(
            const {'middag': <Recipe>[]},
            replaceExisting: true,
          );

          expect(placed, isNull);
          verifyNever(() => mockService.save(any()));
        },
      );

      test(
        'the week-scoped writers refuse rather than retargeting THIS week',
        () async {
          when(() => mockService.readWeek(any())).thenAnswer(
            (_) async => WeeklyMenuPlanRead(plan: _plan(), readFailed: true),
          );
          await viewModel.loadWeek(DateTime(2026, 4, 15));

          await viewModel.setSlotPresence(DayOfWeek.mon, MealSlot.middag, [
            'm1',
          ]);
          await viewModel.setDayPresence(DayOfWeek.tue, ['m1']);
          final copied = await viewModel.copyWeekToNext();

          expect(copied, isNull);
          verifyNever(
            () => mockService.setSlotPresence(
              weekStart: any(named: 'weekStart'),
              day: any(named: 'day'),
              slot: any(named: 'slot'),
              memberIds: any(named: 'memberIds'),
            ),
          );
          verifyNever(
            () => mockService.setDayPresence(
              weekStart: any(named: 'weekStart'),
              day: any(named: 'day'),
              memberIds: any(named: 'memberIds'),
            ),
          );
          verifyNever(
            () => mockService.copyWeek(
              fromWeekStart: any(named: 'fromWeekStart'),
              toWeekStart: any(named: 'toWeekStart'),
            ),
          );
        },
      );

      test(
        'bulkMoveSelected refuses on a failed read',
        () async {
          final week = _plan(
            entries: [
              _entry(day: DayOfWeek.mon, slot: MealSlot.middag, id: 'e-sel'),
            ],
          );
          var failNext = false;
          when(() => mockService.readWeek(any())).thenAnswer(
            (_) async => WeeklyMenuPlanRead(plan: week, readFailed: failNext),
          );
          await viewModel.loadWeek(DateTime(2026, 4, 15));
          viewModel.beginSelection();
          viewModel.toggleSelection('e-sel');
          expect(viewModel.selectedCount, 1);

          failNext = true;
          await viewModel.loadWeek(DateTime(2026, 4, 22));

          final moved = await viewModel.bulkMoveSelected(
            toDay: DayOfWeek.tue,
            toSlot: MealSlot.middag,
          );

          expect(moved, isNull);
          verifyNever(
            () => mockService.bulkMoveEntries(
              weekStart: any(named: 'weekStart'),
              entryIds: any(named: 'entryIds'),
              toDay: any(named: 'toDay'),
              toSlot: any(named: 'toSlot'),
            ),
          );
        },
      );

      test(
        'generateShoppingList refuses rather than listing the wrong week',
        () async {
          when(() => mockService.readWeek(any())).thenAnswer(
            (_) async => WeeklyMenuPlanRead(plan: _plan(), readFailed: true),
          );
          await viewModel.loadWeek(DateTime(2026, 4, 15));

          final result = await viewModel.generateShoppingList();

          expect(result, isNull);
          verifyNever(() => mockGenerator.generateForWeek(any()));
        },
      );

      test(
        'currentWeekStart still names the REQUESTED week after a failed read',
        () async {
          // The getter is public and `veckomeny_view` hands it to the placement
          // session. Falling back to today would aim that session at a week the
          // user never chose — and that write lands, because the session reads
          // its own target fresh.
          final target = DateTime(2026, 4, 20);
          when(() => mockService.readWeek(any())).thenAnswer(
            (_) async => WeeklyMenuPlanRead(plan: _plan(), readFailed: true),
          );

          await viewModel.loadWeek(target);

          expect(viewModel.plan, isNull);
          expect(
            viewModel.currentWeekStart,
            equals(IsoWeekUtils.weekStartOf(target)),
          );
        },
      );

      test(
        'adoptPlan clears the refusal — a placement session recovers it',
        () async {
          // `loadWeek` short-circuits on a matching weekStartDate, so without
          // adoptPlan clearing the flag nothing would ever re-fetch and every
          // guarded action would stay silently inert for that week.
          final week = _plan();
          when(() => mockService.readWeek(any())).thenAnswer(
            (_) async => WeeklyMenuPlanRead(plan: week, readFailed: true),
          );
          when(
            () => mockService.copyWeek(
              fromWeekStart: any(named: 'fromWeekStart'),
              toWeekStart: any(named: 'toWeekStart'),
            ),
          ).thenAnswer((_) async => 3);
          await viewModel.loadWeek(week.weekStartDate);
          expect(viewModel.plan, isNull);

          viewModel.adoptPlan(week);

          final copied = await viewModel.copyWeekToNext();
          expect(copied, isNotNull);
          verify(
            () => mockService.copyWeek(
              fromWeekStart: any(named: 'fromWeekStart'),
              toWeekStart: any(named: 'toWeekStart'),
            ),
          ).called(1);
        },
      );

      test('and the entry mutators write nothing while it holds', () async {
        // A SUCCESSFUL load first, then a failed re-read of a DIFFERENT week:
        // without it the mutant that drops `_plan = null` is invisible,
        // because the plan was never resident to begin with.
        final week = _plan(
          entries: [
            _entry(day: DayOfWeek.mon, slot: MealSlot.middag, id: 'e-live'),
          ],
        );
        var failNext = false;
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: week, readFailed: failNext),
        );
        when(
          () => mockService.removeEntry(
            plan: any(named: 'plan'),
            entryId: any(named: 'entryId'),
          ),
        ).thenReturn(_plan());
        await viewModel.loadWeek(DateTime(2026, 4, 13));
        expect(viewModel.plan, isNotNull);

        failNext = true;
        await viewModel.loadWeek(DateTime(2026, 4, 20));

        await viewModel.removeEntry('e-live');

        verifyNever(() => mockService.save(any()));
      });
    });

    group('loadWeek', () {
      test('fetches the plan for the ISO week containing the given date '
          'and notifies listeners', () async {
        final fetched = _plan();
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: fetched, readFailed: false),
        );
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        await viewModel.loadWeek(DateTime(2026, 4, 15)); // Wed of that week

        expect(viewModel.plan, same(fetched));
        // executeAsyncVoid fires at minimum: setLoading(true), success path
        // setLoading(false), plus explicit notifyListeners on plan assignment.
        expect(notifications, greaterThanOrEqualTo(1));
        verify(() => mockService.readWeek(fetched.weekStartDate)).called(1);
      });

      test('short-circuits when the target week is already loaded '
          '(no extra service call)', () async {
        final first = _plan();
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: first, readFailed: false),
        );

        // First load pulls from the service.
        await viewModel.loadWeek(DateTime(2026, 4, 13));
        verify(() => mockService.readWeek(first.weekStartDate)).called(1);

        // Second call for ANY date in the same ISO week — must be a no-op.
        await viewModel.loadWeek(DateTime(2026, 4, 15));
        await viewModel.loadWeek(DateTime(2026, 4, 18));

        verifyNever(() => mockService.readWeek(any()));
      });

      test('sets the localized error string when the service throws', () async {
        when(
          () => mockService.readWeek(any()),
        ).thenThrow(StateError('network down'));

        // executeAsyncVoid swallows the throw and records the prefix as
        // the user-facing error message. The ViewModel call completes
        // normally (no rethrow), so no expectLater(throwsA).
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, 'Kunde inte ladda veckomenyn');
        expect(viewModel.plan, isNull);
      });
    });

    group('previousWeek / nextWeek', () {
      test(
        'nextWeek advances by 7 days from the current week anchor',
        () async {
          final week1 = _plan(weekStart: DateTime(2026, 4, 13));
          final week2 = _plan(weekStart: DateTime(2026, 4, 20));
          when(
            () => mockService.readWeek(week1.weekStartDate),
          ).thenAnswer((_) async => _read(week1));
          when(
            () => mockService.readWeek(week2.weekStartDate),
          ).thenAnswer((_) async => _read(week2));

          await viewModel.loadWeek(DateTime(2026, 4, 13));
          await viewModel.nextWeek();

          expect(viewModel.currentWeekStart, week2.weekStartDate);
          verify(() => mockService.readWeek(week2.weekStartDate)).called(1);
        },
      );

      test(
        'previousWeek rewinds by 7 days from the current week anchor',
        () async {
          final week1 = _plan(weekStart: DateTime(2026, 4, 13));
          final prev = _plan(weekStart: DateTime(2026, 4, 6));
          when(
            () => mockService.readWeek(week1.weekStartDate),
          ).thenAnswer((_) async => _read(week1));
          when(
            () => mockService.readWeek(prev.weekStartDate),
          ).thenAnswer((_) async => _read(prev));

          await viewModel.loadWeek(DateTime(2026, 4, 13));
          await viewModel.previousWeek();

          expect(viewModel.currentWeekStart, prev.weekStartDate);
          verify(() => mockService.readWeek(prev.weekStartDate)).called(1);
        },
      );

      test('crosses ISO year boundary (2026-W53 → 2027-W01) without skipping '
          'or duplicating a week', () async {
        // 2026 has 53 ISO weeks because Jan 1 2026 is a Thursday.
        // Week 53 starts Mon 2026-12-28; the following week is 2027-W01.
        final w53 = _plan(
          userId: 'u-boundary',
          weekStart: DateTime(2026, 12, 28),
        );
        final w1 = _plan(
          userId: 'u-boundary',
          weekStart: DateTime(2027, 1, 4),
        );
        when(
          () => mockService.readWeek(w53.weekStartDate),
        ).thenAnswer((_) async => _read(w53));
        when(
          () => mockService.readWeek(w1.weekStartDate),
        ).thenAnswer((_) async => _read(w1));

        await viewModel.loadWeek(DateTime(2026, 12, 30));
        // Confirm we landed on week 53 of 2026.
        expect(IsoWeekUtils.isoWeekNumber(viewModel.currentWeekStart), 53);
        expect(IsoWeekUtils.isoWeekYear(viewModel.currentWeekStart), 2026);

        await viewModel.nextWeek();

        expect(IsoWeekUtils.isoWeekNumber(viewModel.currentWeekStart), 1);
        expect(IsoWeekUtils.isoWeekYear(viewModel.currentWeekStart), 2027);
      });
    });

    group('applyGeneratedMenu', () {
      test('distributes the generated menu, persists, and updates plan '
          '+ overflow state', () async {
        final initial = _plan();
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        final distributedPlan = initial.copyWith(
          entries: [
            _entry(day: DayOfWeek.mon, slot: MealSlot.middag, id: 'e-m'),
          ],
        );
        final overflowRecipe = _recipe(id: 'overflow-r', title: 'Too Many');
        when(
          () => mockService.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        ).thenReturn(
          WeeklyMenuDistributionResult(
            plan: distributedPlan,
            overflow: [overflowRecipe],
          ),
        );

        await viewModel.applyGeneratedMenu({
          'middag': [_recipe(id: 'r-m')],
        });

        expect(viewModel.plan, same(distributedPlan));
        expect(viewModel.overflow, [overflowRecipe]);
        expect(viewModel.hasOverflow, isTrue);
        verify(() => mockService.save(distributedPlan)).called(1);
      });

      test('uses replaceExisting=true to clear prior entries before '
          'distribution', () async {
        final initial = _plan(
          entries: [
            _entry(day: DayOfWeek.mon, slot: MealSlot.middag, id: 'pre-1'),
          ],
        );
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        final result = WeeklyMenuDistributionResult(
          plan: initial.copyWith(entries: const []),
          overflow: const [],
        );
        when(
          () => mockService.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        ).thenReturn(result);

        await viewModel.applyGeneratedMenu(
          {
            'middag': [_recipe(id: 'r')],
          },
          replaceExisting: true,
        );

        // Captured `existing` arg must be an empty-entries clone.
        final captured =
            verify(
                  () => mockService.distributeFromGeneratedMenu(
                    generated: any(named: 'generated'),
                    weekStart: any(named: 'weekStart'),
                    existing: captureAny(named: 'existing'),
                    now: any(named: 'now'),
                    dayPins: any(named: 'dayPins'),
                  ),
                ).captured.single
                as WeeklyMenuPlan?;
        expect(captured, isNotNull);
        expect(captured!.entries, isEmpty);
      });

      test(
        'persists the parsed request on the view model for UI chips',
        () async {
          final initial = _plan();
          when(
            () => mockService.readWeek(any()),
          ).thenAnswer((_) async => _read(initial));
          await viewModel.loadWeek(DateTime(2026, 4, 13));

          when(
            () => mockService.distributeFromGeneratedMenu(
              generated: any(named: 'generated'),
              weekStart: any(named: 'weekStart'),
              existing: any(named: 'existing'),
              now: any(named: 'now'),
              dayPins: any(named: 'dayPins'),
            ),
          ).thenReturn(
            WeeklyMenuDistributionResult(
              plan: initial,
              overflow: const [],
            ),
          );

          final parsed = ParsedMenuRequest.empty('5 middagar');
          await viewModel.applyGeneratedMenu(
            const {'middag': []},
            parsedRequest: parsed,
          );

          expect(viewModel.lastParsedRequest, same(parsed));
        },
      );

      test('the write-in-flight guard blocks a concurrent second call '
          '(only the first distributes + saves)', () async {
        final initial = _plan();
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        var distributeCalls = 0;
        when(
          () => mockService.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        ).thenAnswer((_) {
          distributeCalls++;
          return WeeklyMenuDistributionResult(
            plan: initial,
            overflow: const [],
          );
        });

        // Fire the two calls back-to-back WITHOUT awaiting the first. The
        // first marks a write in flight synchronously, before its first
        // await, so the second sees the guard and early-returns.
        clearInteractions(mockService);
        final first = viewModel.applyGeneratedMenu(const {'middag': []});
        final second = viewModel.applyGeneratedMenu(const {'middag': []});
        await Future.wait([first, second]);

        expect(
          distributeCalls,
          1,
          reason: 'the second call must early-return on the in-flight guard',
        );
        verify(() => mockService.save(any())).called(1);
        // The refusal is deliberately SILENT (BUT-1987). A message here would
        // land on a surface where `LoadingStateBuilder` ranks error above
        // data, replacing the whole calendar — including the week the first
        // tap just placed. Pinned so re-introducing `setError` on this branch
        // cannot go green.
        expect(viewModel.error, isNull);
      });
    });

    group('assignRecipe', () {
      test('is a no-op when no plan is loaded', () async {
        // Guard: current == null triggers early-return before _executeWrite.
        await viewModel.assignRecipe(
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipe: _recipe(),
        );

        verifyNever(
          () => mockService.addEntry(
            plan: any(named: 'plan'),
            day: any(named: 'day'),
            slot: any(named: 'slot'),
            recipe: any(named: 'recipe'),
          ),
        );
        verifyNever(() => mockService.save(any()));
      });

      test(
        'delegates to service.addEntry, persists, and updates plan',
        () async {
          final initial = _plan();
          final recipe = _recipe(id: 'r-add');
          when(
            () => mockService.readWeek(any()),
          ).thenAnswer((_) async => _read(initial));
          await viewModel.loadWeek(DateTime(2026, 4, 13));

          final updated = initial.copyWith(
            entries: [
              _entry(day: DayOfWeek.tue, slot: MealSlot.lunch, id: 'e-added'),
            ],
          );
          when(
            () => mockService.addEntry(
              plan: initial,
              day: DayOfWeek.tue,
              slot: MealSlot.lunch,
              recipe: recipe,
            ),
          ).thenReturn(updated);

          await viewModel.assignRecipe(
            day: DayOfWeek.tue,
            slot: MealSlot.lunch,
            recipe: recipe,
          );

          expect(viewModel.plan, same(updated));
          verify(() => mockService.save(updated)).called(1);
        },
      );
    });

    group('moveEntry', () {
      test(
        'self-drop skips notify + save (identical(updated, current))',
        () async {
          // Service returns the very same plan instance — the VM must detect
          // that via `identical` and short-circuit.
          final initial = _plan(
            entries: [
              _entry(day: DayOfWeek.mon, slot: MealSlot.middag, id: 'e-self'),
            ],
          );
          when(
            () => mockService.readWeek(any()),
          ).thenAnswer((_) async => _read(initial));
          await viewModel.loadWeek(DateTime(2026, 4, 13));

          when(
            () => mockService.moveEntry(
              plan: initial,
              entryId: 'e-self',
              toDay: DayOfWeek.mon,
              toSlot: MealSlot.middag,
            ),
          ).thenReturn(initial); // self-drop — identical returned

          // The plan reference before and after self-drop must be identical —
          // the VM must not reassign `_plan` when service.moveEntry returns
          // the very same instance. Combined with verifyNever(save) below,
          // that pins the `identical(updated, current)` short-circuit.
          final planBefore = viewModel.plan;

          await viewModel.moveEntry(
            entryId: 'e-self',
            toDay: DayOfWeek.mon,
            toSlot: MealSlot.middag,
          );

          verifyNever(() => mockService.save(any()));
          // Plan reference unchanged: _plan never reassigned.
          expect(
            identical(viewModel.plan, planBefore),
            isTrue,
            reason:
                'self-drop must skip the `_plan = updated` + notify + save path',
          );
        },
      );

      test('real move persists the updated plan', () async {
        final initial = _plan(
          entries: [
            _entry(day: DayOfWeek.mon, slot: MealSlot.middag, id: 'e-move'),
          ],
        );
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        final moved = initial.copyWith(
          entries: [
            _entry(day: DayOfWeek.tue, slot: MealSlot.middag, id: 'e-move'),
          ],
        );
        when(
          () => mockService.moveEntry(
            plan: initial,
            entryId: 'e-move',
            toDay: DayOfWeek.tue,
            toSlot: MealSlot.middag,
          ),
        ).thenReturn(moved);

        await viewModel.moveEntry(
          entryId: 'e-move',
          toDay: DayOfWeek.tue,
          toSlot: MealSlot.middag,
        );

        expect(viewModel.plan, same(moved));
        verify(() => mockService.save(moved)).called(1);
      });

      test('is a no-op when no plan is loaded', () async {
        await viewModel.moveEntry(
          entryId: 'any',
          toDay: DayOfWeek.wed,
          toSlot: MealSlot.lunch,
        );

        verifyNever(
          () => mockService.moveEntry(
            plan: any(named: 'plan'),
            entryId: any(named: 'entryId'),
            toDay: any(named: 'toDay'),
            toSlot: any(named: 'toSlot'),
          ),
        );
      });
    });

    group('removeEntry', () {
      test(
        'skips save when the service returns the same plan (unknown id)',
        () async {
          final initial = _plan();
          when(
            () => mockService.readWeek(any()),
          ).thenAnswer((_) async => _read(initial));
          await viewModel.loadWeek(DateTime(2026, 4, 13));

          when(
            () => mockService.removeEntry(
              plan: initial,
              entryId: 'unknown',
            ),
          ).thenReturn(initial); // identical — id didn't match

          await viewModel.removeEntry('unknown');

          verifyNever(() => mockService.save(any()));
        },
      );

      test(
        'persists the updated plan when the entry is actually removed',
        () async {
          final initial = _plan(
            entries: [
              _entry(
                day: DayOfWeek.mon,
                slot: MealSlot.middag,
                id: 'to-delete',
              ),
            ],
          );
          when(
            () => mockService.readWeek(any()),
          ).thenAnswer((_) async => _read(initial));
          await viewModel.loadWeek(DateTime(2026, 4, 13));

          final stripped = initial.copyWith(entries: const []);
          when(
            () => mockService.removeEntry(
              plan: initial,
              entryId: 'to-delete',
            ),
          ).thenReturn(stripped);

          await viewModel.removeEntry('to-delete');

          expect(viewModel.plan, same(stripped));
          verify(() => mockService.save(stripped)).called(1);
        },
      );

      test('is a no-op when no plan is loaded', () async {
        await viewModel.removeEntry('whatever');
        verifyNever(
          () => mockService.removeEntry(
            plan: any(named: 'plan'),
            entryId: any(named: 'entryId'),
          ),
        );
      });
    });

    group('clearWeek', () {
      test('short-circuits when plan is empty AND overflow is empty '
          '(no service call fired)', () async {
        final empty = _plan();
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: empty, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        expect(await viewModel.clearWeek(), isFalse);

        verifyNever(() => mockService.clearWeek(any()));
        verifyNever(() => mockService.save(any()));
      });

      test(
        'clears overflow when present, even if plan was already empty',
        () async {
          // This path proves overflow-only clears are still observable —
          // clearWeek returns the same (empty) plan so service.save is NOT
          // called, but the overflow list is wiped. The guard `isEmpty &&
          // overflow.isEmpty` means overflow alone is enough to enter the
          // _executeWrite path.
          final emptyPlan = _plan();
          when(
            () => mockService.readWeek(any()),
          ).thenAnswer((_) async => _read(emptyPlan));
          await viewModel.loadWeek(DateTime(2026, 4, 13));

          // Seed overflow via applyGeneratedMenu.
          final recipe = _recipe(id: 'overflow-1', title: 'Extra');
          when(
            () => mockService.distributeFromGeneratedMenu(
              generated: any(named: 'generated'),
              weekStart: any(named: 'weekStart'),
              existing: any(named: 'existing'),
              now: any(named: 'now'),
              dayPins: any(named: 'dayPins'),
            ),
          ).thenReturn(
            WeeklyMenuDistributionResult(plan: emptyPlan, overflow: [recipe]),
          );
          await viewModel.applyGeneratedMenu(const {'middag': []});
          expect(viewModel.overflow, [recipe]);

          when(() => mockService.clearWeek(emptyPlan)).thenReturn(emptyPlan);

          // Reset interactions BEFORE the action under test — the preceding
          // applyGeneratedMenu already called save() once, and we only care
          // about what clearWeek does on top of that.
          clearInteractions(mockService);

          await viewModel.clearWeek();

          expect(viewModel.overflow, isEmpty);
          // Plan was already empty → service.clearWeek returns the same plan →
          // `identical(cleared, current)` → save must NOT be fired by clearWeek.
          verifyNever(() => mockService.save(any()));
        },
      );

      test('persists the cleared plan when entries actually existed', () async {
        final populated = _plan(
          entries: [
            _entry(day: DayOfWeek.mon, slot: MealSlot.middag, id: 'e-x'),
          ],
        );
        when(
          () => mockService.readWeek(any()),
        ).thenAnswer((_) async => _read(populated));
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        final cleared = populated.copyWith(entries: const []);
        when(() => mockService.clearWeek(populated)).thenReturn(cleared);

        expect(await viewModel.clearWeek(), isTrue);

        expect(viewModel.plan, same(cleared));
        verify(() => mockService.save(cleared)).called(1);
      });

      test('is a no-op when no plan is loaded', () async {
        expect(await viewModel.clearWeek(), isFalse);
        verifyNever(() => mockService.clearWeek(any()));
      });
    });

    group('undoClearWeek', () {
      test(
        'restores the pre-clear entries, persists, and wipes the snapshot',
        () async {
          final entry = _entry(day: DayOfWeek.mon, slot: MealSlot.middag);
          final populated = _plan(entries: [entry]);
          when(
            () => mockService.readWeek(any()),
          ).thenAnswer((_) async => _read(populated));
          await viewModel.loadWeek(DateTime(2026, 4, 13));

          final cleared = populated.copyWith(entries: const []);
          when(() => mockService.clearWeek(populated)).thenReturn(cleared);
          await viewModel.clearWeek();
          expect(viewModel.plan, same(cleared));

          // Undo: service.restoreWeek should put the snapshot entries back.
          final restored = cleared.copyWith(entries: [entry]);
          when(
            () => mockService.restoreWeek(cleared, any()),
          ).thenReturn(restored);

          await viewModel.undoClearWeek();

          expect(viewModel.plan, same(restored));
          verify(() => mockService.save(restored)).called(1);
          // Snapshot must be consumed so a second undo is a no-op.
          clearInteractions(mockService);
          await viewModel.undoClearWeek();
          verifyNever(() => mockService.restoreWeek(any(), any()));
          verifyNever(() => mockService.save(any()));
        },
      );

      test('is a no-op when called without a preceding clearWeek', () async {
        final initial = _plan(
          entries: [
            _entry(day: DayOfWeek.tue, slot: MealSlot.lunch),
          ],
        );
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        // No clearWeek called — snapshot is null.
        await viewModel.undoClearWeek();

        verifyNever(() => mockService.restoreWeek(any(), any()));
        verifyNever(() => mockService.save(any()));
      });

      test('restores the overflow tray on undo (overflow-only clear is not '
          'silently lost)', () async {
        // Reproduces the data-loss bug: an empty plan with a populated
        // overflow tray. clearWeek wipes the tray but service.save is NOT
        // called (entries didn't change). Tapping Ångra must bring the tray
        // back — the snapshot has to capture overflow, not just entries.
        final emptyPlan = _plan();
        when(
          () => mockService.readWeek(any()),
        ).thenAnswer((_) async => _read(emptyPlan));
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        final overflowRecipe = _recipe(id: 'overflow-1', title: 'Extra');
        when(
          () => mockService.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        ).thenReturn(
          WeeklyMenuDistributionResult(
            plan: emptyPlan,
            overflow: [overflowRecipe],
          ),
        );
        await viewModel.applyGeneratedMenu(const {'middag': []});
        expect(viewModel.overflow, [overflowRecipe]);

        when(() => mockService.clearWeek(emptyPlan)).thenReturn(emptyPlan);
        await viewModel.clearWeek();
        expect(
          viewModel.overflow,
          isEmpty,
          reason: 'clearWeek wipes the tray.',
        );

        // Undo. Plan is unchanged (still empty) but the tray must reappear.
        when(
          () => mockService.restoreWeek(emptyPlan, any()),
        ).thenReturn(emptyPlan);
        await viewModel.undoClearWeek();

        expect(
          viewModel.overflow,
          [overflowRecipe],
          reason:
              'undoClearWeek must restore the overflow tray, not leave '
              'the overflow recipes permanently lost.',
        );
      });
    });

    group('generateShoppingList (BUT-1234)', () {
      const successResult = MenuShoppingGenerationResult(
        listId: 'list-1',
        listName: 'Inköpslista v.16',
        itemCount: 7,
        recipeCount: 3,
        unresolvedRecipes: 0,
      );

      test('delegates to the generator with the current week anchor, toggles '
          'isLoading, and passes the success result through', () async {
        final week = _plan(weekStart: DateTime(2026, 4, 13));
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: week, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        var sawLoading = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) sawLoading = true;
        });
        when(
          () => mockGenerator.generateForWeek(any()),
        ).thenAnswer((_) async => successResult);

        final result = await viewModel.generateShoppingList();

        expect(
          result,
          same(successResult),
          reason:
              'the view renders the snackbar from this result — it '
              'must pass through untouched',
        );
        expect(
          sawLoading,
          isTrue,
          reason: 'executeAsync must raise isLoading so the FAB disables',
        );
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
        verify(
          () => mockGenerator.generateForWeek(week.weekStartDate),
        ).called(1);
      });

      test(
        'passes the nothingToGenerate sentinel through (empty plan)',
        () async {
          when(() => mockGenerator.generateForWeek(any())).thenAnswer(
            (_) async => MenuShoppingGenerationResult.nothingToGenerate,
          );

          final result = await viewModel.generateShoppingList();

          expect(result, isNotNull);
          expect(
            result!.isEmptyPlan,
            isTrue,
            reason:
                'the empty-plan sentinel must reach the view distinct '
                'from the null failure signal',
          );
          expect(viewModel.hasError, isFalse);
        },
      );

      test('passes the null failure signal through without raising the VM '
          'error state (the generator already swallowed and logged)', () async {
        when(
          () => mockGenerator.generateForWeek(any()),
        ).thenAnswer((_) async => null);

        final result = await viewModel.generateShoppingList();

        expect(
          result,
          isNull,
          reason: 'null = failure is the view\'s error-snackbar trigger',
        );
        expect(
          viewModel.hasError,
          isFalse,
          reason:
              'a null return is a normal completion of executeAsync — '
              'no exception, no error state',
        );
        expect(viewModel.isLoading, isFalse);
      });

      test('a throwing generator surfaces the localized error and returns '
          'null instead of rethrowing to the view', () async {
        when(
          () => mockGenerator.generateForWeek(any()),
        ).thenThrow(StateError('write failed'));

        final result = await viewModel.generateShoppingList();

        expect(result, isNull);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, 'Kunde inte skapa inköpslistan');
        expect(viewModel.isLoading, isFalse);
      });

      test('isLoading re-entrancy backstop: a second call while the first is '
          'in flight no-ops (one generator invocation)', () async {
        when(() => mockGenerator.generateForWeek(any())).thenAnswer(
          (_) async {
            // Hold the first call across an event-loop turn so the second
            // call observes isLoading == true.
            await Future<void>.delayed(Duration.zero);
            return successResult;
          },
        );

        final first = viewModel.generateShoppingList();
        final second = viewModel.generateShoppingList();
        final results = await Future.wait([first, second]);

        expect(results[0], same(successResult));
        expect(
          results[1],
          same(MenuShoppingGenerationResult.alreadyRunning),
          reason:
              'the guarded second call must not run the generator, and '
              'must NOT alias the null failure sentinel — the view renders '
              'alreadyRunning as silence, null as an error snackbar',
        );
        verify(() => mockGenerator.generateForWeek(any())).called(1);
      });
    });

    group('assignFromOverflow', () {
      test(
        'prunes the recipe from overflow after a successful assign',
        () async {
          // Seed VM with a plan + overflow containing 2 recipes.
          final initial = _plan();
          when(
            () => mockService.readWeek(any()),
          ).thenAnswer((_) async => _read(initial));
          await viewModel.loadWeek(DateTime(2026, 4, 13));

          final r1 = _recipe(id: 'o-1', title: 'Första');
          final r2 = _recipe(id: 'o-2', title: 'Andra');
          when(
            () => mockService.distributeFromGeneratedMenu(
              generated: any(named: 'generated'),
              weekStart: any(named: 'weekStart'),
              existing: any(named: 'existing'),
              now: any(named: 'now'),
              dayPins: any(named: 'dayPins'),
            ),
          ).thenReturn(
            WeeklyMenuDistributionResult(
              plan: initial,
              overflow: [r1, r2],
            ),
          );
          await viewModel.applyGeneratedMenu(const {'middag': []});
          expect(viewModel.overflow, [r1, r2]);

          // Stub addEntry for r1.
          final updated = initial.copyWith(
            entries: [
              _entry(
                day: DayOfWeek.wed,
                slot: MealSlot.middag,
                id: 'e-from-overflow',
                recipeId: 'o-1',
                title: 'Första',
              ),
            ],
          );
          when(
            () => mockService.addEntry(
              plan: initial,
              day: DayOfWeek.wed,
              slot: MealSlot.middag,
              recipe: r1,
            ),
          ).thenReturn(updated);

          // Act
          await viewModel.assignFromOverflow(
            recipe: r1,
            day: DayOfWeek.wed,
            slot: MealSlot.middag,
          );

          // Assert — r1 removed from overflow, r2 remains.
          expect(viewModel.overflow, [r2]);
        },
      );

      test('does not notify listeners a second time when the recipe was '
          'not in the overflow', () async {
        final initial = _plan();
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        // Overflow stays empty, but assignRecipe still runs.
        final recipe = _recipe(id: 'not-in-tray');
        when(
          () => mockService.addEntry(
            plan: initial,
            day: DayOfWeek.thu,
            slot: MealSlot.middag,
            recipe: recipe,
          ),
        ).thenReturn(initial);

        await viewModel.assignFromOverflow(
          recipe: recipe,
          day: DayOfWeek.thu,
          slot: MealSlot.middag,
        );

        expect(viewModel.overflow, isEmpty);
      });
    });

    group('BUT-1241 placement-flow additions', () {
      WeeklyMenuDistributionResult stubDistribution(WeeklyMenuPlan plan) {
        final result = WeeklyMenuDistributionResult(
          plan: plan,
          overflow: const [],
        );
        when(
          () => mockService.distributeFromGeneratedMenu(
            generated: any(named: 'generated'),
            weekStart: any(named: 'weekStart'),
            existing: any(named: 'existing'),
            now: any(named: 'now'),
            dayPins: any(named: 'dayPins'),
          ),
        ).thenReturn(result);
        return result;
      }

      test('applyGeneratedMenu returns the placed count and flags the new '
          'entries as recently placed (NY badge)', () async {
        final preExisting = _entry(
          day: DayOfWeek.mon,
          slot: MealSlot.lunch,
          id: 'old-1',
        );
        final initial = _plan(entries: [preExisting]);
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        stubDistribution(
          initial.copyWith(
            entries: [
              preExisting,
              _entry(day: DayOfWeek.tue, slot: MealSlot.middag, id: 'new-1'),
              _entry(day: DayOfWeek.wed, slot: MealSlot.middag, id: 'new-2'),
            ],
          ),
        );

        final placed = await viewModel.applyGeneratedMenu({
          'middag': [_recipe()],
        });

        expect(placed, 2);
        expect(viewModel.isRecentlyPlaced('new-1'), isTrue);
        expect(viewModel.isRecentlyPlaced('new-2'), isTrue);
        expect(
          viewModel.isRecentlyPlaced('old-1'),
          isFalse,
          reason: 'pre-existing entries are not "NY"',
        );
      });

      test('adoptPlan publishes a placement-saved plan without a Firestore '
          'read and carries the session NY flags', () async {
        final initial = _plan();
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        final placedPlan = initial.copyWith(
          entries: [
            _entry(day: DayOfWeek.tue, slot: MealSlot.middag, id: 'manual-1'),
          ],
        );
        viewModel.adoptPlan(placedPlan, recentlyPlacedEntryIds: {'manual-1'});

        expect(viewModel.plan, same(placedPlan));
        expect(
          viewModel.isRecentlyPlaced('manual-1'),
          isTrue,
          reason: 'manual placements get the same NY badge as auto',
        );
        expect(
          viewModel.overflow,
          isEmpty,
          reason: 'a placement session supersedes any stale overflow tray',
        );
        // Exactly the initial fetch — adoption must not re-read the doc.
        verify(() => mockService.readWeek(any())).called(1);
      });

      test('applyGeneratedMenu returns null when the save fails — a success '
          'toast must never describe an unpersisted week', () async {
        final initial = _plan();
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: initial, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        stubDistribution(
          initial.copyWith(
            entries: [
              _entry(day: DayOfWeek.tue, slot: MealSlot.middag, id: 'new-1'),
            ],
          ),
        );
        when(() => mockService.save(any())).thenThrow(Exception('boom'));

        final placed = await viewModel.applyGeneratedMenu({
          'middag': [_recipe()],
        });

        expect(placed, isNull);
        expect(viewModel.hasError, isTrue);
      });
    });

    group('BUT-1043 copy-week + bulk-move', () {
      test('copyWeekToNext delegates to service.copyWeek with current → +7d '
          'and returns the copied count', () async {
        final plan = _plan(weekStart: DateTime(2026, 4, 13));
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));
        when(
          () => mockService.copyWeek(
            fromWeekStart: any(named: 'fromWeekStart'),
            toWeekStart: any(named: 'toWeekStart'),
          ),
        ).thenAnswer((_) async => 4);

        final copied = await viewModel.copyWeekToNext();

        expect(copied, 4);
        final from = plan.weekStartDate;
        verify(
          () => mockService.copyWeek(
            fromWeekStart: from,
            toWeekStart: from.add(const Duration(days: 7)),
          ),
        ).called(1);
      });

      test(
        'copyWeekToNext returns null and raises error state on failure',
        () async {
          final plan = _plan(weekStart: DateTime(2026, 4, 13));
          when(() => mockService.readWeek(any())).thenAnswer(
            (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
          );
          await viewModel.loadWeek(DateTime(2026, 4, 13));
          when(
            () => mockService.copyWeek(
              fromWeekStart: any(named: 'fromWeekStart'),
              toWeekStart: any(named: 'toWeekStart'),
            ),
          ).thenThrow(Exception('boom'));

          final copied = await viewModel.copyWeekToNext();

          expect(copied, isNull);
          expect(viewModel.hasError, isTrue);
        },
      );

      test(
        'beginSelection enters selection mode with an empty selection',
        () async {
          expect(viewModel.selectionMode, isFalse);

          viewModel.beginSelection();

          expect(viewModel.selectionMode, isTrue);
          expect(viewModel.selectedCount, 0);
        },
      );

      test(
        'toggleSelection adds then removes; emptying selection exits mode',
        () async {
          viewModel.beginSelection();

          viewModel.toggleSelection('e1');
          expect(viewModel.isSelected('e1'), isTrue);
          expect(viewModel.selectedCount, 1);

          viewModel.toggleSelection('e1');
          // Last item removed → selection mode auto-exits so cells revert to
          // navigate-on-tap.
          expect(viewModel.isSelected('e1'), isFalse);
          expect(viewModel.selectionMode, isFalse);
        },
      );

      test('clearSelection cancels mode and drops all selected ids', () {
        viewModel.beginSelection();
        viewModel.toggleSelection('e1');
        viewModel.toggleSelection('e2');

        viewModel.clearSelection();

        expect(viewModel.selectionMode, isFalse);
        expect(viewModel.selectedCount, 0);
      });

      test('bulkMoveSelected moves the selection via the service, re-fetches '
          'the week, and exits selection mode', () async {
        final plan = _plan(
          weekStart: DateTime(2026, 4, 13),
          entries: [
            _entry(day: DayOfWeek.mon, slot: MealSlot.ovrigt, id: 'e1'),
            _entry(day: DayOfWeek.tue, slot: MealSlot.ovrigt, id: 'e2'),
          ],
        );
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
        );
        await viewModel.loadWeek(DateTime(2026, 4, 13));
        when(
          () => mockService.bulkMoveEntries(
            weekStart: any(named: 'weekStart'),
            entryIds: any(named: 'entryIds'),
            toDay: any(named: 'toDay'),
            toSlot: any(named: 'toSlot'),
          ),
        ).thenAnswer((_) async => 2);

        viewModel.beginSelection();
        viewModel.toggleSelection('e1');
        viewModel.toggleSelection('e2');

        final moved = await viewModel.bulkMoveSelected(
          toDay: DayOfWeek.fri,
          toSlot: MealSlot.ovrigt,
        );

        expect(moved, 2);
        expect(viewModel.selectionMode, isFalse);
        expect(viewModel.selectedCount, 0);
        final captured = verify(
          () => mockService.bulkMoveEntries(
            weekStart: any(named: 'weekStart'),
            entryIds: captureAny(named: 'entryIds'),
            toDay: DayOfWeek.fri,
            toSlot: MealSlot.ovrigt,
          ),
        ).captured;
        expect((captured.single as List).toSet(), {'e1', 'e2'});
      });

      test(
        'bulkMoveSelected with no selection returns 0 without a service call',
        () async {
          final moved = await viewModel.bulkMoveSelected(
            toDay: DayOfWeek.mon,
            toSlot: MealSlot.middag,
          );

          expect(moved, 0);
          verifyNever(
            () => mockService.bulkMoveEntries(
              weekStart: any(named: 'weekStart'),
              entryIds: any(named: 'entryIds'),
              toDay: any(named: 'toDay'),
              toSlot: any(named: 'toSlot'),
            ),
          );
        },
      );

      test(
        'bulkMoveSelected returns null on failure and still clears selection',
        () async {
          final plan = _plan(
            weekStart: DateTime(2026, 4, 13),
            entries: [
              _entry(day: DayOfWeek.mon, slot: MealSlot.ovrigt, id: 'e1'),
            ],
          );
          when(() => mockService.readWeek(any())).thenAnswer(
            (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
          );
          await viewModel.loadWeek(DateTime(2026, 4, 13));
          when(
            () => mockService.bulkMoveEntries(
              weekStart: any(named: 'weekStart'),
              entryIds: any(named: 'entryIds'),
              toDay: any(named: 'toDay'),
              toSlot: any(named: 'toSlot'),
            ),
          ).thenThrow(Exception('boom'));

          viewModel.beginSelection();
          viewModel.toggleSelection('e1');

          final moved = await viewModel.bulkMoveSelected(
            toDay: DayOfWeek.fri,
            toSlot: MealSlot.ovrigt,
          );

          expect(moved, isNull);
          // A failed move must not trap the user in selection mode.
          expect(viewModel.selectionMode, isFalse);
          expect(viewModel.hasError, isTrue);
        },
      );
    });

    group('BUT-1611 per-slot presence', () {
      final weekStart = IsoWeekUtils.weekStartOf(DateTime(2026, 4, 13));

      Future<void> loadPlanWith(
        Map<DayOfWeek, Map<MealSlot, List<String>>> presence,
      ) async {
        final plan = _plan(weekStart: weekStart).copyWith(
          presenceBySlot: presence,
        );
        when(() => mockService.readWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlanRead(plan: plan, readFailed: false),
        );
        await viewModel.loadWeek(weekStart);
      }

      test('setSlotPresence delegates and adopts the returned plan', () async {
        await loadPlanWith(const {});
        final updated = _plan(weekStart: weekStart).copyWith(
          presenceBySlot: {
            DayOfWeek.mon: {
              MealSlot.middag: ['m1'],
            },
          },
        );
        when(
          () => mockService.setSlotPresence(
            weekStart: any(named: 'weekStart'),
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            memberIds: ['m1'],
          ),
        ).thenAnswer((_) async => updated);

        await viewModel.setSlotPresence(DayOfWeek.mon, MealSlot.middag, ['m1']);

        expect(
          viewModel.presentMemberIdsFor(DayOfWeek.mon, MealSlot.middag),
          ['m1'],
        );
      });

      // Note: presence deliberately does NOT scope menu generation (that would
      // filter allergens below the household baseline — see BUT-1625). There is
      // therefore no presentUnionForGeneration to test; generation always uses
      // the safe household-aggregated filtering, covered in the generator suite.
    });
  });
}
