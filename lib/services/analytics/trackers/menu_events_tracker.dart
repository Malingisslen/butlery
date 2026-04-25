import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks menu-related analytics events
class MenuEventsTracker extends BaseTracker {
  MenuEventsTracker({required super.repository});

  /// Per-install dedupe key for the once-per-user `first_meal_plan` milestone.
  /// Suffixed with the user uid so household devices don't cross-fire.
  static const String _firstMealPlanPrefsPrefix = 'menu_activated_v1_';

  /// Log menu generation
  Future<void> logMenuGenerated({
    required int recipeCount,
    required String method,
  }) async {
    if (!await hasAnalyticsConsent()) return;
    await repository.logMenuGenerated(recipeCount: recipeCount, method: method);
  }

  /// Log menu generation started
  Future<void> logMenuGenerationStarted({int? promptLength}) async {
    await logEvent(
      name: 'menu_generation_started',
      parameters: {if (promptLength != null) 'prompt_length': promptLength},
    );
  }

  /// Log menu generation failed (exempt from consent - error tracking)
  Future<void> logMenuGenerationFailed({
    required String errorCode,
    String? errorMessage,
  }) async {
    await logEvent(
      name: 'menu_generation_failed',
      parameters: {
        'error_code': errorCode,
        if (errorMessage != null) 'error_message': errorMessage,
      },
    );
  }

  /// Log menu saved
  Future<void> logMenuSaved({
    required String menuId,
    required int recipeCount,
    bool isShared = false,
  }) async {
    await logEvent(
      name: 'menu_saved',
      parameters: {
        'menu_id': menuId,
        'recipe_count': recipeCount,
        'is_shared': isShared,
      },
    );
  }

  /// Once-per-user `first_meal_plan` milestone (BUT-576). Dedupes via a
  /// SharedPreferences flag keyed by uid — survives app restarts, no Firestore
  /// write. If [joinedAt] is null we omit `minutes_since_signup` rather than
  /// emit a guessed value.
  ///
  /// Returns true if the milestone fired, false if skipped (already activated,
  /// no consent, or no userId).
  Future<bool> logFirstMealPlanIfMilestone({
    required String? userId,
    required int recipeCountInPlan,
    DateTime? joinedAt,
  }) async {
    if (userId == null || userId.isEmpty) return false;
    if (!await hasAnalyticsConsent()) return false;

    final prefs = await _tryGetPrefs();
    if (prefs == null) return false;

    final key = '$_firstMealPlanPrefsPrefix$userId';
    if (prefs.getBool(key) == true) return false;

    final params = <String, Object>{
      'recipe_count_in_plan': recipeCountInPlan,
    };
    if (joinedAt != null) {
      params['minutes_since_signup'] =
          DateTime.now().difference(joinedAt).inMinutes;
    }

    await repository.logEvent(name: 'first_meal_plan', parameters: params);
    await repository.setUserProperty(name: 'menu_activated', value: 'true');
    await prefs.setBool(key, true);
    return true;
  }

  Future<SharedPreferences?> _tryGetPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.warning(
        'first_meal_plan milestone: SharedPreferences unavailable ($e); skipping',
      );
      return null;
    }
  }

  /// Log menu loaded
  Future<void> logMenuLoaded({
    required String menuId,
    bool isOwned = true,
  }) async {
    await logEvent(
      name: 'menu_loaded',
      parameters: {'menu_id': menuId, 'is_owned': isOwned},
    );
  }

  /// Log menu shared
  Future<void> logMenuShared({
    required String menuId,
    required int recipientCount,
    String? shareMethod,
  }) async {
    await logEvent(
      name: 'menu_shared',
      parameters: {
        'menu_id': menuId,
        'recipient_count': recipientCount,
        if (shareMethod != null) 'share_method': shareMethod,
      },
    );
  }

  /// Log menu deleted
  Future<void> logMenuDeleted({required String menuId, String? reason}) async {
    await logEvent(
      name: 'menu_deleted',
      parameters: {'menu_id': menuId, if (reason != null) 'reason': reason},
    );
  }
}
