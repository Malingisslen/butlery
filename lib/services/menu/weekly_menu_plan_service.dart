/// Owns the today-anchored auto-distribution algorithm that converts
/// `MenuGenerator.generateMenuFromPrompt` output (a `Map<mealType, List<Recipe>>`)
/// into a `WeeklyMenuPlan` with one recipe per (day, slot) for lunch/middag
/// and stacked entries for the multi-recipe `övrigt` slot.
library;

import 'package:clock/clock.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/user_service.dart';

/// Result of [WeeklyMenuPlanService.distributeFromGeneratedMenu]: the new
/// plan plus any recipes that didn't fit (rendered in the overflow tray).
class WeeklyMenuDistributionResult {
  final WeeklyMenuPlan plan;
  final List<Recipe> overflow;

  const WeeklyMenuDistributionResult({
    required this.plan,
    required this.overflow,
  });
}

class WeeklyMenuPlanService extends BaseService {
  final WeeklyMenuPlanRepository _repository;
  final UserService _userService;

  WeeklyMenuPlanService({
    required WeeklyMenuPlanRepository repository,
    required UserService userService,
  })  : _repository = repository,
        _userService = userService;

  @override
  String get serviceName => 'WeeklyMenuPlanService';

  String? get _currentUserId => _userService.currentUserProfile?.uid;

  /// Loads the saved plan for the ISO week containing [date], or returns
  /// an empty plan if none exists.
  Future<WeeklyMenuPlan> getWeek(DateTime date) async {
    return await executeServiceOperation<WeeklyMenuPlan>(
          () async {
            final userId = _currentUserId;
            if (userId == null) {
              throw StateError('No authenticated user for getWeek');
            }
            final weekStart = IsoWeekUtils.weekStartOf(date);
            final saved = await _repository.fetchForWeek(
              userId: userId,
              weekStart: weekStart,
            );
            return saved ??
                WeeklyMenuPlan.empty(userId: userId, date: weekStart);
          },
          operationName: 'getWeek',
        ) ??
        WeeklyMenuPlan.empty(
          userId: _currentUserId ?? 'anonymous',
          date: IsoWeekUtils.weekStartOf(date),
        );
  }

  /// Persist [plan] (upsert by deterministic doc ID).
  Future<void> save(WeeklyMenuPlan plan) async {
    await executeServiceOperation(
      () => _repository.save(plan),
      operationName: 'saveWeeklyMenuPlan',
    );
  }

  /// BUT-893: scrub [recipeId] from every weekly plan owned by the current
  /// user. Returns the number of plans actually changed. Safe to call on a
  /// recipe that was never on any plan (returns 0). Designed to be invoked
  /// fire-and-forget from the recipe-delete cascade — failures are logged
  /// but never thrown, so the user's delete never fails because of menu
  /// cleanup glitches.
  Future<int> removeRecipeFromAllPlans(String recipeId) async {
    final userId = _currentUserId;
    if (userId == null) return 0;
    final result = await executeServiceOperation<int>(
      () => _repository.removeRecipeFromAllPlans(
        userId: userId,
        recipeId: recipeId,
      ),
      operationName: 'removeRecipeFromAllPlans',
    );
    return result ?? 0;
  }

  /// Auto-distribute the result of `MenuGenerator.generateMenuFromPrompt`
  /// onto a weekly plan using the today-anchored chronological algorithm.
  ///
  /// **Anchor:** if [weekStart] is the current ISO week, the anchor is today
  /// (no recipes on past days). For any other week, the anchor is Monday.
  ///
  /// **Lunch/middag:** one entry per cell. Skips days where the slot is
  /// already occupied in [existing]. Walks anchor → Sunday.
  ///
  /// **Övrigt:** unlimited entries per cell. Walks anchor → Sunday adding
  /// one per day; pre-existing övrigt entries are not removed but the
  /// algorithm still places one per day in chronological order. Anything
  /// that doesn't fit lands in [WeeklyMenuDistributionResult.overflow].
  ///
  /// [now] is injected for testability — defaults to `DateTime.now()`.
  WeeklyMenuDistributionResult distributeFromGeneratedMenu({
    required Map<String, List<Recipe>> generated,
    required DateTime weekStart,
    WeeklyMenuPlan? existing,
    DateTime? now,
    List<DayPin> dayPins = const [],
  }) {
    final userId = _currentUserId ?? 'anonymous';
    final evaluationTime = now ?? clock.now();
    final normalizedWeekStart = IsoWeekUtils.weekStartOf(weekStart);
    final currentWeekStart = IsoWeekUtils.weekStartOf(evaluationTime);
    final anchorIsToday = normalizedWeekStart == currentWeekStart;

    // Anchor index: 0 = Mon. For current week, start from today's weekday;
    // otherwise start from Monday.
    final anchorIndex =
        anchorIsToday ? DayOfWeek.fromDateTime(evaluationTime).index : 0;

    final base = existing ??
        WeeklyMenuPlan.empty(userId: userId, date: normalizedWeekStart);
    final mutableEntries = List<WeeklyMenuPlanEntry>.from(base.entries);
    final overflow = <Recipe>[];

    // Day pins (e.g. tacofredag) land first — they claim their weekday
    // before the generic chronological fill. Pinned recipes come from the
    // generated map; the pin's tag is matched against recipe tags.
    final pinnedRecipeIds = <String>{};
    for (final pin in dayPins) {
      final slotKey = pin.mealType;
      final recipes = generated[slotKey];
      if (recipes == null) continue;
      final match = recipes
          .where((r) =>
              !pinnedRecipeIds.contains(r.id) &&
              (pin.constraint.requiredTags.isEmpty ||
                  (r.tagResult?.hasAllTags(pin.constraint.requiredTags) ??
                      false)))
          .firstOrNull;
      if (match == null) continue;
      pinnedRecipeIds.add(match.id);
      // weekdayIndex is 1-based (Mon=1), DayOfWeek is 0-based index.
      final dayIdx = (pin.weekdayIndex - 1).clamp(0, DayOfWeek.sun.index);
      final day = DayOfWeek.values[dayIdx];
      final slot = mapMealTypeToSlot(slotKey);
      mutableEntries.add(_entryFor(day: day, slot: slot, recipe: match));
    }

    for (final entry in generated.entries) {
      final slot = mapMealTypeToSlot(entry.key);
      final recipes = entry.value;

      if (slot.isMulti) {
        // Övrigt — one per day Mon→Sun starting at anchor, no skip.
        var dayCursor = anchorIndex;
        for (final recipe in recipes) {
          if (pinnedRecipeIds.contains(recipe.id)) continue;
          if (dayCursor > DayOfWeek.sun.index) {
            overflow.add(recipe);
            continue;
          }
          mutableEntries.add(_entryFor(
            day: DayOfWeek.values[dayCursor],
            slot: slot,
            recipe: recipe,
          ));
          dayCursor += 1;
        }
      } else {
        // Lunch / middag — fill empty cells chronologically from anchor.
        for (final recipe in recipes) {
          if (pinnedRecipeIds.contains(recipe.id)) continue;
          DayOfWeek? targetDay;
          for (var i = anchorIndex; i <= DayOfWeek.sun.index; i++) {
            final candidate = DayOfWeek.values[i];
            final occupied =
                mutableEntries.any((e) => e.day == candidate && e.slot == slot);
            if (!occupied) {
              targetDay = candidate;
              break;
            }
          }
          if (targetDay == null) {
            overflow.add(recipe);
            continue;
          }
          mutableEntries.add(_entryFor(
            day: targetDay,
            slot: slot,
            recipe: recipe,
          ));
        }
      }
    }

    final newPlan = base.copyWith(entries: mutableEntries);
    return WeeklyMenuDistributionResult(plan: newPlan, overflow: overflow);
  }

  /// BUT-1013: append multiple recipes to a weekly plan starting at
  /// (day, slot). Semantic differs by slot kind:
  ///
  /// **Multi-slot (övrigt)** — all recipes stack at (startDay, slot). No
  /// overflow possible (övrigt has no per-day capacity).
  ///
  /// **Single-slot (lunch/middag)** — walks forward day-by-day from
  /// `startDay`, placing one recipe per empty cell. Cells already occupied
  /// in the loaded plan are **skipped** (the existing entry is preserved
  /// — bulk-add must never silently overwrite a user's deliberate
  /// placement). Recipes that run out of empty days before Sunday count
  /// as `overflowed`.
  ///
  /// Loads + saves the plan via this service. Returns counts so the UI can
  /// render an accurate snackbar.
  Future<({int added, int overflowed})> bulkAssignRecipes({
    required DateTime weekStart,
    required DayOfWeek startDay,
    required MealSlot slot,
    required List<Recipe> recipes,
  }) async {
    if (recipes.isEmpty) {
      return (added: 0, overflowed: 0);
    }
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user for bulkAssignRecipes');
    }
    final normalizedWeekStart = IsoWeekUtils.weekStartOf(weekStart);
    final fetched = await _repository.fetchForWeek(
      userId: userId,
      weekStart: normalizedWeekStart,
    );
    var plan = fetched ??
        WeeklyMenuPlan.empty(userId: userId, date: normalizedWeekStart);

    var added = 0;
    var overflowed = 0;
    if (slot.isMulti) {
      for (final recipe in recipes) {
        plan = addEntry(plan: plan, day: startDay, slot: slot, recipe: recipe);
        added++;
      }
    } else {
      var dayIdx = startDay.index;
      for (final recipe in recipes) {
        // Skip occupied cells without consuming a recipe slot; advance the
        // cursor until we find an empty day or fall off the end of the week.
        while (dayIdx <= DayOfWeek.sun.index) {
          final candidate = DayOfWeek.values[dayIdx];
          final occupied = plan.entriesAt(candidate, slot).isNotEmpty;
          if (!occupied) break;
          dayIdx++;
        }
        if (dayIdx > DayOfWeek.sun.index) {
          overflowed++;
          continue;
        }
        plan = addEntry(
          plan: plan,
          day: DayOfWeek.values[dayIdx],
          slot: slot,
          recipe: recipe,
        );
        added++;
        dayIdx++;
      }
    }
    // Use `_repository.save` directly (not `save()`), bypassing
    // `executeServiceOperation` which gates on service-initialised state
    // and is unfriendly to mock-only unit tests. The error surface for a
    // failed bulk-assign save is intentionally raw — the caller (snackbar
    // handler) catches and surfaces; we don't want a swallow-and-return-null.
    if (added > 0) await _repository.save(plan);
    return (added: added, overflowed: overflowed);
  }

  /// Add a single recipe to a (day, slot). For lunch/middag, replaces any
  /// existing entry; for övrigt, appends a new entry.
  WeeklyMenuPlan addEntry({
    required WeeklyMenuPlan plan,
    required DayOfWeek day,
    required MealSlot slot,
    required Recipe recipe,
  }) {
    final updated = List<WeeklyMenuPlanEntry>.from(plan.entries);
    if (!slot.isMulti) {
      updated.removeWhere((e) => e.day == day && e.slot == slot);
    }
    updated.add(_entryFor(day: day, slot: slot, recipe: recipe));
    return plan.copyWith(entries: updated);
  }

  /// Move a single entry by id to a new (day, slot). For single-recipe
  /// targets, swaps with the occupant if any. Self-drop is a no-op.
  WeeklyMenuPlan moveEntry({
    required WeeklyMenuPlan plan,
    required String entryId,
    required DayOfWeek toDay,
    required MealSlot toSlot,
  }) {
    final source = plan.entries.firstWhere(
      (e) => e.id == entryId,
      orElse: () => throw StateError('Entry $entryId not found'),
    );
    if (source.day == toDay && source.slot == toSlot) return plan;

    final updated = List<WeeklyMenuPlanEntry>.from(plan.entries);
    updated.removeWhere((e) => e.id == entryId);

    if (!toSlot.isMulti) {
      // Swap if target single-slot is occupied: occupant takes source's old
      // (day, slot), source takes the target.
      final occupantIndex = updated.indexWhere(
        (e) => e.day == toDay && e.slot == toSlot,
      );
      if (occupantIndex != -1) {
        final occupant = updated[occupantIndex];
        updated[occupantIndex] = occupant.copyWith(
          day: source.day,
          slot: source.slot,
        );
      }
    }
    updated.add(source.copyWith(day: toDay, slot: toSlot));
    return plan.copyWith(entries: updated);
  }

  /// Remove an entry by id. Returns the same plan unchanged if the id is
  /// missing, so the ViewModel can short-circuit via `identical` without
  /// triggering a no-op Firestore write.
  WeeklyMenuPlan removeEntry({
    required WeeklyMenuPlan plan,
    required String entryId,
  }) {
    final updated = plan.entries.where((e) => e.id != entryId).toList();
    if (updated.length == plan.entries.length) return plan;
    return plan.copyWith(entries: updated);
  }

  /// Clear every entry from the plan. No-op if already empty.
  WeeklyMenuPlan clearWeek(WeeklyMenuPlan plan) {
    if (plan.entries.isEmpty) return plan;
    return plan.copyWith(entries: const []);
  }

  WeeklyMenuPlanEntry _entryFor({
    required DayOfWeek day,
    required MealSlot slot,
    required Recipe recipe,
  }) {
    return WeeklyMenuPlanEntry.create(
      day: day,
      slot: slot,
      recipeId: recipe.id,
      recipeTitle: recipe.title,
      recipeImageUrl: recipe.primaryImageUrl,
    );
  }
}
