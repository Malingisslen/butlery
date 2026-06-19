/// Widget test for the metric info "i" button — the pedagogical layer. Tapping
/// it must open a dialog showing the metric's what / how / why from the
/// explanations registry, and close cleanly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/views/admin/widgets/admin_metric_info_button.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('tapping the info button opens what/how/why, then closes',
      (tester) async {
    await tester.pumpWidget(createLocalizedTestApp(
      child: const AdminMetricInfoButton(metricKey: MetricKey.recipeTotal),
    ));

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    // The three teaching sections are present.
    expect(find.text('Vad är det'), findsOneWidget);
    expect(find.text('Hur räknas det'), findsOneWidget);
    expect(find.text('Varför viktigt'), findsOneWidget);
    // And the real explanation copy for this metric is shown.
    expect(find.textContaining('totala antalet recept'), findsOneWidget);

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();
    expect(find.text('Vad är det'), findsNothing);
  });
}
