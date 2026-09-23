/// Owns the today-anchored auto-distribution algorithm that converts
/// `MenuGenerator.generateMenuFromPrompt` output (a `Map<mealType, List<Recipe>>`)
/// into a `WeeklyMenuPlan` with one recipe per (day, slot) for lunch/middag
/// and stacked entries for the multi-recipe `övrigt` slot.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
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

  /// P5-U23: the meal type each overflowed recipe was generated for, keyed by
  /// recipe id. The tray needs it to distribute the rest into next week.
  final Map<String, String> overflowMealTypes;

  /// P5-U23 (produktregler.md:1125, § 22.6): why the rest did not fit. Null
  /// when nothing overflowed, or when the caller built the result by hand.
  final WeeklyMenuOverflowReason? overflowReason;

  const WeeklyMenuDistributionResult({
    required this.plan,
    required this.overflow,
    this.overflowMealTypes = const {},
    this.overflowReason,
  });
}

/// P5-U23: why recipes did not fit (produktregler.md:1125: the tray "säger
/// *varför* resten inte fick plats"; Skarmar v12 etapp 11 breda vyer:235).
///
/// A recipe overflows only when its kind of place has no free place left in
/// [weekStart] from the anchor on: lunch and middag take one each, övrigt one
/// per day (distributeFromGeneratedMenu). When [weekStart] is the current
/// week the anchor is today, so days that have passed were never offered;
/// [pastDaysSkipped] says so, because that is part of the reason.
@immutable
class WeeklyMenuOverflowReason {
  const WeeklyMenuOverflowReason({
    required this.weekStart,
    this.pastDaysSkipped = false,
    this.nextWeekOffered = true,
  });

  /// Monday of the week that had no room.
  final DateTime weekStart;

  /// Days before today were skipped (only in the current week).
  final bool pastDaysSkipped;

  /// Whether the tray may offer the following week. False once the tray has
  /// been moved on one week: produktregler.md:893 makes the two-week limit
  /// something the user sees, never a silent third week.
  final bool nextWeekOffered;

  /// Monday of the week the tray offers next.
  DateTime get nextWeekStart => weekStart.add(const Duration(days: 7));

  WeeklyMenuOverflowReason copyWith({bool? nextWeekOffered}) =>
      WeeklyMenuOverflowReason(
        weekStart: weekStart,
        pastDaysSkipped: pastDaysSkipped,
        nextWeekOffered: nextWeekOffered ?? this.nextWeekOffered,
      );

  Map<String, Object?> toJson() => {
    'weekStart': weekStart.toIso8601String(),
    'pastDaysSkipped': pastDaysSkipped,
    'nextWeekOffered': nextWeekOffered,
  };

  static WeeklyMenuOverflowReason? fromJson(Object? json) {
    if (json is! Map) return null;
    final week = DateTime.tryParse('${json['weekStart']}');
    if (week == null) return null;
    return WeeklyMenuOverflowReason(
      weekStart: IsoWeekUtils.weekStartOf(week),
      pastDaysSkipped: json['pastDaysSkipped'] == true,
      nextWeekOffered: json['nextWeekOffered'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WeeklyMenuOverflowReason &&
      other.weekStart == weekStart &&
      other.pastDaysSkipped == pastDaysSkipped &&
      other.nextWeekOffered == nextWeekOffered;

  @override
  int get hashCode => Object.hash(weekStart, pastDaysSkipped, nextWeekOffered);
}

/// P5-U24: what the overflow tray keeps on the device between sessions.
///
/// Recipes are kept by id and resolved again on restore, so a recipe deleted
/// in the meantime does not come back. Nothing here is written to the shared
/// week: the tray is the unplaced rest of a week generation, and
/// produktregler.md:164-172 keeps a generation's local draft on the device
/// only (Q-A11: per person, on the device).
@immutable
class WeeklyMenuOverflowTraySnapshot {
  const WeeklyMenuOverflowTraySnapshot({
    required this.recipeIds,
    required this.mealTypes,
    required this.total,
    required this.savedAt,
    this.reason,
  });

  /// The tray's recipes, in tray order.
  final List<String> recipeIds;

  /// Meal type per recipe id (see [WeeklyMenuDistributionResult]).
  final Map<String, String> mealTypes;

  /// How many recipes the distribution was given (placed plus overflow).
  final int total;

  /// Last change. The tray lives 30 days from here (produktregler.md:169).
  final DateTime savedAt;

  final WeeklyMenuOverflowReason? reason;

  Map<String, Object?> toJson() => {
    'recipeIds': recipeIds,
    'mealTypes': mealTypes,
    'total': total,
    'savedAt': savedAt.toIso8601String(),
    'reason': reason?.toJson(),
  };

  static WeeklyMenuOverflowTraySnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final ids = json['recipeIds'];
    final savedAt = DateTime.tryParse('${json['savedAt']}');
    if (ids is! List || savedAt == null) return null;
    final types = json['mealTypes'];
    final total = json['total'];
    return WeeklyMenuOverflowTraySnapshot(
      recipeIds: [for (final id in ids) '$id'],
      mealTypes: types is Map
          ? {for (final e in types.entries) '${e.key}': '${e.value}'}
          : const {},
      total: total is int ? total : ids.length,
      savedAt: savedAt,
      reason: WeeklyMenuOverflowReason.fromJson(json['reason']),
    );
  }
}

/// P5-U24: keeps the overflow tray on this device, per person, 30 days.
///
/// produktregler.md:164-172 (the local draft of a week generation): only on
/// the device, never in the cloud until saved; 30 days since the last change;
/// deleted when saved (here: when the tray is emptied), when discarded, when
/// its lifetime runs out, and at logout. The key carries the user id, so
/// another account on the same device never sees someone else's tray.
///
/// Logout: [clearAll] is the hook. Decision 2026-09-23 (PQ-12 = A) keeps
/// device drafts through an AUTOMATIC logout (inactivity) and deletes them
/// only when the user logs out herself, so the call belongs in the manual
/// sign-out path only (`AuthService.signOut`, not `logoutDueToInactivity`).
///
/// Best-effort like `AutoSaveManager`: a storage error is logged and never
/// breaks placing a recipe.
class WeeklyMenuOverflowTrayStore {
  WeeklyMenuOverflowTrayStore({
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefsProvider;

  /// Every key this store writes starts with this.
  static const String keyPrefix = 'weekly_menu_overflow_tray_v1:';

  /// How long an untouched tray is kept (produktregler.md:169).
  static const Duration lifetime = Duration(days: 30);

  static String keyFor(String userId) => '$keyPrefix$userId';

  /// The kept tray for [userId], or null when there is none, when it is
  /// older than [lifetime] (it is then deleted), or when it cannot be read.
  Future<WeeklyMenuOverflowTraySnapshot?> load(String userId) async {
    try {
      final prefs = await _prefsProvider();
      final raw = prefs.getString(keyFor(userId));
      if (raw == null || raw.isEmpty) return null;
      final snapshot = WeeklyMenuOverflowTraySnapshot.fromJson(
        jsonDecode(raw),
      );
      if (snapshot == null ||
          snapshot.recipeIds.isEmpty ||
          clock.now().difference(snapshot.savedAt) > lifetime) {
        await prefs.remove(keyFor(userId));
        return null;
      }
      return snapshot;
    } catch (e) {
      AppLogger.warning('WeeklyMenuOverflowTrayStore: load failed ($e)');
      return null;
    }
  }

  /// Keeps [snapshot] for [userId]; an empty or null snapshot deletes it.
  Future<void> save(
    String userId,
    WeeklyMenuOverflowTraySnapshot? snapshot,
  ) async {
    try {
      final prefs = await _prefsProvider();
      if (snapshot == null || snapshot.recipeIds.isEmpty) {
        await prefs.remove(keyFor(userId));
        return;
      }
      await prefs.setString(keyFor(userId), jsonEncode(snapshot.toJson()));
    } catch (e) {
      AppLogger.warning('WeeklyMenuOverflowTrayStore: save failed ($e)');
    }
  }

  /// The manual-logout hook: deletes the kept tray of [userId], the person
  /// logging out. Another account's tray on the same device stays, since an
  /// automatic logout is meant to keep it (PQ-12 = A). Without a [userId]
  /// every kept tray on the device goes.
  static Future<void> clearAll({
    String? userId,
    Future<SharedPreferences> Function()? prefsProvider,
  }) async {
    try {
      final prefs = await (prefsProvider ?? SharedPreferences.getInstance)();
      if (userId != null) {
        await prefs.remove(keyFor(userId));
        return;
      }
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(keyPrefix)) await prefs.remove(key);
      }
    } catch (e) {
      AppLogger.warning('WeeklyMenuOverflowTrayStore: clearAll failed ($e)');
    }
  }
}

/// Outcome of a weekly-plan read (BUT-1928).
///
/// [plan] is always usable — the saved week, or an empty plan when the week has
/// none. [readFailed] is the part a bare [WeeklyMenuPlan] cannot carry: an empty
/// plan means "nothing saved yet" AND "the fetch never answered".
/// Display may ignore the flag; anything that WRITES must not.
///
/// Measured 2026-08-27: saving on top of the second one does NOT overwrite a
/// STORED week. An empty plan carries a fresh `createdAt` and the update limb
/// refuses a changed one — pinned by W2 in
/// `functions/src/__tests__/weekly-menu-plans-rules.test.ts`. The create limb
/// carries no such conjunct, so on a week with no document the same save is a
/// create and lands.
class WeeklyMenuPlanRead {
  final WeeklyMenuPlan plan;
  final bool readFailed;

  const WeeklyMenuPlanRead({required this.plan, required this.readFailed});
}

/// The refusal message shown when [WeeklyMenuPlanRead.readFailed] said the week
/// could not be read (BUT-1939).
///
/// One string rather than one per surface: the refusal is the same event everywhere,
/// and two spellings of it drift. It names the retry because the failure is a read
/// that did not answer, which the next attempt may well survive — unlike the
/// generic fallback, which tells the user nothing they can act on.
///
/// BUT-1984: the text lives in the ARB files now, not in this file. `AppLocale`
/// rather than `context.l10n` because three of the five call sites are a
/// viewmodel or a service with no `BuildContext` — the same accessor
/// `BaseService` already uses for its own user-facing errors. It stays a single
/// symbol so the one-string decision above survives the move.
String get weeklyPlanReadFailedMessage =>
    AppLocale.current.weeklyPlanReadFailed;

class WeeklyMenuPlanService extends BaseService {
  final WeeklyMenuPlanRepository _repository;
  final UserService _userService;

  WeeklyMenuPlanService({
    required WeeklyMenuPlanRepository repository,
    required UserService userService,
  }) : _repository = repository,
       _userService = userService;

  @override
  String get serviceName => 'WeeklyMenuPlanService';

  String? get _currentUserId => _userService.currentUserProfile?.uid;

  /// P5-U24: whose overflow tray this device keeps (null when signed out).
  String? get overflowTrayOwnerId => _currentUserId;

  /// Loads the saved plan for the ISO week containing [date], or returns
  /// an empty plan if none exists.
  ///
  /// A failed read is reported as an empty plan here, which is fine for display
  /// and unsafe for a caller about to save.
  Future<WeeklyMenuPlan> getWeek(DateTime date) async {
    return (await readWeek(date)).plan;
  }

  /// [getWeek] plus the one bit it cannot return: whether the fetch actually
  /// answered (BUT-1928).
  ///
  /// `readFailed` is true when the wrapped read did not answer — a throwing
  /// repository or a failed auth pre-flight — because either leaves the caller
  /// holding an empty plan that does not describe what is saved. A repository
  /// that maps an unreachable week to null rather than throwing is NOT covered:
  /// that route reports `readFailed: false` and is indistinguishable here from
  /// a week with nothing saved.
  Future<WeeklyMenuPlanRead> readWeek(DateTime date) async {
    final weekStart = IsoWeekUtils.weekStartOf(date);
    final read = await executeServiceOperation<WeeklyMenuPlanRead>(
      () async {
        final userId = _currentUserId;
        if (userId == null) {
          throw StateError('No authenticated user for readWeek');
        }
        final saved = await _repository.fetchForWeek(
          userId: userId,
          weekStart: weekStart,
        );
        return WeeklyMenuPlanRead(
          plan: saved ?? WeeklyMenuPlan.empty(userId: userId, date: weekStart),
          readFailed: false,
        );
      },
      operationName: 'readWeek',
    );
    return read ??
        WeeklyMenuPlanRead(
          plan: WeeklyMenuPlan.empty(
            userId: _currentUserId ?? 'anonymous',
            date: weekStart,
          ),
          readFailed: true,
        );
  }

  /// Persist [plan] (upsert by deterministic doc ID).
  ///
  /// Deliberately NOT wrapped in `executeServiceOperation`, which answers a
  /// failure with a default value. For a READ that is a usable fallback; for a
  /// write there is no default, so it made a refused save indistinguishable
  /// from a completed one and the user was told nothing at all (BUT-1962).
  ///
  /// A failure therefore propagates. Where the caller routes it through
  /// `BaseViewModel.executeAsyncVoid`, that catches and calls `setError`,
  /// which is how a Swedish error prefix reaches the screen. Not every caller
  /// does — the onboarding seed deliberately shows nothing at all — so read the
  /// call site rather than assuming this surfaces.
  ///
  /// Note what this does NOT cover: with `persistenceEnabled: true` an offline
  /// write does not throw — it applies locally and the future stays pending
  /// until the server acks. So this path sees refusals and faults, not
  /// offline. Offline has two open tickets: BUT-1965 for the generated-week
  /// write, and BUT-1975 for the calendar sitting in a permanent loading state
  /// because this future never completes.
  Future<void> save(WeeklyMenuPlan plan) async => _repository.save(plan);

  /// BUT-996: copy every entry from [fromWeekStart] into [toWeekStart].
  ///
  /// Additive, not destructive — entries already on the destination week
  /// are preserved. Matches the user mental model "use last week as a
  /// starting point, then tweak", and means a misclick can't wipe a
  /// half-built menu the user already started for next week.
  ///
  /// Duplicate detection: an entry is skipped if the destination already
  /// has an entry with the same (day, slot, recipeId) triple. Lets the
  /// caller invoke copyWeek twice safely without inflating the plan with
  /// dupes.
  ///
  /// Each copied entry gets a fresh UUID via `WeeklyMenuPlanEntry.create`
  /// so the two weeks share recipes-by-id but never share an entry-id.
  ///
  /// Returns the count of entries actually copied. Throws if either read
  /// THROWS (BUT-1972) — the caller must be able to tell that from a returned
  /// 0, which means "there was nothing to copy". A `null` read is not a throw:
  /// it still means "week absent", which offline is a true absence
  /// (BUT-1961's `acceptCachedAbsence`) and returns 0.
  ///
  /// Signed out throws too (BUT-1993), for the same reason: returning 0 there
  /// spent the caller's "nothing to copy" answer on a week nobody read, and
  /// the view rendered it as "allt finns redan nästa vecka".
  Future<int> copyWeek({
    required DateTime fromWeekStart,
    required DateTime toWeekStart,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user for copyWeek');
    }
    final normalizedFrom = IsoWeekUtils.weekStartOf(fromWeekStart);
    final normalizedTo = IsoWeekUtils.weekStartOf(toWeekStart);
    if (normalizedFrom == normalizedTo) return 0;

    // BUT-1972: the two reads sit OUTSIDE the wrapper, for the same reason the
    // save was moved out in BUT-1962. Inside it, a throwing read came back as
    // `null`, `copyWeek` returned 0, and the view rendered that as "everything
    // was already there" — the user was told a copy succeeded that never read
    // the week. A throw now reaches the caller, which shows an error instead.
    //
    // A `null` from either read is a different answer and still means what it
    // says: the week is absent. `fetchForWeek` passes `acceptCachedAbsence`, so
    // offline that is a TRUE "nothing to copy" (BUT-1961) and must keep its
    // success message.
    final source = await _repository.fetchForWeek(
      userId: userId,
      weekStart: normalizedFrom,
    );
    if (source == null) return 0;
    // Presence can be set BEFORE a menu is generated, so a source week with no
    // entries but explicit presence must still carry that presence forward.
    //
    // This check must stay BEFORE the destination read. Two reasons, and the
    // second is the one that bites: it saves a Firestore read on every
    // "nothing to copy" tap, and — since a read that throws now reaches the
    // caller — reading the destination first would turn a cleared source week
    // into an ERROR when the destination read fails, where "Inget kopierades"
    // is the true answer. That is the inverse of the defect BUT-1972 fixes.
    if (source.entries.isEmpty && source.presenceBySlot.isEmpty) return 0;

    final destFetched = await _repository.fetchForWeek(
      userId: userId,
      weekStart: normalizedTo,
    );

    var dest =
        destFetched ?? WeeklyMenuPlan.empty(userId: userId, date: normalizedTo);

    final newEntries = <WeeklyMenuPlanEntry>[];
    for (final src in source.entries) {
      final duplicate = dest.entries.any(
        (e) =>
            e.day == src.day &&
            e.slot == src.slot &&
            e.recipeId == src.recipeId,
      );
      if (duplicate) continue;
      newEntries.add(
        WeeklyMenuPlanEntry.create(
          day: src.day,
          slot: src.slot,
          recipeId: src.recipeId,
          recipeTitle: src.recipeTitle,
          recipeImageUrl: src.recipeImageUrl,
        ),
      );
    }

    // BUT-1611: presence travels with the week. The destination keeps any
    // explicit selection it already had; the source only fills empty slots.
    final (mergedPresence, presenceAdded) = _mergePresenceForward(
      dest.presenceBySlot,
      source.presenceBySlot,
    );

    if (newEntries.isEmpty && !presenceAdded) return 0;

    dest = dest.copyWith(
      entries: [...dest.entries, ...newEntries],
      presenceBySlot: mergedPresence,
    );
    // Every step above is now outside `executeServiceOperation`. Nothing
    // between the two reads and this save can fail in a way the caller should
    // not hear about: the reads were hoisted out by BUT-1972, the save by
    // BUT-1962, and what is left in between is pure computation over values
    // already in hand. A wrapper here would only be able to swallow.
    await _repository.save(dest);
    return newEntries.length;
  }

  /// Deep-merges [source] presence into [dest], with dest winning on any
  /// (day, slot) it already holds. Returns the merged map and whether any
  /// source slot was actually copied in.
  static (Map<DayOfWeek, Map<MealSlot, List<String>>>, bool)
  _mergePresenceForward(
    Map<DayOfWeek, Map<MealSlot, List<String>>> dest,
    Map<DayOfWeek, Map<MealSlot, List<String>>> source,
  ) {
    final merged = {
      for (final entry in dest.entries)
        entry.key: {
          for (final slot in entry.value.entries)
            slot.key: List<String>.unmodifiable(slot.value),
        },
    };
    var added = false;
    source.forEach((day, bySlot) {
      final target = merged.putIfAbsent(day, () => <MealSlot, List<String>>{});
      bySlot.forEach((slot, memberIds) {
        if (target.containsKey(slot)) return; // dest wins
        target[slot] = List<String>.unmodifiable(memberIds);
        added = true;
      });
    });
    return (merged, added);
  }

  /// BUT-1043: move multiple entries to the same (toDay, toSlot) in one
  /// persisted write. Loops the in-memory [moveEntry] primitive over
  /// [entryIds] against a single loaded plan, then saves once — never one
  /// write per entry.
  ///
  /// Entry ids that aren't present on the loaded plan are skipped (a stale
  /// selection — e.g. an entry deleted by a parallel edit — must not abort
  /// the whole move). Returns the number of entries actually moved; 0 short-
  /// circuits without touching the repository.
  ///
  /// Single-slot swap semantics from [moveEntry] still apply per entry, so
  /// moving several entries onto one lunch/middag cell behaves like repeated
  /// drops: the last one wins the cell and earlier occupants get shuffled to
  /// the moved entries' vacated cells. The realistic caller (bulk-move to
  /// övrigt, or to a free cell) avoids that; the contract is documented for
  /// completeness.
  Future<int> bulkMoveEntries({
    required DateTime weekStart,
    required List<String> entryIds,
    required DayOfWeek toDay,
    required MealSlot toSlot,
  }) async {
    if (entryIds.isEmpty) return 0;
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user for bulkMoveEntries');
    }
    var plan = await _loadPlanForWrite(userId: userId, weekStart: weekStart);

    var moved = 0;
    for (final entryId in entryIds) {
      if (!plan.entries.any((e) => e.id == entryId)) continue;
      final updated = moveEntry(
        plan: plan,
        entryId: entryId,
        toDay: toDay,
        toSlot: toSlot,
      );
      if (identical(updated, plan)) continue; // self-drop no-op
      plan = updated;
      moved++;
    }
    if (moved > 0) await _repository.save(plan);
    return moved;
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
  /// [now] is injected for testability — defaults to the ambient clock.
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
    final anchorIndex = anchorIsToday
        ? DayOfWeek.fromDateTime(evaluationTime).index
        : 0;

    final base =
        existing ??
        WeeklyMenuPlan.empty(userId: userId, date: normalizedWeekStart);
    final mutableEntries = List<WeeklyMenuPlanEntry>.from(base.entries);
    final overflow = <Recipe>[];
    final overflowMealTypes = <String, String>{};

    // Day pins (e.g. tacofredag) land first — they claim their weekday
    // before the generic chronological fill. Pinned recipes come from the
    // generated map; the pin's tag is matched against recipe tags.
    final pinnedRecipeIds = <String>{};
    for (final pin in dayPins) {
      final slotKey = pin.mealType;
      final recipes = generated[slotKey];
      if (recipes == null) continue;
      final match = recipes
          .where(
            (r) =>
                !pinnedRecipeIds.contains(r.id) &&
                (pin.constraint.requiredTags.isEmpty ||
                    (r.tagResult?.hasAllTags(pin.constraint.requiredTags) ??
                        false)),
          )
          .firstOrNull;
      if (match == null) continue;
      // weekdayIndex is 1-based (Mon=1), DayOfWeek is 0-based index.
      final dayIdx = (pin.weekdayIndex - 1).clamp(0, DayOfWeek.sun.index);
      // BUT-1668: a pin must respect the today-anchor. Pinning "tacofredag"
      // on a Saturday would place a recipe on a day that already passed, so
      // skip the pin and let the recipe fall through to the chronological
      // fill. anchorIndex is 0 for any non-current week, so future weeks are
      // unaffected.
      if (dayIdx < anchorIndex) continue;
      final day = DayOfWeek.values[dayIdx];
      final slot = mapMealTypeToSlot(slotKey);
      // BUT-1241: a pin must not double-stack an occupied single slot
      // (e.g. the user already hand-placed Friday middag in the manual
      // placement flow). Skip the pin and let the recipe fall through to
      // the chronological fill instead.
      if (!slot.isMulti &&
          mutableEntries.any((e) => e.day == day && e.slot == slot)) {
        continue;
      }
      pinnedRecipeIds.add(match.id);
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
            overflowMealTypes[recipe.id] = entry.key;
            continue;
          }
          mutableEntries.add(
            _entryFor(
              day: DayOfWeek.values[dayCursor],
              slot: slot,
              recipe: recipe,
            ),
          );
          dayCursor += 1;
        }
      } else {
        // Lunch / middag — fill empty cells chronologically from anchor.
        for (final recipe in recipes) {
          if (pinnedRecipeIds.contains(recipe.id)) continue;
          DayOfWeek? targetDay;
          for (var i = anchorIndex; i <= DayOfWeek.sun.index; i++) {
            final candidate = DayOfWeek.values[i];
            final occupied = mutableEntries.any(
              (e) => e.day == candidate && e.slot == slot,
            );
            if (!occupied) {
              targetDay = candidate;
              break;
            }
          }
          if (targetDay == null) {
            overflow.add(recipe);
            overflowMealTypes[recipe.id] = entry.key;
            continue;
          }
          mutableEntries.add(
            _entryFor(
              day: targetDay,
              slot: slot,
              recipe: recipe,
            ),
          );
        }
      }
    }

    final newPlan = base.copyWith(entries: mutableEntries);
    return WeeklyMenuDistributionResult(
      plan: newPlan,
      overflow: overflow,
      overflowMealTypes: overflowMealTypes,
      overflowReason: overflow.isEmpty
          ? null
          : WeeklyMenuOverflowReason(
              weekStart: normalizedWeekStart,
              pastDaysSkipped: anchorIndex > 0,
            ),
    );
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
    var plan = await _loadPlanForWrite(userId: userId, weekStart: weekStart);

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
    if (added > 0) await _repository.save(plan);
    return (added: added, overflowed: overflowed);
  }

  /// BUT-999: place ONE recipe on multiple (day, slot) targets within the
  /// same week — the inverse of [bulkAssignRecipes] (N recipes → one start
  /// cell). All targets are applied in memory and persisted with a SINGLE
  /// batched save, never one write per target.
  ///
  /// Placement follows [addEntry] semantics per target: single-slot targets
  /// (lunch/middag) replace any existing occupant — the user explicitly
  /// tapped that cell in the picker, so replacement is deliberate — while
  /// övrigt targets append. Duplicate targets are applied once.
  ///
  /// Returns the number of targets actually placed (0 short-circuits
  /// without touching the repository).
  Future<int> assignRecipeToTargets({
    required DateTime weekStart,
    required Recipe recipe,
    required List<SlotTarget> targets,
  }) async {
    if (targets.isEmpty) return 0;
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('No authenticated user for assignRecipeToTargets');
    }
    var plan = await _loadPlanForWrite(userId: userId, weekStart: weekStart);

    // toSet() dedupes record-equal targets, preserving first-seen order.
    final unique = targets.toSet();
    for (final target in unique) {
      plan = addEntry(
        plan: plan,
        day: target.day,
        slot: target.slot,
        recipe: recipe,
      );
    }
    await _repository.save(plan);
    return unique.length;
  }

  /// BUT-1988: the presence merge, applied to a plan the CALLER already holds.
  /// The viewmodel publishes presence optimistically and
  /// must not re-implement the merge — two copies of the "no selection =
  /// everyone" invariant drift apart.
  static WeeklyMenuPlan withPresence({
    required WeeklyMenuPlan plan,
    required DayOfWeek day,
    required List<MealSlot> slots,
    required List<String>? memberIds,
  }) {
    var presence = plan.presenceBySlot;
    for (final slot in slots) {
      presence = _withSlotPresence(presence, day, slot, memberIds);
    }
    return plan.copyWith(presenceBySlot: presence);
  }

  /// Returns a copy of [presence] with [day]/[slot] set to [memberIds] (null
  /// removes the slot's explicit selection). Prunes a day whose inner map is
  /// left empty, so the "no selection = everyone" invariant round-trips.
  static Map<DayOfWeek, Map<MealSlot, List<String>>> _withSlotPresence(
    Map<DayOfWeek, Map<MealSlot, List<String>>> presence,
    DayOfWeek day,
    MealSlot slot,
    List<String>? memberIds,
  ) {
    final result = {
      for (final entry in presence.entries)
        entry.key: Map<MealSlot, List<String>>.from(entry.value),
    };
    final slots = result.putIfAbsent(day, () => <MealSlot, List<String>>{});
    if (memberIds == null) {
      slots.remove(slot);
    } else {
      slots[slot] = List.unmodifiable(memberIds);
    }
    if (slots.isEmpty) result.remove(day);
    return result;
  }

  /// Shared write-path loader: fetch the week's plan or start from an empty
  /// one. Normalizes [weekStart] to Monday.
  Future<WeeklyMenuPlan> _loadPlanForWrite({
    required String userId,
    required DateTime weekStart,
  }) async {
    final normalizedWeekStart = IsoWeekUtils.weekStartOf(weekStart);
    final fetched = await _repository.fetchForWeek(
      userId: userId,
      weekStart: normalizedWeekStart,
    );
    return fetched ??
        WeeklyMenuPlan.empty(userId: userId, date: normalizedWeekStart);
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

  /// Restore [entries] onto [plan], replacing whatever is there now.
  /// Used by the undo path after clearWeek: the VM snapshots the pre-clear
  /// entries list and passes it here if the user taps "Ångra" within 7 s.
  WeeklyMenuPlan restoreWeek(
    WeeklyMenuPlan plan,
    List<WeeklyMenuPlanEntry> entries,
  ) {
    return plan.copyWith(entries: entries);
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
