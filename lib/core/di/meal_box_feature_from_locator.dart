/// The meal-box surfaces' switch and analytics (BUT-2486 part 5), looked up
/// here so view models and widgets share them.
library;

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';

/// Whether the meal-box surfaces exist at all. Off means no read of the boxes
/// and no block, sheet part or lunch row.
bool mealBoxesEnabled() {
  try {
    return ServiceLocator.tryGet<FeatureFlagService>()?.isEnabled(
          FeatureFlags.enableMealBoxes,
        ) ??
        false;
  } catch (_) {
    return false;
  }
}

/// Best-effort: analytics checks consent itself and never costs the user an
/// action.
void logMealBoxEvent(String name, {Map<String, Object>? parameters}) {
  try {
    final analytics = ServiceLocator.tryGet<AnalyticsService>();
    analytics?.logEvent(name: name, parameters: parameters).catchError((
      Object e,
    ) {
      AppLogger.debug('Meal box analytics failed: $e');
    });
  } catch (e) {
    AppLogger.debug('Meal box analytics failed: $e');
  }
}
