// The completeness part of Statistik: one legend line per bucket, in bucket
// order with that bucket's own count, and nothing at all when no recipe has
// been scored.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/settings/collection_stats/completeness_distribution.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> pump(WidgetTester tester, Map<String, int> distribution) =>
      tester.pumpWidget(
        createLocalizedTestApp(
          child: Scaffold(
            body: CompletenessDistribution(distribution: distribution),
          ),
        ),
      );

  testWidgets('each bucket shows its own count, in bucket order', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, {'0-25%': 2, '25-50%': 0, '50-75%': 1, '75-100%': 4});

    const expected = ['0-25%: 2', '25-50%: 0', '50-75%: 1', '75-100%: 4'];
    final xs = [for (final t in expected) tester.getTopLeft(find.text(t)).dx];
    expect(xs, [...xs]..sort());
    // The bar adds no announcement of its own; the four legend lines are all.
    expect(find.bySemanticsLabel(RegExp('%')), findsNWidgets(4));
    handle.dispose();
  });

  testWidgets('an empty or all-zero distribution draws nothing', (
    tester,
  ) async {
    await pump(tester, {});
    expect(find.textContaining('%:'), findsNothing);

    await pump(tester, {'0-25%': 0, '25-50%': 0, '50-75%': 0, '75-100%': 0});
    expect(find.textContaining('%:'), findsNothing);
  });
}
