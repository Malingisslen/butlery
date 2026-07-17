/// ViewModel backing the calendar weekly menu view.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

class WeeklyMenuPlanViewModel extends BaseViewModel {
  final WeeklyMenuPlanService _service;
  final UnifiedRecipeService _recipeService;
  final MenuShoppingListGenerator _shoppingListGenerator;

  WeeklyMenuPlanViewModel({
    required WeeklyMenuPlanService service,
    required UnifiedRecipeService recipeService,
    required MenuShoppingListGenerator shoppingListGenerator,
  }) : _service = service,
       _recipeService = recipeService,
       _shoppingListGenerator = shoppingListGenerator;

  WeeklyMenuPlan? _plan;
  List<Recipe> _overflow = const [];
  bool _applyInFlight = false;
  ParsedMenuRequest? _lastParsedRequest;

  // BUT-1241: entry ids placed by the most recent auto-distribution, used
  // by the calendar cells to render the "NY" badge. Cleared whenever a
  // (re)load replaces the plan — the badge only lives for the session that
  // triggered the generation.
  Set<String> _recentlyPlacedEntryIds = const {};

  // Snapshot kept for the 7-second undo window after clearWeek. Both the
  // visible entries AND the overflow tray are captured so undo restores the
  // full pre-clear state — clearWeek wipes both, so undo must restore both or
  // the overflow recipes are lost permanently.
  List<WeeklyMenuPlanEntry>? _preClearEntries;
  List<Recipe>? _preClearOverflow;

  // BUT-1043: long-press multi-select state for bulk-move. When
  // [_selectionMode] is on, calendar cells toggle selection on tap instead
  // of navigating; the selection bar then offers "move N to (day, slot)".
  // Kept separate from drag-and-drop (which owns long-press) so the two
  // gestures never collide.
  bool _selectionMode = false;
  final Set<String> _selectedEntryIds = <String>{};

  WeeklyMenuPlan? get plan => _plan;
  List<Recipe> get overflow => _overflow;
  ParsedMenuRequest? get lastParsedRequest => _lastParsedRequest;

  bool get selectionMode => _selectionMode;
  Set<String> get selectedEntryIds => Set.unmodifiable(_selectedEntryIds);
  int get selectedCount => _selectedEntryIds.length;
  bool isSelected(String entryId) => _selectedEntryIds.contains(entryId);

  /// BUT-1241: whether [entryId] was placed by the most recent
  /// auto-distribution (renders the "NY" badge).
  bool isRecentlyPlaced(String entryId) =>
      _recentlyPlacedEntryIds.contains(entryId);

  // Until the first `loadWeek` call completes, fall back to "this week".
  DateTime get currentWeekStart =>
      _plan?.weekStartDate ?? IsoWeekUtils.weekStartOf(clock.now());

  bool get hasOverflow => _overflow.isNotEmpty;
  bool get hasEntries => _plan?.isNotEmpty ?? false;

  List<WeeklyMenuPlanEntry> entriesAt(DayOfWeek day, MealSlot slot) {
    return _plan?.entriesAt(day, slot) ?? const [];
  }

  /// BUT-1611: the explicit "who's home" selection for [day]/[slot], or null
  /// when the slot has none (= everyone, the default).
  List<String>? presentMemberIdsFor(DayOfWeek day, MealSlot slot) =>
      _plan?.presentMemberIdsFor(day, slot);

  /// BUT-1611: persist who's home for a single meal [slot] on [day]. Null
  /// clears the slot back to the "everyone" default.
  Future<void> setSlotPresence(
    DayOfWeek day,
    MealSlot slot,
    List<String>? memberIds,
  ) async {
    await executeAsyncVoid(
      () async {
        final updated = await _service.setSlotPresence(
          weekStart: currentWeekStart,
          day: day,
          slot: slot,
          memberIds: memberIds,
        );
        if (isDisposed) return;
        _plan = updated;
        notifyListeners();
      },
      errorPrefix: 'Kunde inte spara vilka som är hemma',
    );
  }

  /// BUT-1611 "Hela dagen": set the same selection on both meal slots of
  /// [day]. Null clears both back to the "everyone" default.
  Future<void> setDayPresence(DayOfWeek day, List<String>? memberIds) async {
    await executeAsyncVoid(
      () async {
        final updated = await _service.setDayPresence(
          weekStart: currentWeekStart,
          day: day,
          memberIds: memberIds,
        );
        if (isDisposed) return;
        _plan = updated;
        notifyListeners();
      },
      errorPrefix: 'Kunde inte spara vilka som är hemma',
    );
  }

  // BUT-1611 note: presence intentionally does NOT scope menu generation.
  // A present-diner union would filter allergens below the whole-household
  // baseline (övrigt is eaten by everyone; single-section re-rolls reuse a
  // stale set), so generation keeps the safe household-aggregated filtering
  // (BUT-1464). Safe present-aware generation is deferred to BUT-1625.

  /// Resolves a recipe by ID for navigation. Returns null if deleted.
  Recipe? resolveForNavigation(String recipeId) =>
      _recipeService.getRecipeById(recipeId);

  Future<void> loadWeek(DateTime date) async {
    final targetWeekStart = IsoWeekUtils.weekStartOf(date);
    if (_plan != null && _plan!.weekStartDate == targetWeekStart) return;
    await _fetchWeek(targetWeekStart);
  }

  /// BUT-1241: adopt a plan the manual placement flow already persisted —
  /// the saved document would otherwise be re-read from Firestore just to
  /// learn what we already hold in memory. [recentlyPlacedEntryIds] carries
  /// the session's placements so manual placements get the same "NY" badge
  /// treatment as auto-distribution.
  void adoptPlan(
    WeeklyMenuPlan plan, {
    Set<String> recentlyPlacedEntryIds = const {},
  }) {
    _plan = plan;
    // The placement session is the new truth for that week; whatever the
    // tray held that wasn't placed was deliberately left out.
    _overflow = const [];
    _recentlyPlacedEntryIds = recentlyPlacedEntryIds;
    notifyListeners();
  }

  Future<void> _fetchWeek(DateTime weekStart) async {
    await executeAsyncVoid(
      () async {
        final fetched = await _service.getWeek(weekStart);
        if (isDisposed) return;
        _plan = fetched;
        _recentlyPlacedEntryIds = const {};
        // A week (re)load is a fresh context — drop any in-progress
        // selection so it can't apply to entries from a different week.
        _selectionMode = false;
        _selectedEntryIds.clear();
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
  ///
  /// BUT-1241: returns the number of entries actually placed (null when the
  /// call was skipped or failed) so the view can render the
  /// "N recept placerade" toast. Newly placed entry ids are tracked for the
  /// "NY" badge via [isRecentlyPlaced].
  Future<int?> applyGeneratedMenu(
    Map<String, List<Recipe>> generated, {
    DateTime? now,
    ParsedMenuRequest? parsedRequest,
    bool replaceExisting = false,
  }) async {
    if (_applyInFlight) return null;
    _applyInFlight = true;
    _lastParsedRequest = parsedRequest;
    int? placedCount;
    try {
      final ok = await executeAsyncVoid(
        () async {
          final base = replaceExisting
              ? _plan?.copyWith(entries: const [])
              : _plan;
          final baseIds = base?.entries.map((e) => e.id).toSet() ?? const {};
          final result = _service.distributeFromGeneratedMenu(
            generated: generated,
            weekStart: currentWeekStart,
            existing: base,
            now: now,
            dayPins: parsedRequest?.dayPins ?? const [],
          );
          if (isDisposed) return;
          // Persist FIRST, publish after: a failed save must not leave the
          // calendar showing a distributed week (with NY badges) that was
          // never written.
          await _service.save(result.plan);
          if (isDisposed) return;
          final newIds = result.plan.entries
              .map((e) => e.id)
              .where((id) => !baseIds.contains(id))
              .toSet();
          _plan = result.plan;
          _overflow = result.overflow;
          _recentlyPlacedEntryIds = newIds;
          placedCount = newIds.length;
          notifyListeners();
        },
        errorPrefix: 'Kunde inte fördela recepten',
      );
      // A failed save must not report success either.
      if (!ok) return null;
    } finally {
      _applyInFlight = false;
    }
    return placedCount;
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

  /// BUT-956/BUT-1234: aggregate the visible week's recipes into one
  /// shopping list ("Generera inköpslista" FAB).
  ///
  /// Three-way result contract the view renders snackbars from:
  /// - non-null with `isEmptyPlan == false` → success
  /// - non-null `nothingToGenerate` sentinel → week has no resolvable recipes
  /// - null → generation FAILED
  ///
  /// Re-entrancy rides on [isLoading] (set synchronously by executeAsync) —
  /// the view disables the FAB while loading; a racing second call returns
  /// the [MenuShoppingGenerationResult.alreadyRunning] sentinel, which the
  /// view renders as silence (a double-tap is not a failure). The
  /// generator's own error path swallows
  /// exceptions into a null return, so the catch below only fires for
  /// failures outside it; either way the caller sees null = failure.
  Future<MenuShoppingGenerationResult?> generateShoppingList() async {
    if (isLoading) return MenuShoppingGenerationResult.alreadyRunning;
    try {
      return await executeAsync(
        () => _shoppingListGenerator.generateForWeek(currentWeekStart),
        errorPrefix: 'Kunde inte skapa inköpslistan',
      );
    } catch (_) {
      // executeAsync already set the error state and logged the details.
      return null;
    }
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

  /// BUT-1043: copy every entry from the visible week into the following
  /// ISO week, surfacing the additive, duplicate-skipping `copyWeek` service
  /// primitive as a UI action ("Kopiera denna vecka → nästa vecka").
  ///
  /// Returns the number of entries copied (0 when the next week already has
  /// all of them / this week is empty), or null when the call failed — the
  /// view distinguishes "nothing to copy" (count 0) from an error (null).
  /// Does NOT navigate to next week; the user stays on the current week so
  /// the copy is a non-disruptive background action.
  Future<int?> copyWeekToNext() async {
    final from = currentWeekStart;
    final to = from.add(const Duration(days: 7));
    int? copied;
    final ok = await executeAsyncVoid(
      () async {
        copied = await _service.copyWeek(
          fromWeekStart: from,
          toWeekStart: to,
        );
      },
      errorPrefix: 'Kunde inte kopiera veckan',
    );
    if (!ok) return null;
    return copied;
  }

  /// BUT-1043: enter multi-select mode with an empty selection (header
  /// "Välj flera att flytta" button). Cells then toggle selection on tap.
  /// No-op if already selecting.
  void beginSelection() {
    if (_selectionMode) return;
    _selectionMode = true;
    notifyListeners();
  }

  /// Toggle [entryId] in the current selection. Exiting the last selection
  /// also leaves selection mode so the cells revert to navigate-on-tap.
  void toggleSelection(String entryId) {
    if (_selectedEntryIds.contains(entryId)) {
      _selectedEntryIds.remove(entryId);
    } else {
      _selectedEntryIds.add(entryId);
    }
    if (_selectedEntryIds.isEmpty) _selectionMode = false;
    notifyListeners();
  }

  /// Cancel selection mode and clear every selected id.
  void clearSelection() {
    if (!_selectionMode && _selectedEntryIds.isEmpty) return;
    _selectionMode = false;
    _selectedEntryIds.clear();
    notifyListeners();
  }

  /// BUT-1043: move every selected entry to (toDay, toSlot) in a single
  /// persisted write via the service's `bulkMoveEntries`, then refresh the
  /// in-memory plan and leave selection mode. Returns the number moved, or
  /// null on failure (view shows an error). A no-op selection returns 0.
  Future<int?> bulkMoveSelected({
    required DayOfWeek toDay,
    required MealSlot toSlot,
  }) async {
    if (_selectedEntryIds.isEmpty) return 0;
    final ids = _selectedEntryIds.toList(growable: false);
    final weekStart = currentWeekStart;
    int? moved;
    final ok = await executeAsyncVoid(
      () async {
        moved = await _service.bulkMoveEntries(
          weekStart: weekStart,
          entryIds: ids,
          toDay: toDay,
          toSlot: toSlot,
        );
        if (isDisposed) return;
        // Re-read so the calendar reflects the persisted layout. The plan's
        // weekStart hasn't changed, so loadWeek would short-circuit — force
        // a fetch.
        await _fetchWeek(weekStart);
      },
      errorPrefix: 'Kunde inte flytta recepten',
    );
    // Clear selection regardless of outcome — a failed move shouldn't leave
    // the user trapped in selection mode over a now-uncertain plan.
    _selectionMode = false;
    _selectedEntryIds.clear();
    if (isDisposed) return null;
    notifyListeners();
    if (!ok) return null;
    return moved;
  }
}
