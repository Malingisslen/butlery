import 'package:csv/csv.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/catalog.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';

/// Builds a Swedish-Excel-friendly CSV of the given metrics: UTF-8 BOM (so
/// Excel reads åäö), semicolon delimiter (Swedish locale), CRLF line ends,
/// and RAW numbers (no grouping spaces) so Excel parses them as numbers. One
/// section per metric. Pure — no platform/IO, trivially testable.
String buildMetricsCsv(
  List<MetricKey> keys,
  Map<MetricKey, MetricValue> values,
  AppLocalizations l10n,
) {
  final rows = <List<String>>[];

  for (final key in keys) {
    final value = values[key];
    final desc = catalog[key];
    if (value == null || desc == null) continue;
    final label = desc.label(l10n);

    switch (value) {
      case ScalarMetric(value: final v):
        rows.add([label, _num(v)]);
      case BreakdownMetric(rows: final brows):
        rows.add([label]);
        for (final r in brows) {
          rows.add([r.label, _num(r.value)]);
        }
      case SeriesMetric(points: final points):
        rows.add([label]);
        for (final p in points) {
          rows.add([p.label, _num(p.value)]);
        }
      case FunnelMetric(stages: final stages):
        rows.add([label]);
        for (final s in stages) {
          rows.add([s.label, _num(s.value)]);
        }
      case MatrixMetric(
        rowLabels: final rowLabels,
        colLabels: final colLabels,
        cells: final cells,
      ):
        rows.add([label, ...colLabels]);
        for (var r = 0; r < rowLabels.length; r++) {
          rows.add([rowLabels[r], for (final c in cells[r]) _num(c)]);
        }
    }
    rows.add(const []); // blank separator between metrics
  }

  const converter = CsvEncoder(fieldDelimiter: ';', lineDelimiter: '\r\n');
  // ﻿ = UTF-8 BOM so Excel detects UTF-8 and renders åäö correctly.
  return '﻿${converter.convert(rows)}';
}

/// Raw numeric string — int without a trailing `.0`, no grouping separators.
String _num(num value) => (value % 1 == 0 ? value.toInt() : value).toString();
