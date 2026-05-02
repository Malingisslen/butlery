import 'package:butlery/services/analytics/analytics_events.dart';
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
      name: AnalyticsEvents.menuGenerationStarted,
      parameters: {if (promptLength != null) 'prompt_length': promptLength},
    );
  }

  /// Log menu generation failed (exempt from consent - error tracking)
  Future<void> logMenuGenerationFailed({
    required String errorCode,
    String? errorMessage,
  }) async {
    await logEvent(
      name: AnalyticsEvents.menuGenerationFailed,
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
      name: AnalyticsEvents.menuSaved,
      parameters: {
        'menu_id': menuId,
        'recipe_count': recipeCount,
        'is_shared': isShared,
      },
    );
  }

  /// Once-per-user `first_meal_plan` milestone (BUT-576). Returns true if the
  /// milestone fired, false if skipped (already activated, no consent, or no
  /// userId).
  Future<bool> logFirstMealPlanIfMilestone({
    required String? userId,
    required int recipeCountInPlan,
    DateTime? joinedAt,
  }) async {
    return fireOnceMilestone(
      userId: userId,
      prefsPrefix: _firstMealPlanPrefsPrefix,
      eventName: AnalyticsEvents.firstMealPlan,
      userPropertyName: AnalyticsUserProperties.menuActivated,
      joinedAt: joinedAt,
      extraParams: {'recipe_count_in_plan': recipeCountInPlan},
    );
  }

  /// Log menu loaded
  Future<void> logMenuLoaded({
    required String menuId,
    bool isOwned = true,
  }) async {
    await logEvent(
      name: AnalyticsEvents.menuLoaded,
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
      name: AnalyticsEvents.menuShared,
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
      name: AnalyticsEvents.menuDeleted,
      parameters: {'menu_id': menuId, if (reason != null) 'reason': reason},
    );
  }
}
