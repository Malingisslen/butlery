/// Tests for buildMetricsCsv — the Swedish-Excel CSV export: BOM prefix,
/// semicolon delimiter, CRLF line ends, raw numbers, and one section per
/// metric (scalar row, breakdown rows, matrix header+rows). A bug here would
/// produce a file Excel mis-parses (wrong delimiter, broken åäö, or "NaN").
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/views/admin/metrics_csv.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('sv'));
  });

  test('starts with a UTF-8 BOM and uses semicolon + CRLF', () {
    final csv = buildMetricsCsv(
      const [MetricKey.recipeTotal],
      const {MetricKey.recipeTotal: ScalarMetric(7)},
      l10n,
    );
    expect(csv.codeUnitAt(0), 0xFEFF); // BOM
    expect(csv.contains('\r\n'), isTrue); // CRLF
    expect(csv.contains(';'), isTrue); // semicolon delimiter
    expect(csv.contains('7'), isTrue);
  });

  test('a matrix becomes a header row + one row per data row, raw numbers', () {
    final csv = buildMetricsCsv(
      const [MetricKey.importDomainTable],
      const {
        MetricKey.importDomainTable: MatrixMetric(
          ['koket.se'],
          ['Lyckade', 'Misslyckade', 'Andel'],
          [
            [1, 3, 25],
          ],
        ),
      },
      l10n,
    );
    expect(csv.contains('Lyckade;Misslyckade;Andel'), isTrue);
    expect(csv.contains('koket.se;1;3;25'), isTrue);
  });

  test('whole-number values carry no .0 (Excel parses them as numbers)', () {
    final csv = buildMetricsCsv(
      const [MetricKey.recipeTotal],
      const {MetricKey.recipeTotal: ScalarMetric(1000)},
      l10n,
    );
    expect(csv.contains('1000'), isTrue);
    expect(csv.contains('1000.0'), isFalse);
    expect(csv.contains('1 000'), isFalse); // no grouping space in CSV
  });

  test('skips metrics with no resolved value, no crash', () {
    final csv = buildMetricsCsv(
      const [MetricKey.recipeTotal, MetricKey.recipeByMethod],
      const {MetricKey.recipeTotal: ScalarMetric(2)}, // byMethod missing
      l10n,
    );
    expect(csv.contains('2'), isTrue);
  });
}
