import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/shopping_store.dart';

/// "Move [first] to just before [second]" in a store's category order.
class StoreOrderSuggestion {
  final String first;
  final String second;

  const StoreOrderSuggestion({required this.first, required this.second});
}

/// Learns, on the phone only, which category the user ticks before which in a
/// store, and turns a steady habit into one [StoreOrderSuggestion].
///
/// Only pair counts per store are kept: no item, time, list or visit is
/// written. The ticks of the visit in progress live in memory only.
class StoreOrderLearner {
  StoreOrderLearner(this._preferences);

  /// Cleared at sign-out (`LocalUserDataRegistry`): it describes one person's
  /// shopping habits.
  static const String storageKey = 'store_order_pairs_v1';

  /// A pair must have been ticked in this order this many times.
  static const int minTicks = 5;

  /// And at least this many times as often as the opposite order.
  static const int dominance = 2;

  static const int maxStores = ShoppingStore.maxStores;

  final SharedPreferences? _preferences;

  String? _loadedFor;
  final Map<String, Map<String, int>> _pairs = {};

  String? _visitKey;
  final Set<String> _visit = {};

  /// Reads what this device holds for [userId]. What another account left is
  /// dropped, so it is never read or kept.
  void load(String userId) {
    // The key is gone (a sign-out cleared it): counts held in memory must not
    // write themselves back.
    if (_loadedFor == userId &&
        _preferences != null &&
        _preferences.getString(storageKey) == null) {
      _pairs.clear();
    }
    if (_loadedFor == userId) return;
    _loadedFor = userId;
    _pairs.clear();
    try {
      final raw = _preferences?.getString(storageKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['owner'] != userId) {
        unawaited(_preferences?.remove(storageKey).catchError((_) => false));
        return;
      }
      final stores = decoded['stores'] as Map<String, dynamic>;
      for (final entry in stores.entries) {
        _pairs[entry.key] = {
          for (final pair in (entry.value as Map<String, dynamic>).entries)
            if (pair.value is int && (pair.value as int) > 0)
              pair.key: pair.value as int,
        };
      }
    } catch (e) {
      AppLogger.warning('StoreOrderLearner: could not read (${e.runtimeType})');
      _pairs.clear();
    }
  }

  /// Forgets the visit in progress.
  void endVisit() {
    _visitKey = null;
    _visit.clear();
  }

  /// Counts that [category] was ticked after every category already ticked in
  /// this visit. A second tick in a category adds nothing.
  Future<void> recordTick({
    required String userId,
    required String storeId,
    required String listId,
    required String category,
  }) async {
    load(userId);
    final key = '$storeId|$listId';
    if (key != _visitKey) {
      _visitKey = key;
      _visit.clear();
    }
    if (!_visit.add(category)) return;
    final counts = _pairs.putIfAbsent(storeId, () => {});
    for (final earlier in _visit) {
      if (earlier == category) continue;
      final pair = _pairKey(earlier, category);
      counts[pair] = (counts[pair] ?? 0) + 1;
    }
    await _save(userId);
  }

  /// The strongest habit in [storeId] that [order] does not follow, or null.
  StoreOrderSuggestion? suggestionFor(String storeId, List<String> order) {
    final counts = _pairs[storeId];
    if (counts == null) return null;
    StoreOrderSuggestion? best;
    var bestCount = 0;
    for (final entry in counts.entries) {
      final n = entry.value;
      if (n < minTicks || n <= bestCount) continue;
      final parts = entry.key.split('>');
      final first = parts.first;
      final second = parts.last;
      final firstAt = order.indexOf(first);
      final secondAt = order.indexOf(second);
      if (firstAt < 0 || secondAt < 0 || firstAt < secondAt) continue;
      final opposite = counts[_pairKey(second, first)] ?? 0;
      if (n < dominance * opposite) continue;
      best = StoreOrderSuggestion(first: first, second: second);
      bestCount = n;
    }
    return best;
  }

  /// Forgets both directions of the pair, after the user answered it.
  Future<void> forgetPair(
    String userId,
    String storeId,
    StoreOrderSuggestion suggestion,
  ) async {
    load(userId);
    final counts = _pairs[storeId];
    if (counts == null) return;
    counts.remove(_pairKey(suggestion.first, suggestion.second));
    counts.remove(_pairKey(suggestion.second, suggestion.first));
    await _save(userId);
  }

  /// Forgets everything learned for a store the user removed.
  Future<void> forgetStore(String userId, String storeId) async {
    load(userId);
    if (_pairs.remove(storeId) == null) return;
    await _save(userId);
  }

  String _pairKey(String first, String second) => '$first>$second';

  Future<void> _save(String userId) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      _pairs.removeWhere((_, counts) => counts.isEmpty);
      // A store removed on another device is never forgotten here, so the
      // oldest are dropped past the number of stores a user can have.
      while (_pairs.length > maxStores) {
        _pairs.remove(_pairs.keys.first);
      }
      await preferences.setString(
        storageKey,
        jsonEncode({'owner': userId, 'stores': _pairs}),
      );
    } catch (e) {
      AppLogger.warning('StoreOrderLearner: could not save (${e.runtimeType})');
    }
  }
}
