/// Widget tests for the metric charts: they must mount with data and degrade to
/// nothing on empty data without throwing, and the renderer must show a chart
/// for a chart-enabled metric (recipeByMethod = bar). Charts are decoration
/// over the table, so "no crash" is the load-bearing guarantee.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/views/admin/widgets/metric_charts.dart';
import 'package:butlery/views/admin/widgets/metric_renderer.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('bar chart mounts with data', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const MetricBarChart(
          rows: [
            BreakdownRow('Länk', 3),
            BreakdownRow('Foto', 1),
          ],
        ),
      ),
    );
    expect(find.byType(BarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty bar chart renders nothing, no crash', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const MetricBarChart(rows: []),
      ),
    );
    expect(find.byType(BarChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('line chart mounts with a matrix + legend', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: const MetricLineChart(
          value: MatrixMetric(
            ['2026-06-19', '2026-06-18'],
            ['Lagat', 'Delat'],
            [
              [2, 1],
              [0, 3],
            ],
          ),
        ),
      ),
    );
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Lagat'), findsOneWidget); // legend
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty line chart renders nothing, no crash', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const MetricLineChart(value: MatrixMetric([], [], [])),
      ),
    );
    expect(find.byType(LineChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renderer shows a bar chart for the recipe-by-method metric', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: const MetricRenderer(
          metricKey: MetricKey.recipeByMethod,
          value: BreakdownMetric([
            BreakdownRow('Länk (URL)', 5),
            BreakdownRow('Manuellt / okänt', 2),
          ]),
        ),
      ),
    );
    expect(find.byType(BarChart), findsOneWidget); // chart above the table
    expect(find.text('Länk (URL)'), findsOneWidget); // table still present
    expect(tester.takeException(), isNull);
  });
}
