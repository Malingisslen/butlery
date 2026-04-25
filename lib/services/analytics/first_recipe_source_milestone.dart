import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics_service.dart';

/// Sets the once-per-user `first_recipe_source` analytics user property
/// (BUT-618). Mirrors the SharedPreferences-flag dedupe pattern from A1's
/// `logFirstShareIfMilestone` so the property survives restarts and doesn't
/// cost a Firestore write.
///
/// Source values: `'import'` | `'manual'` | `'seed'` — determined by the
/// caller, since only the call site knows the upstream provenance.
class FirstRecipeSourceMilestone {
  static const String _prefsPrefix = 'first_recipe_source_v1_';

  /// Sets `first_recipe_source` user property exactly once per user.
  ///
  /// Returns true if the property was set on this call, false if skipped
  /// (already set, no userId, or SharedPreferences unavailable).
  static Future<bool> setIfFirstRecipe({
    required AnalyticsService? analytics,
    required String? userId,
    required String source,
  }) async {
    if (analytics == null) return false;
    if (userId == null || userId.isEmpty) return false;

    final prefs = await _tryGetPrefs();
    if (prefs == null) return false;

    final key = '$_prefsPrefix$userId';
    if (prefs.getBool(key) == true) return false;

    await analytics.setUserProperty(
      name: 'first_recipe_source',
      value: source,
    );
    await prefs.setBool(key, true);
    return true;
  }

  static Future<SharedPreferences?> _tryGetPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.warning(
        'first_recipe_source milestone: SharedPreferences unavailable ($e); skipping',
      );
      return null;
    }
  }
}
