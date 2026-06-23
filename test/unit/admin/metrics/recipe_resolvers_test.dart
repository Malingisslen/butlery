/// Resolver tests for the recipe metrics — proves the pure (InsightsData, l10n)
/// → MetricValue path: the scalar total and the method breakdown (fixed order,
/// localized labels). This is the template every migrated tab's resolvers follow.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/insights_data.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/metrics/resolvers.dart';
import 'package:butlery/models/admin/recipe_stats.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('sv'));
  });

  test('recipeTotal resolves to a scalar of the total', () {
    final data = InsightsData(
      recipes: const RecipeStats(total: 7, byMethod: {}),
    );
    final value = resolvers[MetricKey.recipeTotal]!(data, l10n);
    expect(value, isA<ScalarMetric>());
    expect((value as ScalarMetric).value, 7);
    expect(value.isEmpty, isFalse);
  });

  test('recipeTotal carries the snapshot total as previous for a delta', () {
    final data = InsightsData(
      recipes: const RecipeStats(total: 12, byMethod: {}),
      recipeSnapshot: const {'total': 10},
    );
    final value = resolvers[MetricKey.recipeTotal]!(data, l10n) as ScalarMetric;
    expect(value.value, 12);
    expect(value.previous, 10);
    expect(value.deltaPercent, 20); // (12-10)/10*100
  });

  test('recipeTotal has no previous when there is no snapshot yet', () {
    final data = InsightsData(
      recipes: const RecipeStats(total: 3, byMethod: {}),
    );
    final value = resolvers[MetricKey.recipeTotal]!(data, l10n) as ScalarMetric;
    expect(value.previous, isNull);
    expect(value.deltaPercent, isNull);
  });

  test('recipeByMethod resolves to a fixed-order localized breakdown', () {
    final data = InsightsData(
      recipes: const RecipeStats(
        total: 6,
        byMethod: {
          RecipeImportMethod.url: 3,
          RecipeImportMethod.manual: 2,
          RecipeImportMethod.photo: 1,
        },
      ),
    );
    final value = resolvers[MetricKey.recipeByMethod]!(data, l10n);
    expect(value, isA<BreakdownMetric>());
    final rows = (value as BreakdownMetric).rows;
    // five fixed rows, url first, manual last
    expect(rows.length, 5);
    expect(rows.first.label, l10n.adminRecipesMethodUrl);
    expect(rows.first.value, 3);
    expect(rows.last.label, l10n.adminRecipesMethodManual);
    expect(rows.last.value, 2);
    // a method with no recipes still shows a zero row
    final social = rows.firstWhere(
      (r) => r.label == l10n.adminRecipesMethodSocial,
    );
    expect(social.value, 0);
  });
}
