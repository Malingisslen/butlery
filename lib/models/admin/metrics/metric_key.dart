/// The closed set of dashboard metrics. A Dart `enum` is exactly the "string
/// union" the registry pattern wants: `.values` powers the key-lock test,
/// `.name` is URL-safe (for shareable views) and a stable CSV header.
///
/// Keys are added tab-by-tab as each tab migrates onto the registry; the
/// key-lock test (test/unit/admin/metrics/registry_keys_test.dart) keeps the
/// catalog/resolvers/explanations registries in lockstep with this enum.
library;

/// Grouping that drives lazy per-category fetching (the assembler fetches only
/// the categories whose metrics are on screen) and tab composition.
enum MetricCategory {
  engagement,
  importHealth,
  parsing,
  recipes,
  feedback,
  ops
}

enum MetricKey {
  // recipes
  recipeTotal,
  recipeByMethod,
  // import health
  importDomains,
  importSuccess,
  importFailure,
  importSuccessRate,
  importDomainTable,
  // engagement
  engagementUsers,
  engagementActiveToday,
  engagementActive7d,
  engagementActive28d,
  engagementDailyTable;

  MetricCategory get category => switch (this) {
        recipeTotal || recipeByMethod => MetricCategory.recipes,
        importDomains ||
        importSuccess ||
        importFailure ||
        importSuccessRate ||
        importDomainTable =>
          MetricCategory.importHealth,
        engagementUsers ||
        engagementActiveToday ||
        engagementActive7d ||
        engagementActive28d ||
        engagementDailyTable =>
          MetricCategory.engagement,
      };
}
