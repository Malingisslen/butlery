import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';

/// Which weekdays need a lunchbox when the week is suggested (BUT-2486
/// part 6), kept on this device only so last week's choice is there next
/// week without a cloud field or a policy line. Keyed by the account, so
/// another account on the same phone reads nothing; cleared by
/// `LocalUserDataRegistry` on sign-out. Never throws.
class LunchboxDaysStore {
  const LunchboxDaysStore();

  static const String keyPrefix = 'menu_lunchbox_days_v1_';

  static String _key(String userId) => '$keyPrefix$userId';

  Future<Set<DayOfWeek>> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final names = prefs.getStringList(_key(userId)) ?? const <String>[];
      return {
        for (final day in DayOfWeek.values)
          if (names.contains(day.name)) day,
      };
    } catch (e) {
      AppLogger.warning('LunchboxDaysStore: read failed ($e)');
      return <DayOfWeek>{};
    }
  }

  Future<void> write(String userId, Set<DayOfWeek> days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(userId), [
        for (final day in DayOfWeek.values)
          if (days.contains(day)) day.name,
      ]);
    } catch (e) {
      AppLogger.warning('LunchboxDaysStore: write failed ($e)');
    }
  }

  /// Every account's choice on this device.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith(keyPrefix))) {
        await prefs.remove(key);
      }
    } catch (e) {
      AppLogger.warning('LunchboxDaysStore: clear failed ($e)');
    }
  }
}
