/// Resolver tests for the import-health metrics — ports the old
/// ImportHealthViewModel intent: keep only domains with activity, sort worst
/// (failing) first, compute summary totals/rate, and shape the per-domain
/// matrix. A bug here would hide failing recipe sites or mis-rank them.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/insights_data.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/metrics/resolvers.dart';
import 'package:butlery/models/parsing/site_config.dart';

SiteConfig _cfg(String domain, {required int success, required int fail}) =>
    SiteConfig(
      domain: domain,
      successCount: success,
      failureCount: fail,
      lastUpdated: DateTime.utc(2026, 3, 15),
    );

MetricValue _resolve(
        MetricKey key, List<SiteConfig> configs, AppLocalizations l10n,
        {Map<String, dynamic>? snapshot}) =>
    resolvers[key]!(
        InsightsData(importConfigs: configs, importSnapshot: snapshot), l10n);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('sv'));
  });

  test('domain count excludes domains with no activity', () {
    final configs = [
      _cfg('active.se', success: 1, fail: 0),
      _cfg('never.se', success: 0, fail: 0), // excluded
    ];
    final value = _resolve(MetricKey.importDomains, configs, l10n);
    expect((value as ScalarMetric).value, 1);
  });

  test('summary totals and overall rate are correct', () {
    final configs = [
      _cfg('a.se', success: 5, fail: 0),
      _cfg('b.se', success: 0, fail: 3),
      _cfg('c.se', success: 2, fail: 2),
    ];
    expect(
        (_resolve(MetricKey.importSuccess, configs, l10n) as ScalarMetric)
            .value,
        7);
    expect(
        (_resolve(MetricKey.importFailure, configs, l10n) as ScalarMetric)
            .value,
        5);
    // 7 / 12 = 58.3% → 58
    expect(
        (_resolve(MetricKey.importSuccessRate, configs, l10n) as ScalarMetric)
            .value,
        58);
  });

  test('rate is 0 when there is no activity, not NaN', () {
    final value = _resolve(MetricKey.importSuccessRate, const [], l10n);
    expect((value as ScalarMetric).value, 0);
  });

  test('domain matrix sorts failing worst-rate first and carries 3 columns',
      () {
    final configs = [
      _cfg('ok.se', success: 5, fail: 0), // no failures → last
      _cfg('half.se', success: 2, fail: 2), // 50%
      _cfg('broken.se', success: 0, fail: 3), // 0% → first
    ];
    final value =
        _resolve(MetricKey.importDomainTable, configs, l10n) as MatrixMetric;
    expect(value.rowLabels, ['broken.se', 'half.se', 'ok.se']);
    expect(value.colLabels.length, 3);
    // broken.se row: 0 success, 3 fail, 0% rate
    expect(value.cells.first, [0, 3, 0]);
    // ok.se row: 5 success, 0 fail, 100% rate
    expect(value.cells.last, [5, 0, 100]);
  });

  test('import scalars carry snapshot totals as previous for deltas', () {
    final configs = [_cfg('a.se', success: 8, fail: 2)];
    const snapshot = {
      'totalSuccess': 6,
      'totalFailure': 2,
      'byDomain': {'a.se': {}, 'b.se': {}},
    };
    final success =
        _resolve(MetricKey.importSuccess, configs, l10n, snapshot: snapshot)
            as ScalarMetric;
    expect(success.value, 8);
    expect(success.previous, 6);
    final domains =
        _resolve(MetricKey.importDomains, configs, l10n, snapshot: snapshot)
            as ScalarMetric;
    expect(domains.previous, 2); // two domains in the snapshot
  });

  test('empty configs yield an empty matrix (no crash)', () {
    final value =
        _resolve(MetricKey.importDomainTable, const [], l10n) as MatrixMetric;
    expect(value.isEmpty, isTrue);
  });
}
