// lib/services/shopping/week_list_follower.dart

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';

/// Runs [sync] for a week once its saves have paused for [pause], so that a
/// burst of edits to the week menu becomes one write to the week's list, and
/// two syncs of the same week never run at once.
class WeekListFollower {
  WeekListFollower({
    required Stream<DateTime> savedWeeks,
    required this.sync,
    this.pause = defaultPause,
  }) {
    _subscription = savedWeeks.listen(_onSaved);
  }

  static const Duration defaultPause = Duration(seconds: 2);

  final Future<void> Function(DateTime week) sync;
  final Duration pause;

  late final StreamSubscription<DateTime> _subscription;
  final Map<String, Timer> _timers = {};
  final Map<String, Future<void>> _running = {};
  var _disposed = false;

  void _onSaved(DateTime week) {
    final key = IsoWeekUtils.weekKeyOf(week);
    _timers.remove(key)?.cancel();
    _timers[key] = Timer(pause, () {
      _timers.remove(key);
      _running[key] = (_running[key] ?? Future<void>.value()).then(
        (_) => _run(week),
      );
    });
  }

  Future<void> _run(DateTime week) async {
    if (_disposed) return;
    try {
      await sync(week);
    } catch (e) {
      AppLogger.warning(
        'The shopping list of week ${IsoWeekUtils.weekKeyOf(week)} could not '
            'follow the menu: $e',
        'WeekListFollower',
      );
    }
  }

  /// Waits for every sync that has already started. For tests and dispose.
  Future<void> idle() => Future.wait(_running.values);

  Future<void> dispose() async {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    await _subscription.cancel();
  }
}

/// The rules the user last confirmed in the merge sheet, kept on the device
/// so a follow made later, after a restart too, uses the same ones.
class MenuShoppingOptionsMemory {
  MenuShoppingOptionsMemory(this._preferences);

  static const String _key = 'menu_shopping_last_options';

  /// Null where no device storage is wired: nothing is remembered and the
  /// sheet's drawn defaults are read.
  final SharedPreferences? _preferences;

  MenuShoppingMergeOptions read() {
    final flags = _preferences?.getString(_key)?.split('|');
    if (flags == null || flags.length != 3) {
      return const MenuShoppingMergeOptions();
    }
    return MenuShoppingMergeOptions(
      mergeDuplicates: flags[0] == '1',
      convertUnits: flags[1] == '1',
      subtractPantry: flags[2] == '1',
    );
  }

  Future<void> write(MenuShoppingMergeOptions options) async {
    String flag(bool on) => on ? '1' : '0';
    try {
      await _preferences?.setString(
        _key,
        [
          flag(options.mergeDuplicates),
          flag(options.convertUnits),
          flag(options.subtractPantry),
        ].join('|'),
      );
    } catch (e) {
      AppLogger.warning(
        'Could not remember the shopping merge rules: $e',
        'MenuShoppingOptionsMemory',
      );
    }
  }
}
