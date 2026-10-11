import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

/// BUT-918: GDPR transparency, so users see exactly what telemetry the
/// analytics consent covers. Categories carry [AnalyticsEvents] constants
/// directly, so a renamed event breaks compilation here rather than drifting.
Future<void> showConsentWhatWeLogSheet(BuildContext context) {
  final l10n = context.l10n;
  final categories = <(String, List<String>)>[
    (
      l10n.consentLogCategoryUsage,
      [
        AnalyticsEvents.appOpened,
        AnalyticsEvents.appBackgrounded,
        AnalyticsEvents.logout,
      ],
    ),
    (
      l10n.consentLogCategoryRecipes,
      [
        AnalyticsEvents.recipeCreated,
        AnalyticsEvents.recipeCooked,
        AnalyticsEvents.recipeViewed,
        AnalyticsEvents.recipeSearchPerformed,
      ],
    ),
    (
      l10n.consentLogCategoryMenuShopping,
      [
        AnalyticsEvents.menuGenerated,
        AnalyticsEvents.shoppingListItemChecked,
      ],
    ),
    (
      l10n.consentLogCategoryImport,
      [AnalyticsEvents.importStarted, AnalyticsEvents.importSuccess],
    ),
    (
      l10n.consentLogCategorySocial,
      [AnalyticsEvents.friendRequestSent, AnalyticsEvents.recipeShared],
    ),
    (
      l10n.consentLogCategoryOnboarding,
      [
        AnalyticsEvents.onboardingCompleted,
        AnalyticsEvents.timeToFirstRecipe,
      ],
    ),
  ];
  return showButleryListSheet<void>(
    context,
    title: l10n.consentWhatWeLog,
    rows: (sheetContext) {
      final muted = Theme.of(sheetContext).colorScheme.onSurfaceVariant;
      return [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacingSm,
          ),
          child: Text(
            l10n.consentWhatWeLogIntro,
            style: AppTextStyles.bodySmall.copyWith(color: muted),
          ),
        ),
        for (final (label, eventNames) in categories)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodyBold),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  eventNames.join(', '),
                  style: AppTextStyles.bodySmall.copyWith(color: muted),
                ),
              ],
            ),
          ),
      ];
    },
  );
}
