import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';

/// The shopping-list reminders this person has dismissed ("Inte aktuellt"),
/// kept on this device only (BUT-2494).
///
/// Health-adjacent: an entry says which choice applies to which row, so it is
/// never written to the row or the list, where other members would read it.
/// It holds no timestamps, is keyed by the account so another account on the
/// same phone reads nothing, and [keyPrefix] is cleared by
/// `LocalUserDataRegistry` on every sign-out, including the one an account
/// deletion ends with.
class DismissedDietaryHintsStore {
  const DismissedDietaryHintsStore();

  static const String keyPrefix = 'shopping_hint_dismissed_v1_';

  /// Upper bound on stored entries: rows come and go, and nothing else prunes
  /// entries for rows that were deleted or ticked off.
  static const int maxEntries = 500;

  static String _key(String userId) => '$keyPrefix$userId';

  static String entry(String itemId, String choiceKey) => '$itemId|$choiceKey';

  Future<Set<String>> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key(userId)) ?? const <String>[]).toSet();
    } catch (e) {
      AppLogger.warning('DismissedDietaryHintsStore: read failed ($e)');
      return <String>{};
    }
  }

  Future<void> write(String userId, Set<String> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = entries.toList();
      // Oldest first is insertion order of the Set; keep the newest.
      final kept = list.length > maxEntries
          ? list.sublist(list.length - maxEntries)
          : list;
      await prefs.setStringList(_key(userId), kept);
    } catch (e) {
      AppLogger.warning('DismissedDietaryHintsStore: write failed ($e)');
    }
  }

  /// Every account's dismissals on this device.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith(keyPrefix))) {
        await prefs.remove(key);
      }
    } catch (e) {
      AppLogger.warning('DismissedDietaryHintsStore: clear failed ($e)');
    }
  }
}
