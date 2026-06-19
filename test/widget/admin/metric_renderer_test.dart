/// Widget tests for MetricRenderer — the kind-driven renderer. Proves a scalar
/// renders as a stat card, a breakdown renders its rows, and (most important
/// per the dashboard's main risk) every kind mounts on EMPTY data with the
/// "Ingen data" placeholder instead of crashing.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/views/admin/widgets/metric_renderer.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('scalar renders the formatted value', (tester) async {
    await tester.pumpWidget(createLocalizedTestApp(
      child: const MetricRenderer(
        metricKey: MetricKey.recipeTotal,
        value: ScalarMetric(7),
      ),
    ));
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('breakdown renders a row per entry', (tester) async {
    await tester.pumpWidget(createLocalizedTestApp(
      wrapInScrollView: true,
      child: const MetricRenderer(
        metricKey: MetricKey.recipeByMethod,
        value: BreakdownMetric([
          BreakdownRow('Länk (URL)', 3),
          BreakdownRow('Manuellt / okänt', 2),
        ]),
      ),
    ));
    expect(find.text('Länk (URL)'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Manuellt / okänt'), findsOneWidget);
  });

  testWidgets('empty breakdown shows the no-data placeholder, no crash',
      (tester) async {
    await tester.pumpWidget(createLocalizedTestApp(
      child: const MetricRenderer(
        metricKey: MetricKey.recipeByMethod,
        value: BreakdownMetric([]),
      ),
    ));
    expect(find.text('Ingen data än'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every MetricValue kind mounts on empty data without crashing',
      (tester) async {
    const empties = <MetricValue>[
      SeriesMetric([]),
      BreakdownMetric([]),
      MatrixMetric([], [], []),
      FunnelMetric([]),
    ];
    for (final value in empties) {
      await tester.pumpWidget(createLocalizedTestApp(
        wrapInScrollView: true,
        child: MetricRenderer(
          metricKey: MetricKey.recipeByMethod,
          value: value,
        ),
      ));
      expect(tester.takeException(), isNull,
          reason: '${value.runtimeType} crashed on empty data');
    }
  });
}
