// lib/viewmodels/menu/weekly_allergen_marks.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';

/// What the calendar says about one day's lunchbox (BUT-2486).
enum LunchboxVerdict {
  /// Judged, and everyone taking the box can eat it.
  safe,

  /// Someone taking the box cannot eat it.
  unsafe,

  /// Not judged: no dish, a dish missing from the library, or no allergen
  /// answer for the box's takers yet. Never drawn as safe.
  unjudged,
}

/// BUT-2362: which dishes on the week on screen someone eating that meal
/// cannot eat. Kept for every week whether or not the per-meal choice is on,
/// so a dish added by hand, or a change to who is home after placement, is
/// marked whatever path put it there.
///
/// Never persisted or logged: the marks hold nothing but entry ids and days.
class WeeklyAllergenMarks {
  WeeklyAllergenMarks({
    required Future<MealAllergenScope> Function(WeeklyMenuPlan plan) resolve,
    required Recipe? Function(String recipeId) recipeFor,
    required void Function() onChanged,
    required bool Function() scopeOn,
  }) : _resolve = resolve,
       _recipeFor = recipeFor,
       _onChanged = onChanged,
       _scopeOn = scopeOn;

  final Future<MealAllergenScope> Function(WeeklyMenuPlan plan) _resolve;
  final Recipe? Function(String recipeId) _recipeFor;
  final void Function() _onChanged;
  final bool Function() _scopeOn;

  MealAllergenScope? _scope;
  String? _scopeKey;

  /// The key [_scope] was read for. A box is judged only by a scope read for
  /// the week as it is now: an older scope may name other takers, and a
  /// failed read leaves no answer at all.
  String? _resolvedKey;
  String? _pendingKey;
  int _loads = 0;
  Set<String> _unsafe = const {};
  Set<DayOfWeek> _unsafeBoxes = const {};
  Set<DayOfWeek> _unjudgedBoxes = const {};
  bool _disposed = false;

  bool isUnsafe(String entryId) => _unsafe.contains(entryId);

  /// The verdict on [day]'s lunchbox, or null when the day has none.
  LunchboxVerdict? lunchboxVerdict(WeeklyMenuPlan? plan, DayOfWeek day) {
    if (plan?.lunchboxes[day] == null) return null;
    if (_unsafeBoxes.contains(day)) return LunchboxVerdict.unsafe;
    if (_unjudgedBoxes.contains(day)) return LunchboxVerdict.unjudged;
    return LunchboxVerdict.safe;
  }

  /// Re-reads the scope on the next [refresh] even if the week is unchanged,
  /// for when someone's allergens may have changed.
  void invalidate() {
    _scopeKey = null;
    _resolvedKey = null;
    _pendingKey = null;
    _loads++;
  }

  /// Brings the marks up to date with [plan]. Synchronous when the week and
  /// who is home are as last resolved; otherwise the scope is read again and
  /// [onChanged] fires when it arrives. Until then a meal that followed fewer
  /// people is judged for the whole household.
  void refresh(WeeklyMenuPlan? plan) {
    if (_disposed) return;
    if (plan == null) {
      _unsafe = const {};
      _unsafeBoxes = const {};
      _unjudgedBoxes = const {};
      return;
    }
    final key = _keyFor(plan);
    if (key != _scopeKey && key != _pendingKey) {
      _pendingKey = key;
      // The scope kept below no longer answers for the boxes of any week,
      // not even this key's if the week comes back before the read lands.
      _resolvedKey = null;
      final interim = _scope;
      if (interim != null && interim.isScoped) {
        _scope = MealAllergenScope(household: interim.household);
      }
      unawaited(_load(plan, key, ++_loads));
    }
    _unsafe = _scope?.unsafeEntryIds(plan, _recipeFor) ?? const {};
    final scope = _scope;
    if (scope != null && _resolvedKey == key) {
      final verdicts = scope.lunchboxVerdicts(plan, _recipeFor);
      _unsafeBoxes = verdicts.unsafe;
      _unjudgedBoxes = verdicts.unjudged;
    } else {
      _unsafeBoxes = const {};
      _unjudgedBoxes = plan.lunchboxes.keys.toSet();
    }
  }

  Future<void> _load(WeeklyMenuPlan plan, String key, int load) async {
    MealAllergenScope scope;
    try {
      scope = await _resolve(plan);
    } catch (e) {
      AppLogger.warning('Allergen marks unreadable (${e.runtimeType})');
      // Not retried until [invalidate]: refresh runs on every notify, and a
      // retry there would re-read on every rebuild while the read fails.
      if (_disposed || load != _loads) return;
      _pendingKey = null;
      _scopeKey = key;
      return;
    }
    if (_disposed || load != _loads) return;
    _scope = scope;
    _scopeKey = key;
    _resolvedKey = key;
    _pendingKey = null;
    _onChanged();
  }

  void dispose() => _disposed = true;

  /// The week, who is away at each meal, each lunchbox and whether the
  /// per-meal choice is on: everything the scope depends on that this side
  /// can see.
  @visibleForTesting
  static String keyFor(WeeklyMenuPlan plan, {required bool scopeOn}) {
    final buffer = StringBuffer('${plan.id}|$scopeOn');
    for (final day in DayOfWeek.values) {
      for (final slot in kPresenceSlots) {
        final away = plan.allergenAwayIdsFor(day, slot).toList()..sort();
        if (away.isEmpty) continue;
        buffer.write('|${day.name}.${slot.name}:${away.join(',')}');
      }
    }
    for (final day in DayOfWeek.values) {
      final box = plan.lunchboxes[day];
      if (box == null) continue;
      final takers = box.takerIds.toSet().toList()..sort();
      buffer.write(
        '|box.${day.name}:${box.source.name}:'
        '${box.recipeIdIn(plan).orEmpty()}:${takers.join(',')}',
      );
    }
    return buffer.toString();
  }

  String _keyFor(WeeklyMenuPlan plan) => keyFor(plan, scopeOn: _scopeOn());
}
