/// ViewModel backing the calendar weekly menu view.
library;

import 'package:butlery/core/utils/logger.dart';
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

  /// BUT-1975: an edit computed from `_plan` is being published. Carried ONLY
  /// by the operations that publish optimistically, and released by each of
  /// them the moment it has assigned `_plan`.
  ///
  /// Offline a Firestore write applies locally but its Future does not
  /// complete until the server acks (measured 2026-08-28 on the web SDK). A
  /// guard that spans
  /// the save therefore lasts the whole outage, which would allow exactly one
  /// offline edit and silently drop every later one.
  ///
  /// The writes that re-read through the repository instead of computing from
  /// `_plan` do NOT take it: they assign `_plan`, if at all, only after the
  /// service call has returned — which is the ack, so holding the flag until
  /// then is that same defect.
  bool _publishInFlight = false;

  /// Distribution keeps its own long guard: a double-tap must not distribute
  /// twice, and unlike a single-cell edit there is no sense in which the
  /// second run builds on the first.
  bool _applyInFlight = false;

  /// BUT-1939. Whether the last read of the week FAILED, as distinct from
  /// reading a week with nothing in it.
  /// The two protections are NOT independent: the same branch that sets this
  /// also sets `_plan = null`, which is the only thing stopping `assignRecipe`,
  /// `moveEntry`, `removeEntry`, `clearWeek`, `undoClearWeek` and
  /// `assignFromOverflow`. Keeping the last-known week on screen would remove
  /// that second guard for all six, so they would need their own.
  bool _readFailed = false;

  /// The week most recently asked for, so [currentWeekStart] can answer for a
  /// week whose read failed instead of falling back to today.
  DateTime? _requestedWeekStart;
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

  /// The week this viewmodel is showing, whether or not its plan loaded.
  ///
  /// `_requestedWeekStart` is the middle term because `_plan` is null in two
  /// different situations: nothing has been requested yet, and a requested week
  /// failed to read. Without it the second case answers "this week", and the
  /// getter is PUBLIC — `veckomeny_view.dart` hands it to the placement session,
  /// which would then target a week the user never chose (BUT-1939).
  DateTime get currentWeekStart =>
      _plan?.weekStartDate ??
      _requestedWeekStart ??
      IsoWeekUtils.weekStartOf(clock.now());

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
    if (_readFailed) return;
    await _executeWrite(
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
      guarded: false,
    );
  }

  /// BUT-1611 "Hela dagen": set the same selection on both meal slots of
  /// [day]. Null clears both back to the "everyone" default.
  Future<void> setDayPresence(DayOfWeek day, List<String>? memberIds) async {
    if (_readFailed) return;
    await _executeWrite(
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
      guarded: false,
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

  /// BUT-1975: `executeAsyncVoid` minus the loading flag, for WRITES.
  ///
  /// Reads own `isLoading`; writes must not, or an unacked write leaves the
  /// calendar showing a spinner over a plan it already has. Error handling is
  /// otherwise identical, so a refusal still reaches the user as its Swedish
  /// prefix.
  ///
  /// [guarded] is for the operations that compute an edit from `_plan` and
  /// publish it: they take [_publishInFlight] here and release it themselves
  /// once published. The writes that re-read through the repository pass
  /// false — see that field's doc.
  Future<bool> _executeWrite(
    Future<void> Function() operation, {
    required String errorPrefix,
    bool guarded = true,
  }) async {
    if (isDisposed) return false;
    if (guarded) {
      if (_publishInFlight) return false;
      _publishInFlight = true;
    }
    clearError();
    try {
      await operation();
      return true;
    } catch (e) {
      AppLogger.error(errorPrefix, e);
      if (!isDisposed) setError(errorPrefix);
      return false;
    } finally {
      if (guarded) _publishInFlight = false;
    }
  }

  /// BUT-1975/BUT-1965: put [updated] on screen now, persist after.
  ///
  /// Awaiting the save BEFORE assigning `_plan` is what made an offline edit
  /// invisible. A failure rolls the calendar back
  /// to [previous] and rethrows, so the caller's Swedish prefix still reaches
  /// the user.
  Future<void> _publishThenSave(
    WeeklyMenuPlan updated,
    WeeklyMenuPlan previous,
  ) async {
    _plan = updated;
    notifyListeners();
    // Released HERE, not when the save acks. A guard held across the save
    // lasts the whole outage and allows exactly one offline edit.
    _publishInFlight = false;
    try {
      await _service.save(updated);
    } catch (_) {
      // Roll back only what is still on screen. The user may have navigated to
      // another week, or a later edit may have superseded this one, while the
      // refusal was in flight — restoring unconditionally would drag the
      // calendar back to a week they had left.
      if (!isDisposed && identical(_plan, updated)) {
        _plan = previous;
        notifyListeners();
      }
      rethrow;
    }
  }

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
    // BUT-1939. Without this the flag outlives the failure: the placement
    // session read and saved this exact week successfully, but `loadWeek`
    // short-circuits on a matching `weekStartDate`, so nothing would ever
    // re-fetch and clear it — leaving every guarded action silently inert
    // until the user navigates away.
    _readFailed = false;
    // The placement session is the new truth for that week; whatever the
    // tray held that wasn't placed was deliberately left out.
    _overflow = const [];
    _recentlyPlacedEntryIds = recentlyPlacedEntryIds;
    notifyListeners();
  }

  Future<void> _fetchWeek(DateTime weekStart) async {
    _requestedWeekStart = weekStart;
    await executeAsyncVoid(
      () async {
        final read = await _service.readWeek(weekStart);
        if (isDisposed) return;
        if (read.readFailed) {
          // BUT-1939. `getWeek` spells a failed read as an EMPTY plan, which is
          // indistinguishable from a week with nothing saved.
          _plan = null;
          _readFailed = true;
          // The selection belongs to the week that just failed to load, so it
          // must not survive into the next one.
          _selectionMode = false;
          _selectedEntryIds.clear();
          setError(weeklyPlanReadFailedMessage);
          return;
        }
        _readFailed = false;
        final fetched = read.plan;
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
    // A refused second tap returns null WITHOUT setting an error: on this
    // surface `LoadingStateBuilder` ranks error above data, so a message here
    // replaces the whole calendar — including the week the first tap just
    // placed. The error state's own retry does not recover it either:
    // `onErrorRetry` calls `loadWeek`, which short-circuits when the resident
    // plan already matches that week, so it never reaches `clearError`.
    // Silence is the lesser fault; making the refusal visible needs a channel
    // the view can tell apart from failure, the way `generateShoppingList`
    // uses its `alreadyRunning` sentinel. BUT-1987.
    if (_readFailed || _applyInFlight) return null;
    final previousPlan = _plan;
    final previousOverflow = _overflow;
    final previousPlacedIds = _recentlyPlacedEntryIds;
    final previousParsedRequest = _lastParsedRequest;
    _applyInFlight = true;
    int? placedCount;
    final ok = await _executeWrite(
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
        // Assigned only once the distribution has actually produced a result:
        // set before the guard is evaluated, a refused call would leave the
        // header chips describing a distribution that never ran.
        _lastParsedRequest = parsedRequest;
        final newIds = result.plan.entries
            .map((e) => e.id)
            .where((id) => !baseIds.contains(id))
            .toSet();
        // BUT-1975/BUT-1965: publish FIRST. The old order awaited the save
        // before assigning `_plan`, so offline the generated week was never
        // rendered at all.
        _plan = result.plan;
        _overflow = result.overflow;
        _recentlyPlacedEntryIds = newIds;
        placedCount = newIds.length;
        notifyListeners();
        _publishInFlight = false;
        try {
          await _service.save(result.plan);
        } catch (_) {
          // Every piece this method set, including the parsed request the
          // header chips read — a refused distribution must not leave them
          // describing a week that was rejected. Only while it is still the
          // resident plan: the user may have moved on while the refusal was
          // in flight.
          if (!isDisposed && identical(_plan, result.plan)) {
            _plan = previousPlan;
            _overflow = previousOverflow;
            _recentlyPlacedEntryIds = previousPlacedIds;
            _lastParsedRequest = previousParsedRequest;
            notifyListeners();
          }
          rethrow;
        }
      },
      errorPrefix: 'Kunde inte fördela recepten',
    );
    _applyInFlight = false;
    if (!ok) return null;
    return placedCount;
  }

  /// Returns whether the entry was actually persisted. [assignFromOverflow]
  /// needs that answer: the overflow tray is in-memory only and nothing
  /// repopulates it, so pruning a chip after a refused save loses the recipe
  /// until the menu is regenerated.
  Future<bool> assignRecipe({
    required DayOfWeek day,
    required MealSlot slot,
    required Recipe recipe,
  }) async {
    final current = _plan;
    if (current == null) return false;
    return _executeWrite(
      () async {
        final updated = _service.addEntry(
          plan: current,
          day: day,
          slot: slot,
          recipe: recipe,
        );
        if (isDisposed) return;
        await _publishThenSave(updated, current);
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
    await _executeWrite(
      () async {
        final updated = _service.moveEntry(
          plan: current,
          entryId: entryId,
          toDay: toDay,
          toSlot: toSlot,
        );
        if (isDisposed || identical(updated, current)) return;
        await _publishThenSave(updated, current);
      },
      errorPrefix: 'Kunde inte flytta receptet',
    );
  }

  Future<void> removeEntry(String entryId) async {
    final current = _plan;
    if (current == null) return;
    await _executeWrite(
      () async {
        final updated = _service.removeEntry(plan: current, entryId: entryId);
        if (isDisposed || identical(updated, current)) return;
        await _publishThenSave(updated, current);
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
  /// Returns whether the week was actually cleared. The view needs that: the
  /// success snackbar carries the "Ångra" affordance, and a refused clear arms
  /// no undo snapshot, so announcing it would offer a dead button on top of
  /// the error state.
  Future<bool> clearWeek() async {
    final current = _plan;
    if (current == null) return false;
    if (current.isEmpty && _overflow.isEmpty) return false;
    final previousOverflow = _overflow;
    return _executeWrite(
      () async {
        final cleared = _service.clearWeek(current);
        if (isDisposed) return;
        // Snapshots read the PRE-clear values, so they are taken from `current`
        // and `_overflow` before the assignments below.
        _preClearEntries = List.unmodifiable(current.entries);
        _preClearOverflow = List.unmodifiable(previousOverflow);
        _plan = cleared;
        _overflow = const [];
        notifyListeners();
        _publishInFlight = false;
        if (identical(cleared, current)) return;
        try {
          await _service.save(cleared);
        } catch (_) {
          // The clear was shown before it was persisted, so a refusal puts
          // back all four pieces — plan, tray, and both halves of the undo
          // window it armed. Leaving the snapshot would offer "Ångra" for a
          // clear that never happened. Only if it is still the resident plan:
          // the user may have moved on while the refusal was in flight.
          if (!isDisposed && identical(_plan, cleared)) {
            _plan = current;
            _overflow = previousOverflow;
            _preClearEntries = null;
            _preClearOverflow = null;
            notifyListeners();
          }
          rethrow;
        }
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
    final previousOverflow = _overflow;
    await _executeWrite(
      () async {
        final restored = _service.restoreWeek(current, snapshot);
        if (isDisposed) return;
        _plan = restored;
        // Restore the tray too — clearWeek wiped it, so undo must bring it back
        // or the overflow recipes vanish even though the user tapped "Ångra".
        _overflow = overflowSnapshot ?? const [];
        _preClearEntries = null;
        _preClearOverflow = null;
        notifyListeners();
        _publishInFlight = false;
        try {
          await _service.save(restored);
        } catch (_) {
          // Shown before persisted, so a refusal puts the cleared week back
          // AND re-arms the snapshot — otherwise the user has neither their
          // week nor a second chance at "Ångra".
          if (!isDisposed && identical(_plan, restored)) {
            _plan = current;
            _overflow = previousOverflow;
            _preClearEntries = snapshot;
            _preClearOverflow = overflowSnapshot;
            notifyListeners();
          }
          rethrow;
        }
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
    if (_readFailed) return null;
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
    // Prune only once the write landed. The tray is the recipe's only
    // remaining home — `_fetchWeek` does not repopulate it — so pruning on a
    // refused save dropped it for good.
    final saved = await assignRecipe(day: day, slot: slot, recipe: recipe);
    if (isDisposed || !saved) return;
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
    if (_readFailed) return null;
    final from = currentWeekStart;
    final to = from.add(const Duration(days: 7));
    int? copied;
    final ok = await _executeWrite(
      () async {
        copied = await _service.copyWeek(
          fromWeekStart: from,
          toWeekStart: to,
        );
      },
      errorPrefix: 'Kunde inte kopiera veckan',
      guarded: false,
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
    if (_readFailed) return null;
    if (_selectedEntryIds.isEmpty) return 0;
    final ids = _selectedEntryIds.toList(growable: false);
    final weekStart = currentWeekStart;
    int? moved;
    final ok = await _executeWrite(
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
      guarded: false,
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
