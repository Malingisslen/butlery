/// Widget tests for AccessibilityUtils.clampTextScaling.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/accessibility_utils.dart';

Widget _wrap(double scale, Widget child, {double maxScaleFactor = 1.3}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Builder(builder: (ctx) {
        return AccessibilityUtils.clampTextScaling(
          context: ctx,
          maxScaleFactor: maxScaleFactor,
          child: child,
        );
      }),
    ),
  );
}

void main() {
  testWidgets('scale below max → passes through unchanged', (tester) async {
    TextScaler? observed;
    await tester.pumpWidget(_wrap(
      1.0,
      Builder(builder: (ctx) {
        observed = MediaQuery.of(ctx).textScaler;
        return const SizedBox.shrink();
      }),
    ));
    // 1.0 < 1.3 → no clamp.
    expect(observed!.scale(10), 10);
  });

  testWidgets('scale at threshold → unchanged', (tester) async {
    TextScaler? observed;
    await tester.pumpWidget(_wrap(
      1.3,
      Builder(builder: (ctx) {
        observed = MediaQuery.of(ctx).textScaler;
        return const SizedBox.shrink();
      }),
    ));
    expect(observed!.scale(10), closeTo(13, 0.01));
  });

  testWidgets('scale above max → clamped to maxScaleFactor', (tester) async {
    TextScaler? observed;
    await tester.pumpWidget(_wrap(
      2.0, // way over the max
      Builder(builder: (ctx) {
        observed = MediaQuery.of(ctx).textScaler;
        return const SizedBox.shrink();
      }),
    ));
    // Should clamp to 1.3 → scale(10) ≈ 13, not 20.
    expect(observed!.scale(10), closeTo(13, 0.01));
  });

  testWidgets('custom maxScaleFactor honored', (tester) async {
    TextScaler? observed;
    await tester.pumpWidget(_wrap(
      3.0,
      Builder(builder: (ctx) {
        observed = MediaQuery.of(ctx).textScaler;
        return const SizedBox.shrink();
      }),
      maxScaleFactor: 1.5,
    ));
    expect(observed!.scale(10), closeTo(15, 0.01));
  });

  testWidgets('child renders inside the wrapped MediaQuery', (tester) async {
    await tester.pumpWidget(_wrap(
      2.0,
      const Text('hello'),
    ));
    expect(find.text('hello'), findsOneWidget);
  });
}
