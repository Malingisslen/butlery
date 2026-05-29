/// ViewModel backing the calendar weekly menu view.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

class WeeklyMenuPlanViewModel extends BaseViewModel {
  final WeeklyMenuPlanService _service;
  final UnifiedRecipeService _recipeService;

  WeeklyMenuPlanViewModel({
    required WeeklyMenuPlanService service,
    required UnifiedRecipeService recipeService,
  })  : _service = service,
        _recipeService = recipeService;

  WeeklyMenuPlan? _plan;
  List<Recipe> _overflow = const [];
  bool _applyInFlight = false;
  ParsedMenuRequest? _lastParsedRequest;

  // Snapshot kept for the 7-second undo window after clearWeek. Both the
  // visible entries AND the overflow tray are captured so undo restores the
  // full pre-clear state — clearWeek wipes both, so undo must restore both or
  // the overflow recipes are lost permanently.
  List<WeeklyMenuPlanEntry>? _preClearEntries;
  List<Recipe>? _preClearOverflow;

  WeeklyMenuPlan? get plan => _plan;
  List<Recipe> get overflow => _overflow;
  ParsedMenuRequest? get lastParsedRequest => _lastParsedRequest;

  // Until the first `loadWeek` call completes, fall back to "this week".
  DateTime get currentWeekStart =>
      _plan?.weekStartDate ?? IsoWeekUtils.weekStartOf(clock.now());

  bool get hasOverflow => _overflow.isNotEmpty;
  bool get hasEntries => _plan?.isNotEmpty ?? false;

  List<WeeklyMenuPlanEntry> entriesAt(DayOfWeek day, MealSlot slot) {
    return _plan?.entriesAt(day, slot) ?? const [];
  }

  /// Resolves a recipe by ID for navigation. Returns null if deleted.
  Recipe? resolveForNavigation(String recipeId) =>
      _recipeService.getRecipeById(recipeId);

  Future<void> loadWeek(DateTime date) async {
    final targetWeekStart = IsoWeekUtils.weekStartOf(date);
    if (_plan != null && _plan!.weekStartDate == targetWeekStart) return;
    await executeAsyncVoid(
      () async {
        final fetched = await _service.getWeek(targetWeekStart);
        if (isDisposed) return;
        _plan = fetched;
        notifyListeners();
      },
      errorPrefix: 'Kunde inte ladda veckomenyn',
    );
  }

  Future<void> nextWeek() async {
    await loadWeek(currentWeekStart.add(const Duration(days: 7)));
  }

  Future<void> previousWeek() async {
    await loadWeek(currentWeekStart.subtract(const Duration(days: 7)));
  }

  /// Apply a generated menu (from `MenuGenerator.generateMenuFromPrompt`)
  /// to the currently visible week. Guarded against concurrent runs so
  /// two rapid taps don't race each other on the same plan.
  Future<void> applyGeneratedMenu(
    Map<String, List<Recipe>> generated, {
    DateTime? now,
    ParsedMenuRequest? parsedRequest,
    bool replaceExisting = false,
  }) async {
    if (_applyInFlight) return;
    _applyInFlight = true;
    _lastParsedRequest = parsedRequest;
    try {
      await executeAsyncVoid(
        () async {
          final result = _service.distributeFromGeneratedMenu(
            generated: generated,
            weekStart: currentWeekStart,
            existing:
                replaceExisting ? _plan?.copyWith(entries: const []) : _plan,
            now: now,
            dayPins: parsedRequest?.dayPins ?? const [],
          );
          if (isDisposed) return;
          _plan = result.plan;
          _overflow = result.overflow;
          await _service.save(result.plan);
          if (isDisposed) return;
          notifyListeners();
        },
        errorPrefix: 'Kunde inte fördela recepten',
      );
    } finally {
      _applyInFlight = false;
    }
  }

  Future<void> assignRecipe({
    required DayOfWeek day,
    required MealSlot slot,
    required Recipe recipe,
  }) async {
    final current = _plan;
    if (current == null) return;
    await executeAsyncVoid(
      () async {
        final updated = _service.addEntry(
          plan: current,
          day: day,
          slot: slot,
          recipe: recipe,
        );
        if (isDisposed) return;
        _plan = updated;
        await _service.save(updated);
        if (isDisposed) return;
        notifyListeners();
      },
      errorPrefix: 'Kunde inte lägga till receptet',
    );
  }

  Future<void> moveEntry({
    required String entryId,
    required DayOfWeek toDay,
    required MealSlot toSlot,
  }) async {
    final current = _plan;
    if (current == null) return;
    await executeAsyncVoid(
      () async {
        final updated = _service.moveEntry(
          plan: current,
          entryId: entryId,
          toDay: toDay,
          toSlot: toSlot,
        );
        if (isDisposed || identical(updated, current)) return;
        _plan = updated;
        await _service.save(updated);
        if (isDisposed) return;
        notifyListeners();
      },
      errorPrefix: 'Kunde inte flytta receptet',
    );
  }

  Future<void> removeEntry(String entryId) async {
    final current = _plan;
    if (current == null) return;
    await executeAsyncVoid(
      () async {
        final updated = _service.removeEntry(plan: current, entryId: entryId);
        if (isDisposed || identical(updated, current)) return;
        _plan = updated;
        await _service.save(updated);
        if (isDisposed) return;
        notifyListeners();
      },
      errorPrefix: 'Kunde inte ta bort receptet',
    );
  }

  /// Clear every entry from the visible week ("Rensa veckan" action).
  ///
  /// Snapshots both the current entries and the overflow tray before wiping so
  /// [undoClearWeek] can restore the full state within the 7-second SnackBar
  /// window. The overflow snapshot is required because clearWeek also wipes the
  /// tray — without it, undo would silently lose the overflow recipes.
  Future<void> clearWeek() async {
    final current = _plan;
    if (current == null) return;
    if (current.isEmpty && _overflow.isEmpty) return;
    await executeAsyncVoid(
      () async {
        // Capture snapshots before mutating so the undo path can restore both.
        _preClearEntries = List.unmodifiable(current.entries);
        _preClearOverflow = List.unmodifiable(_overflow);
        final cleared = _service.clearWeek(current);
        if (isDisposed) return;
        final entriesChanged = !identical(cleared, current);
        _plan = cleared;
        _overflow = const [];
        if (entriesChanged) await _service.save(cleared);
        if (isDisposed) return;
        notifyListeners();
      },
      errorPrefix: 'Kunde inte rensa veckan',
    );
  }

  /// Restore the entries and overflow tray present before the last [clearWeek]
  /// call. No-op if no snapshot exists (undo window expired or never set).
  Future<void> undoClearWeek() async {
    final snapshot = _preClearEntries;
    final overflowSnapshot = _preClearOverflow;
    final current = _plan;
    if (snapshot == null || current == null) return;
    _preClearEntries = null;
    _preClearOverflow = null;
    await executeAsyncVoid(
      () async {
        final restored = _service.restoreWeek(current, snapshot);
        if (isDisposed) return;
        _plan = restored;
        // Restore the tray too — clearWeek wiped it, so undo must bring it back
        // or the overflow recipes vanish even though the user tapped "Ångra".
        _overflow = overflowSnapshot ?? const [];
        await _service.save(restored);
        if (isDisposed) return;
        notifyListeners();
      },
      errorPrefix: 'Kunde inte ångra rensningen',
    );
  }

  /// Drop a recipe from the overflow tray into a slot.
  Future<void> assignFromOverflow({
    required Recipe recipe,
    required DayOfWeek day,
    required MealSlot slot,
  }) async {
    await assignRecipe(day: day, slot: slot, recipe: recipe);
    if (isDisposed) return;
    final pruned = _overflow.where((r) => r.id != recipe.id).toList();
    if (pruned.length == _overflow.length) return;
    _overflow = pruned;
    notifyListeners();
  }
}
