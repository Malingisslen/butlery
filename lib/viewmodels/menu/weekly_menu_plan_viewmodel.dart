/// ViewModel backing the calendar weekly menu view.
library;

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

  WeeklyMenuPlan? get plan => _plan;
  List<Recipe> get overflow => _overflow;
  ParsedMenuRequest? get lastParsedRequest => _lastParsedRequest;

  // Until the first `loadWeek` call completes, fall back to "this week".
  DateTime get currentWeekStart =>
      _plan?.weekStartDate ?? IsoWeekUtils.weekStartOf(DateTime.now());

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
            existing: _plan,
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
  Future<void> clearWeek() async {
    final current = _plan;
    if (current == null) return;
    if (current.isEmpty && _overflow.isEmpty) return;
    await executeAsyncVoid(
      () async {
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
