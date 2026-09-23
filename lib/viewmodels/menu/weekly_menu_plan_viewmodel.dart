/// ViewModel backing the calendar weekly menu view.
library;

import 'dart:async';

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

  /// [overflowTrayStore] keeps the overflow tray on this device (P5-U24). It
  /// defaults to the SharedPreferences store; tests pass their own.
  WeeklyMenuPlanViewModel({
    required WeeklyMenuPlanService service,
    required UnifiedRecipeService recipeService,
    required MenuShoppingListGenerator shoppingListGenerator,
    WeeklyMenuOverflowTrayStore? overflowTrayStore,
  }) : _service = service,
       _recipeService = recipeService,
       _shoppingListGenerator = shoppingListGenerator,
       _trayStore = overflowTrayStore ?? WeeklyMenuOverflowTrayStore();

  final WeeklyMenuOverflowTrayStore _trayStore;

  WeeklyMenuPlan? _plan;

  /// P5-U23/U24: the overflow tray, "ett arbetsförråd, inte en notis"
  /// (produktregler.md:1123-1127). Its recipes, the meal type each was
  /// generated for, why they did not fit, and how many recipes the
  /// distribution was given, so the tray can say "2 av 5 rätter placerade"
  /// (produktregler.md:206).
  _OverflowTray _tray = _OverflowTray.empty;

  /// Set once anything has changed the tray in this session, so a slow
  /// restore from the device never overwrites a newer tray.
  bool _trayTouched = false;
  bool _trayRestoreStarted = false;

  /// P5-U24: listens to the recipe list while a restored tray still holds
  /// ids the list could not answer for yet (a cold start, or web, where the
  /// recipes arrive from Firestore after the first week read).
  StreamSubscription<Object?>? _pendingTraySub;

  List<Recipe> get _overflow => _tray.recipes;

  /// Replaces the tray's recipes and keeps what the tray knows about them
  /// (reason, total, meal types). Every change is kept on the device.
  set _overflow(List<Recipe> recipes) => _setTray(_tray.withRecipes(recipes));

  /// P5-U23: the order the latest automatic placement followed, as entry
  /// ids. Shown as numbers in the cells (produktregler.md:1126, :890).
  List<String> _placementOrder = const [];

  /// BUT-1975: an edit computed from `_plan` is being published.
  ///
  /// Offline a Firestore write applies locally but its Future does not
  /// complete until the server acks (measured 2026-08-28 on the web SDK). A
  /// guard that spans
  /// the save therefore lasts the whole outage, which would allow exactly one
  /// offline edit and silently drop every later one.
  bool _publishInFlight = false;

  /// Distribution keeps its own long guard: a double-tap must not distribute
  /// twice, and unlike a single-cell edit there is no sense in which the
  /// second run builds on the first.
  bool _applyInFlight = false;

  /// BUT-1987: what the placement button reads — the same flag, so the control
  /// is busy exactly while a second tap would be refused. The refusal itself
  /// stays silent: this surface ranks error above data, so a message here would
  /// replace the calendar the first tap just placed.
  bool get isPlacingGeneratedMenu => _applyInFlight;

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
  _OverflowTray? _preClearOverflow;

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

  /// P5-U23: the 1-based place of [entryId] in the order the latest
  /// automatic placement followed, or null when it was not part of it.
  /// "Placeringsordningen visas som siffror i rutorna, så resultatet inte är
  /// en gissning" (produktregler.md:1126; Skarmar v12 etapp 11:249-254).
  int? placementOrderOf(String entryId) {
    final index = _placementOrder.indexOf(entryId);
    return index < 0 ? null : index + 1;
  }

  /// P5-U23: why the tray's recipes did not fit. Null without a tray, or for
  /// a tray whose reason is unknown.
  WeeklyMenuOverflowReason? get overflowReason =>
      _overflow.isEmpty ? null : _tray.reason;

  /// P5-U23: how many recipes the distribution behind the tray was given.
  /// With [overflowPlacedCount] it reads "2 av 5 rätter placerade"
  /// (produktregler.md:206: a partial result is counted in recipes).
  int get overflowTotal =>
      _tray.total < _overflow.length ? _overflow.length : _tray.total;

  /// P5-U23: how many of [overflowTotal] have a place now. Placing a chip
  /// from the tray counts it as placed.
  int get overflowPlacedCount => overflowTotal - _overflow.length;

  /// P5-U23: whether the tray offers the following week (produktregler.md:
  /// 1127: "nästa vecka är ett val i brickan").
  ///
  /// A kept tray can outlive its week (P5-U24 keeps it 30 days): once the
  /// week it offers lies before the current week, the choice is not
  /// offered, so a past week is never filled.
  bool get canPlaceOverflowInNextWeek {
    final reason = _tray.reason;
    return _overflow.isNotEmpty &&
        reason != null &&
        reason.nextWeekOffered &&
        _nextWeekNotPassed(reason, clock.now());
  }

  /// Whether [reason]'s next week is the current ISO week or later. The
  /// current week itself is fine: distribution then starts from today.
  static bool _nextWeekNotPassed(
    WeeklyMenuOverflowReason reason,
    DateTime now,
  ) => !reason.nextWeekStart.isBefore(IsoWeekUtils.weekStartOf(now));

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
  ///
  /// Returns whether the selection was actually persisted (BUT-1982). The view
  /// needs that: it announces the change, and a refusal already paints the
  /// error state, so announcing on top of it tells the user their attendance
  /// was saved when it was not.
  Future<bool> setSlotPresence(
    DayOfWeek day,
    MealSlot slot,
    List<String>? memberIds,
  ) async {
    if (_readFailed) return false;
    final current = _plan;
    if (current == null) return false;
    return _executeWrite(
      () async {
        final updated = WeeklyMenuPlanService.withPresence(
          plan: current,
          day: day,
          slots: [slot],
          memberIds: memberIds,
        );
        if (isDisposed) return;
        await _publishThenSave(updated, current);
      },
      errorPrefix: 'Kunde inte spara vilka som är hemma',
      guarded: false,
    );
  }

  /// BUT-1611 "Hela dagen": set the same selection on both meal slots of
  /// [day]. Null clears both back to the "everyone" default.
  ///
  /// Returns whether the selection was actually persisted, for the same reason
  /// as [setSlotPresence] (BUT-1982).
  Future<bool> setDayPresence(DayOfWeek day, List<String>? memberIds) async {
    if (_readFailed) return false;
    final current = _plan;
    if (current == null) return false;
    return _executeWrite(
      () async {
        final updated = WeeklyMenuPlanService.withPresence(
          plan: current,
          day: day,
          slots: kPresenceSlots,
          memberIds: memberIds,
        );
        if (isDisposed) return;
        await _publishThenSave(updated, current);
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
  /// [guarded] takes [_publishInFlight] here, and the operation releases it
  /// itself once published.
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
    _setTray(_OverflowTray.empty);
    _recentlyPlacedEntryIds = recentlyPlacedEntryIds;
    _placementOrder = const [];
    notifyListeners();
  }

  Future<void> _fetchWeek(DateTime weekStart) async {
    _requestedWeekStart = weekStart;
    // P5-U24: the first read of a week in this session also brings back the
    // tray this device kept. Not awaited: the week never waits for it.
    if (!_trayRestoreStarted) {
      _trayRestoreStarted = true;
      unawaited(restoreOverflowTray());
    }
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
        _placementOrder = const [];
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
  /// [onPublished] fires the moment the distributed week is on screen, with
  /// the number of entries placed — BEFORE the save is awaited. Offline the
  /// save never acks, so a caller that waits for the return value shows the
  /// user nothing at all (BUT-2124). It is the same publish-first contract
  /// BUT-1975 gave the plan itself. A later refusal rolls the week back and
  /// surfaces the error, so a caller must be able to undo what it did here.
  Future<int?> applyGeneratedMenu(
    Map<String, List<Recipe>> generated, {
    DateTime? now,
    ParsedMenuRequest? parsedRequest,
    bool replaceExisting = false,
    void Function(int placed)? onPublished,
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
    final previousTray = _tray;
    final previousPlacedIds = _recentlyPlacedEntryIds;
    final previousOrder = _placementOrder;
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
        _setTray(
          _OverflowTray(
            recipes: List.unmodifiable(result.overflow),
            mealTypes: _mealTypesFor(result, generated),
            reason: result.overflowReason,
            total: newIds.length + result.overflow.length,
          ),
        );
        _recentlyPlacedEntryIds = newIds;
        _placementOrder = List.unmodifiable(newIds);
        placedCount = newIds.length;
        notifyListeners();
        _publishInFlight = false;
        // A caller's callback does UI work, and it sits inside the write
        // closure: letting it throw would skip the save entirely.
        try {
          onPublished?.call(newIds.length);
        } catch (e) {
          AppLogger.error('applyGeneratedMenu: onPublished threw', e);
        }
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
            _setTray(previousTray);
            _recentlyPlacedEntryIds = previousPlacedIds;
            _placementOrder = previousOrder;
            _lastParsedRequest = previousParsedRequest;
            notifyListeners();
          }
          rethrow;
        }
      },
      // BUT-2132, Malin's call 2026-09-20: ONE message on every path. The
      // rollback this method may or may not have performed is deliberately not
      // described, because a message that names it is false wherever the undo
      // was skipped — and that branch is reachable.
      errorPrefix: 'Veckan kunde inte sparas',
    );
    _applyInFlight = false;
    // BUT-1987: the footer reads this through `context.watch`, so the release
    // has to be announced or the button never stops spinning.
    if (!isDisposed) notifyListeners();
    if (!ok) return null;
    return placedCount;
  }

  /// Returns whether the entry was actually persisted. [assignFromOverflow]
  /// needs that answer: nothing but the tray itself repopulates the tray (the
  /// device copy of P5-U24 mirrors it, it is not a second source), so pruning
  /// a chip after a refused save loses the recipe until the menu is
  /// regenerated.
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
    final previousOverflow = _tray;
    return _executeWrite(
      () async {
        final cleared = _service.clearWeek(current);
        if (isDisposed) return;
        // Snapshots read the PRE-clear values, so they are taken from `current`
        // and `_overflow` before the assignments below.
        _preClearEntries = List.unmodifiable(current.entries);
        _preClearOverflow = previousOverflow;
        _plan = cleared;
        _setTray(_OverflowTray.empty);
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
            _setTray(previousOverflow);
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
    final previousOverflow = _tray;
    await _executeWrite(
      () async {
        final restored = _service.restoreWeek(current, snapshot);
        if (isDisposed) return;
        _plan = restored;
        // Restore the tray too — clearWeek wiped it, so undo must bring it back
        // or the overflow recipes vanish even though the user tapped "Ångra".
        _setTray(overflowSnapshot ?? _OverflowTray.empty);
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
            _setTray(previousOverflow);
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
    // BUT-1986: prune at publish, and put the chip back if the save is
    // refused. Waiting for the ack left the chip on screen through an offline
    // outage, so the same recipe could be dropped into a second slot. The tray
    // is the recipe's only remaining home — `_fetchWeek` does not repopulate
    // it — so the restore is what keeps a refused save from losing it.
    final before = _overflow;
    final targetWeek = currentWeekStart;
    final index = before.indexWhere((r) => r.id == recipe.id);
    final pruned = before.where((r) => r.id != recipe.id).toList();
    if (pruned.length != before.length) {
      _overflow = pruned;
      notifyListeners();
    }
    final saved = await assignRecipe(day: day, slot: slot, recipe: recipe);
    if (isDisposed || saved) return;
    // BUT-2125: restore into whatever tray is resident NOW, not only the one
    // this drop pruned. The old identity test lost the recipe outright when a
    // SECOND drop pruned its own chip first: the tray was then that drop's
    // list, the test failed, and the recipe was in neither the tray nor the
    // week. The conditions below all have to hold before it goes back:
    //   - the chip was in the tray to begin with,
    //   - the user is still on the week this drop targeted,
    //   - the recipe is not already in the tray (a duplicate chip), and
    //   - no entry on the resident week carries it, which is what a later
    //     re-distribution that actually placed it would leave behind.
    if (index < 0) return;
    if (currentWeekStart != targetWeek) return;
    if (_overflow.any((r) => r.id == recipe.id)) return;
    final placed = _plan?.entries.any((e) => e.recipeId == recipe.id) ?? false;
    if (placed) return;
    final restored = List<Recipe>.of(_overflow);
    restored.insert(index.clamp(0, restored.length), recipe);
    _overflow = restored;
    notifyListeners();
  }

  /// P5-U23: the tray's "Lägg i vecka N" (produktregler.md:1127: with the tray,
  /// FL-11 is unnecessary; next week is a choice in the tray, not an action
  /// in a snackbar. Skarmar v12 etapp 11 breda vyer:241).
  ///
  /// Distributes the tray's recipes into the week after the one that had no
  /// room, the same way a generation is distributed (from Monday, occupied
  /// places are left alone). What does not fit there either stays in the
  /// tray, and the tray then offers no further week: produktregler.md:893
  /// makes the two-week limit something the user sees.
  ///
  /// Publish first, like every write here (BUT-1975): the tray changes at
  /// once and a refused save puts it back. Returns how many recipes moved,
  /// or null when nothing was done or the save was refused.
  Future<int?> placeOverflowInNextWeek({DateTime? now}) async {
    final reason = _tray.reason;
    if (_overflow.isEmpty || reason == null || !reason.nextWeekOffered) {
      return null;
    }
    if (!_nextWeekNotPassed(reason, now ?? clock.now())) return null;
    if (_applyInFlight) return null;
    _applyInFlight = true;
    final target = reason.nextWeekStart;
    final before = _tray;
    int? moved;
    final ok = await _executeWrite(
      () async {
        final read = await _service.readWeek(target);
        if (isDisposed) return;
        if (read.readFailed) throw StateError(weeklyPlanReadFailedMessage);
        final generated = <String, List<Recipe>>{};
        for (final recipe in before.recipes) {
          final mealType = before.mealTypes[recipe.id] ?? recipe.mealType;
          (generated[mealType] ??= []).add(recipe);
        }
        final result = _service.distributeFromGeneratedMenu(
          generated: generated,
          weekStart: target,
          existing: read.plan,
          now: now,
        );
        if (isDisposed) return;
        final rest = result.overflow;
        moved = before.recipes.length - rest.length;
        _setTray(
          _OverflowTray(
            recipes: List.unmodifiable(rest),
            mealTypes: before.mealTypes,
            reason: WeeklyMenuOverflowReason(
              weekStart: target,
              nextWeekOffered: false,
            ),
            total: before.total,
            unresolvedIds: rest.isEmpty ? const [] : before.unresolvedIds,
          ),
        );
        final showsTarget = _plan?.weekStartDate == target;
        final previousPlan = _plan;
        if (showsTarget) _plan = result.plan;
        notifyListeners();
        try {
          await _service.save(result.plan);
        } catch (_) {
          if (!isDisposed) {
            _setTray(before);
            if (showsTarget && identical(_plan, result.plan)) {
              _plan = previousPlan;
            }
            notifyListeners();
          }
          rethrow;
        }
      },
      errorPrefix: 'Veckan kunde inte sparas',
      guarded: false,
    );
    _applyInFlight = false;
    if (!isDisposed) notifyListeners();
    return ok ? moved : null;
  }

  /// P5-U24: brings back the tray this device kept for the signed-in user
  /// (produktregler.md:1125: the tray "överlever omladdning, ligger kvar
  /// tills den töms"). Does nothing when this session already changed the
  /// tray, so a restore never overwrites a newer tray.
  ///
  /// An id the recipe list cannot answer for right now is NOT treated as a
  /// deleted recipe: the list may simply not have loaded yet (cold start,
  /// web). The device copy is left exactly as it was, the chip is hidden
  /// until the list answers, and [_resolvePendingTray] brings it back when
  /// the recipe list changes.
  Future<void> restoreOverflowTray() async {
    final owner = _service.overflowTrayOwnerId;
    if (owner == null) return;
    final kept = await _trayStore.load(owner);
    if (kept == null || isDisposed || _trayTouched) return;
    final recipes = <Recipe>[];
    final unresolved = <String>[];
    for (final id in kept.recipeIds) {
      final recipe = _recipeService.getRecipeById(id);
      if (recipe == null) {
        unresolved.add(id);
      } else {
        recipes.add(recipe);
      }
    }
    _tray = _OverflowTray(
      recipes: List.unmodifiable(recipes),
      mealTypes: kept.mealTypes,
      reason: kept.reason,
      total: kept.total,
      unresolvedIds: List.unmodifiable(unresolved),
    );
    if (unresolved.isNotEmpty) {
      _pendingTraySub ??= _recipeService.stateStream.listen(
        (_) => _resolvePendingTray(),
      );
    }
    notifyListeners();
  }

  /// P5-U24: moves ids the recipe list now answers for from the hidden
  /// pending set back into the tray. The set of ids kept on the device does
  /// not change, so nothing is written.
  void _resolvePendingTray() {
    if (isDisposed) return;
    final pending = _tray.unresolvedIds;
    if (pending.isEmpty) {
      _stopPendingTray();
      return;
    }
    final found = <Recipe>[];
    final still = <String>[];
    for (final id in pending) {
      final recipe = _recipeService.getRecipeById(id);
      if (recipe == null) {
        still.add(id);
      } else {
        found.add(recipe);
      }
    }
    if (found.isEmpty) return;
    _tray = _OverflowTray(
      recipes: List.unmodifiable([..._tray.recipes, ...found]),
      mealTypes: _tray.mealTypes,
      reason: _tray.reason,
      total: _tray.total,
      unresolvedIds: List.unmodifiable(still),
    );
    if (still.isEmpty) _stopPendingTray();
    notifyListeners();
  }

  void _stopPendingTray() {
    unawaited(_pendingTraySub?.cancel());
    _pendingTraySub = null;
  }

  @override
  void dispose() {
    _stopPendingTray();
    super.dispose();
  }

  /// Sets the tray and keeps it on this device (P5-U24).
  void _setTray(_OverflowTray tray) {
    _trayTouched = true;
    _tray = tray;
    _persistTray();
  }

  void _persistTray() {
    final owner = _service.overflowTrayOwnerId;
    if (owner == null) return;
    final tray = _tray;
    // Ids still waiting for the recipe list are kept with the rest; they
    // go only when the visible tray is emptied (withRecipes drops them).
    final ids = [for (final r in tray.recipes) r.id, ...tray.unresolvedIds];
    if (tray.unresolvedIds.isEmpty) _stopPendingTray();
    unawaited(
      _trayStore.save(
        owner,
        ids.isEmpty
            ? null
            : WeeklyMenuOverflowTraySnapshot(
                recipeIds: ids,
                mealTypes: {
                  for (final id in ids)
                    if (tray.mealTypes[id] != null) id: tray.mealTypes[id]!,
                },
                total: tray.total,
                savedAt: clock.now(),
                reason: tray.reason,
              ),
      ),
    );
  }

  /// The meal type each overflowed recipe was generated for. A result built
  /// without them (older callers) falls back to the generated map's keys.
  static Map<String, String> _mealTypesFor(
    WeeklyMenuDistributionResult result,
    Map<String, List<Recipe>> generated,
  ) {
    if (result.overflowMealTypes.isNotEmpty) return result.overflowMealTypes;
    return {
      for (final entry in generated.entries)
        for (final recipe in entry.value) recipe.id: entry.key,
    };
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

/// P5-U23/U24: the overflow tray's state. Immutable, so a rollback can put
/// the whole tray back in one assignment.
class _OverflowTray {
  const _OverflowTray({
    required this.recipes,
    this.mealTypes = const {},
    this.reason,
    this.total = 0,
    this.unresolvedIds = const [],
  });

  static const empty = _OverflowTray(recipes: []);

  /// P5-U24: kept ids the recipe list could not answer for yet. Hidden from
  /// the tray, never dropped as "deleted" (see restoreOverflowTray).
  final List<String> unresolvedIds;

  final List<Recipe> recipes;
  final Map<String, String> mealTypes;
  final WeeklyMenuOverflowReason? reason;
  final int total;

  /// Emptying the visible tray empties it for good: pending ids go too.
  _OverflowTray withRecipes(List<Recipe> next) => _OverflowTray(
    recipes: List.unmodifiable(next),
    mealTypes: mealTypes,
    reason: reason,
    total: total,
    unresolvedIds: next.isEmpty ? const [] : unresolvedIds,
  );
}
