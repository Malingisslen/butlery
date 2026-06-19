/// Resolver tests for the engagement metrics — ports the old
/// EngagementViewModel intent: user count + "active" proxies derived from the
/// LATEST day (max across features), and the day×feature matrix. A bug here
/// would report wrong active-user numbers or mis-shape the daily grid.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/engagement_stats.dart';
import 'package:butlery/models/admin/metrics/insights_data.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/metrics/resolvers.dart';

MetricValue _resolve(MetricKey key, EngagementRaw raw, AppLocalizations l10n) =>
    resolvers[key]!(InsightsData(engagement: raw), l10n);

DailyEngagement _day(
  String date, {
  FeatureCounts dau = const FeatureCounts(),
  FeatureCounts wau7d = const FeatureCounts(),
  FeatureCounts wau28d = const FeatureCounts(),
}) =>
    DailyEngagement(date: date, dau: dau, wau7d: wau7d, wau28d: wau28d);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('sv'));
  });

  test('user count surfaces even with no activity days', () {
    final raw = const EngagementRaw(userCount: 3, days: []);
    expect(
        (_resolve(MetricKey.engagementUsers, raw, l10n) as ScalarMetric).value,
        3);
  });

  test('active proxies come from the latest day, max across features', () {
    final raw = EngagementRaw(userCount: 5, days: [
      _day('2026-06-19',
          dau: const FeatureCounts(cooked: 2, imported: 4),
          wau7d: const FeatureCounts(shared: 6),
          wau28d: const FeatureCounts(shopped: 9)),
      _day('2026-06-18', dau: const FeatureCounts(cooked: 99)),
    ]);
    expect(
        (_resolve(MetricKey.engagementActiveToday, raw, l10n) as ScalarMetric)
            .value,
        4);
    expect(
        (_resolve(MetricKey.engagementActive7d, raw, l10n) as ScalarMetric)
            .value,
        6);
    expect(
        (_resolve(MetricKey.engagementActive28d, raw, l10n) as ScalarMetric)
            .value,
        9);
  });

  test('zero days yields zero active proxies, not a crash', () {
    final raw = const EngagementRaw(userCount: 0, days: []);
    expect(
        (_resolve(MetricKey.engagementActiveToday, raw, l10n) as ScalarMetric)
            .value,
        0);
    expect(
        (_resolve(MetricKey.engagementActive28d, raw, l10n) as ScalarMetric)
            .value,
        0);
  });

  test('daily matrix is one row per day with 5 feature columns', () {
    final raw = EngagementRaw(userCount: 1, days: [
      _day('2026-06-19',
          dau: const FeatureCounts(
              cooked: 1, imported: 2, shared: 3, mealPlanned: 4, shopped: 5)),
    ]);
    final value =
        _resolve(MetricKey.engagementDailyTable, raw, l10n) as MatrixMetric;
    expect(value.rowLabels, ['2026-06-19']);
    expect(value.colLabels.length, 5);
    expect(value.cells.single, [1, 2, 3, 4, 5]);
  });
}
