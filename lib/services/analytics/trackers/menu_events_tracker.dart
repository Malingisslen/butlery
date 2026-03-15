import 'package:butlery/services/analytics/trackers/base_tracker.dart';

/// Tracks menu-related analytics events
class MenuEventsTracker extends BaseTracker {
  MenuEventsTracker({required super.repository});

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
