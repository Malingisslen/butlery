/// Direct unit tests for the admin-metric [resolvers] map (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Each resolver is a pure function (InsightsData, l10n) → MetricValue that the
/// admin dashboard renders. These tests feed a hand-built InsightsData fixture
/// and assert the computed numbers + structure: totals and their snapshot
/// "previous", the active-domain filtering/sort, success-rate math, and the
/// engagement window lookups. Localized label TEXT isn't asserted (brittle) —
/// only row/column counts and cell values.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/engagement_stats.dart';
import 'package:butlery/models/admin/metrics/insights_data.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/metrics/resolvers.dart';
import 'package:butlery/models/admin/recipe_stats.dart';
import 'package:butlery/models/parsing/site_config.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  T resolve<T extends MetricValue>(MetricKey key, InsightsData data) =>
      resolvers[key]!(data, l10n) as T;

  final fixture = InsightsData(
    recipes: const RecipeStats(
      total: 42,
      byMethod: {
        RecipeImportMethod.url: 10,
        RecipeImportMethod.photo: 5,
        RecipeImportMethod.textPaste: 3,
        RecipeImportMethod.social: 2,
        RecipeImportMethod.manual: 22,
      },
    ),
    recipeSnapshot: const {'total': 30},
    importConfigs: [
      // Has failures → sorts first. rate = 8/10 = 0.8.
      SiteConfig(
        domain: 'ica.se',
        successCount: 8,
        failureCount: 2,
        lastUpdated: DateTime(2026, 1, 2),
      ),
      // No failures, perfect rate → sorts after ica.
      SiteConfig(
        domain: 'arla.se',
        successCount: 10,
        failureCount: 0,
        lastUpdated: DateTime(2026, 1, 1),
      ),
      // No activity at all → excluded from "active".
      const SiteConfig(domain: 'idle.se'),
    ],
    importSnapshot: const {
      'byDomain': {'a': 1, 'b': 1, 'c': 1},
      'totalSuccess': 15,
      'totalFailure': 5,
    },
    engagement: const EngagementRaw(
      userCount: 100,
      days: [
        DailyEngagement(
          date: 'd0',
          dau: FeatureCounts(cooked: 5, imported: 3, shared: 1),
          wau7d: FeatureCounts(cooked: 20),
          wau28d: FeatureCounts(cooked: 50),
        ),
        DailyEngagement(
          date: 'd1',
          dau: FeatureCounts(cooked: 4),
          wau7d: FeatureCounts(cooked: 18),
          wau28d: FeatureCounts(cooked: 40),
        ),
      ],
    ),
  );

  group('recipe metrics', () {
    test('recipeTotal carries the total and the snapshot previous', () {
      final m = resolve<ScalarMetric>(MetricKey.recipeTotal, fixture);
      expect(m.value, 42);
      expect(m.previous, 30);
    });

    test('recipeByMethod breaks down in fixed order', () {
      final m = resolve<BreakdownMetric>(MetricKey.recipeByMethod, fixture);
      expect(m.rows.map((r) => r.value).toList(), [10, 5, 3, 2, 22]);
    });
  });

  group('import metrics', () {
    test('importDomains counts active domains; previous from snapshot', () {
      final m = resolve<ScalarMetric>(MetricKey.importDomains, fixture);
      expect(m.value, 2); // idle.se excluded
      expect(m.previous, 3); // byDomain map length
    });

    test('importSuccess / importFailure sum active domains', () {
      expect(resolve<ScalarMetric>(MetricKey.importSuccess, fixture).value, 18);
      expect(
        resolve<ScalarMetric>(MetricKey.importSuccess, fixture).previous,
        15,
      );
      expect(resolve<ScalarMetric>(MetricKey.importFailure, fixture).value, 2);
      expect(
        resolve<ScalarMetric>(MetricKey.importFailure, fixture).previous,
        5,
      );
    });

    test(
      'importSuccessRate is a rounded percentage with snapshot previous',
      () {
        final m = resolve<ScalarMetric>(MetricKey.importSuccessRate, fixture);
        expect(m.value, 90); // 18 / 20
        expect(m.previous, 75); // 15 / 20 from snapshot
      },
    );

    test(
      'importDomainTable lists active domains failures-first with rates',
      () {
        final m = resolve<MatrixMetric>(MetricKey.importDomainTable, fixture);
        expect(m.rowLabels, ['ica.se', 'arla.se']);
        expect(m.colLabels, hasLength(3));
        expect(m.cells, [
          [8, 2, 80],
          [10, 0, 100],
        ]);
      },
    );
  });

  group('engagement metrics', () {
    test('engagementUsers is the user count', () {
      expect(
        resolve<ScalarMetric>(MetricKey.engagementUsers, fixture).value,
        100,
      );
    });

    test('activeToday uses day0 max with yesterday as previous', () {
      final m = resolve<ScalarMetric>(MetricKey.engagementActiveToday, fixture);
      expect(m.value, 5); // max(5,3,1,0,0)
      expect(m.previous, 4); // day1 dau max
    });

    test(
      'active7d/28d read their windows; previous null without enough days',
      () {
        expect(
          resolve<ScalarMetric>(MetricKey.engagementActive7d, fixture).value,
          20,
        );
        expect(
          resolve<ScalarMetric>(MetricKey.engagementActive7d, fixture).previous,
          isNull, // only 2 days < 7
        );
        expect(
          resolve<ScalarMetric>(MetricKey.engagementActive28d, fixture).value,
          50,
        );
        expect(
          resolve<ScalarMetric>(
            MetricKey.engagementActive28d,
            fixture,
          ).previous,
          isNull,
        );
      },
    );

    test('engagementDailyTable is a day × feature matrix', () {
      final m = resolve<MatrixMetric>(MetricKey.engagementDailyTable, fixture);
      expect(m.rowLabels, ['d0', 'd1']);
      expect(m.colLabels, hasLength(5));
      // day0: cooked5, imported3, shared1, mealPlanned0, shopped0
      expect(m.cells.first, [5, 3, 1, 0, 0]);
    });

    test('empty engagement days yield a zero scalar, not a crash', () {
      const empty = InsightsData(
        engagement: EngagementRaw(userCount: 0, days: []),
      );
      expect(
        resolve<ScalarMetric>(MetricKey.engagementActiveToday, empty).value,
        0,
      );
      expect(
        resolve<ScalarMetric>(MetricKey.engagementActive7d, empty).value,
        0,
      );
    });
  });
}
