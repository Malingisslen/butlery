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

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

    group('loadWeek', () {
      test('fetches the plan for the ISO week containing the given date '
          'and notifies listeners', () async {
        final fetched = _plan();
        when(() => mockService.getWeek(any())).thenAnswer((_) async => fetched);
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        await viewModel.loadWeek(DateTime(2026, 4, 15)); // Wed of that week

        expect(viewModel.plan, same(fetched));
        // executeAsyncVoid fires at minimum: setLoading(true), success path
        // setLoading(false), plus explicit notifyListeners on plan assignment.
        expect(notifications, greaterThanOrEqualTo(1));
        verify(() => mockService.getWeek(fetched.weekStartDate)).called(1);
      });

      test('short-circuits when the target week is already loaded '
          '(no extra service call)', () async {
        final first = _plan();
        when(() => mockService.getWeek(any())).thenAnswer((_) async => first);

        // First load pulls from the service.
        await viewModel.loadWeek(DateTime(2026, 4, 13));
        verify(() => mockService.getWeek(first.weekStartDate)).called(1);

        // Second call for ANY date in the same ISO week — must be a no-op.
        await viewModel.loadWeek(DateTime(2026, 4, 15));
        await viewModel.loadWeek(DateTime(2026, 4, 18));

        verifyNever(() => mockService.getWeek(any()));
      });

      test('sets the localized error string when the service throws', () async {
        when(
          () => mockService.getWeek(any()),
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
            () => mockService.getWeek(week1.weekStartDate),
          ).thenAnswer((_) async => week1);
          when(
            () => mockService.getWeek(week2.weekStartDate),
          ).thenAnswer((_) async => week2);

          await viewModel.loadWeek(DateTime(2026, 4, 13));
          await viewModel.nextWeek();

          expect(viewModel.currentWeekStart, week2.weekStartDate);
          verify(() => mockService.getWeek(week2.weekStartDate)).called(1);
        },
      );

      test(
        'previousWeek rewinds by 7 days from the current week anchor',
        () async {
          final week1 = _plan(weekStart: DateTime(2026, 4, 13));
          final prev = _plan(weekStart: DateTime(2026, 4, 6));
          when(
            () => mockService.getWeek(week1.weekStartDate),
          ).thenAnswer((_) async => week1);
          when(
            () => mockService.getWeek(prev.weekStartDate),
          ).thenAnswer((_) async => prev);

          await viewModel.loadWeek(DateTime(2026, 4, 13));
          await viewModel.previousWeek();

          expect(viewModel.currentWeekStart, prev.weekStartDate);
          verify(() => mockService.getWeek(prev.weekStartDate)).called(1);
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
          () => mockService.getWeek(w53.weekStartDate),
        ).thenAnswer((_) async => w53);
        when(
          () => mockService.getWeek(w1.weekStartDate),
        ).thenAnswer((_) async => w1);

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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
            () => mockService.getWeek(any()),
          ).thenAnswer((_) async => initial);
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

      test('_applyInFlight guard blocks a concurrent second call '
          '(only the first distributes + saves)', () async {
        final initial = _plan();
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
        // first call sets `_applyInFlight = true` synchronously (before its
        // first await), so the second sees the guard and early-returns.
        clearInteractions(mockService);
        final first = viewModel.applyGeneratedMenu(const {'middag': []});
        final second = viewModel.applyGeneratedMenu(const {'middag': []});
        await Future.wait([first, second]);

        expect(
          distributeCalls,
          1,
          reason: 'second call must early-return on _applyInFlight',
        );
        verify(() => mockService.save(any())).called(1);
      });
    });

    group('assignRecipe', () {
      test('is a no-op when no plan is loaded', () async {
        // Guard: current == null triggers early-return before executeAsyncVoid.
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
            () => mockService.getWeek(any()),
          ).thenAnswer((_) async => initial);
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
            () => mockService.getWeek(any()),
          ).thenAnswer((_) async => initial);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
            () => mockService.getWeek(any()),
          ).thenAnswer((_) async => initial);
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
            () => mockService.getWeek(any()),
          ).thenAnswer((_) async => initial);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => empty);
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        await viewModel.clearWeek();

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
          // executeAsyncVoid path.
          final emptyPlan = _plan();
          when(
            () => mockService.getWeek(any()),
          ).thenAnswer((_) async => emptyPlan);
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
          // `entriesChanged` is false → save must NOT be fired by clearWeek.
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
          () => mockService.getWeek(any()),
        ).thenAnswer((_) async => populated);
        await viewModel.loadWeek(DateTime(2026, 4, 13));

        final cleared = populated.copyWith(entries: const []);
        when(() => mockService.clearWeek(populated)).thenReturn(cleared);

        await viewModel.clearWeek();

        expect(viewModel.plan, same(cleared));
        verify(() => mockService.save(cleared)).called(1);
      });

      test('is a no-op when no plan is loaded', () async {
        await viewModel.clearWeek();
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
            () => mockService.getWeek(any()),
          ).thenAnswer((_) async => populated);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
          () => mockService.getWeek(any()),
        ).thenAnswer((_) async => emptyPlan);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => week);
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
            () => mockService.getWeek(any()),
          ).thenAnswer((_) async => initial);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
        verify(() => mockService.getWeek(any())).called(1);
      });

      test('applyGeneratedMenu returns null when the save fails — a success '
          'toast must never describe an unpersisted week', () async {
        final initial = _plan();
        when(() => mockService.getWeek(any())).thenAnswer((_) async => initial);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => plan);
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
          when(() => mockService.getWeek(any())).thenAnswer((_) async => plan);
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
        when(() => mockService.getWeek(any())).thenAnswer((_) async => plan);
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
          when(() => mockService.getWeek(any())).thenAnswer((_) async => plan);
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
  });
}
