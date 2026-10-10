// lib/viewmodels/menu/weekly_allergen_marks.dart

import 'dart:async';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';

/// BUT-2362: which dishes on the week on screen someone eating that meal
/// cannot eat. Kept for every week whether or not the per-meal choice is on,
/// so a dish added by hand, or a change to who is home after placement, is
/// marked whatever path put it there.
///
/// Never persisted or logged: the marks hold nothing but entry ids.
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
  String? _pendingKey;
  int _loads = 0;
  Set<String> _unsafe = const {};
  bool _disposed = false;

  bool isUnsafe(String entryId) => _unsafe.contains(entryId);

  /// Re-reads the scope on the next [refresh] even if the week is unchanged,
  /// for when someone's allergens may have changed.
  void invalidate() {
    _scopeKey = null;
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
      return;
    }
    final key = _keyFor(plan);
    if (key != _scopeKey && key != _pendingKey) {
      _pendingKey = key;
      final interim = _scope;
      if (interim != null && interim.isScoped) {
        _scope = MealAllergenScope(household: interim.household);
      }
      unawaited(_load(plan, key, ++_loads));
    }
    _unsafe = _scope?.unsafeEntryIds(plan, _recipeFor) ?? const {};
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
    _pendingKey = null;
    _onChanged();
  }

  void dispose() => _disposed = true;

  /// The week, who is away at each meal and whether the per-meal choice is
  /// on: everything the scope depends on that this side can see.
  String _keyFor(WeeklyMenuPlan plan) {
    final buffer = StringBuffer('${plan.id}|${_scopeOn()}');
    for (final day in DayOfWeek.values) {
      for (final slot in kPresenceSlots) {
        final away = plan.allergenAwayIdsFor(day, slot).toList()..sort();
        if (away.isEmpty) continue;
        buffer.write('|${day.name}.${slot.name}:${away.join(',')}');
      }
    }
    return buffer.toString();
  }
}
