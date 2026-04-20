// test/widget/common/indicators/pulse_dot_test.dart
//
// BUT-408: pump tests for the extracted [PulseDot].

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/indicators/pulse_dot.dart';

void main() {
  Widget wrap(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Center(child: child),
        ),
      ),
    );
  }

  group('PulseDot', () {
    testWidgets('renders a square of the configured size and color',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const PulseDot(color: Color(0xFFFBBF24), size: 10),
          disableAnimations: true,
        ),
      );

      // The outer SizedBox governs the footprint; Transform.scale wraps it
      // only when animating, so with reduce-motion the top-level is the
      // SizedBox itself.
      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 10),
      );
      expect(sizedBox.height, 10);
      expect(sizedBox.width, 10);

      // A ColoredBox with the requested color is rendered inside.
      final coloredBox = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(PulseDot),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(coloredBox.color, const Color(0xFFFBBF24));

      // Large pump must not fail — no animation controller running.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('animates when reduce-motion is off', (tester) async {
      await tester.pumpWidget(
        wrap(
          const PulseDot(color: Color(0xFF4A7C59), size: 8),
          // disableAnimations defaults to false
        ),
      );

      // Rendering with a Transform.scale wrapper implies the animation is
      // active — under reduce-motion the scale wrapper is skipped.
      expect(
        find.descendant(
          of: find.byType(PulseDot),
          matching: find.byType(Transform),
        ),
        findsWidgets,
      );

      // Pump a couple of frames to exercise the animation ticker. We do
      // NOT pumpAndSettle — the animation repeats forever and would never
      // settle. A few explicit pumps is enough to prove the ticker runs.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('reduce-motion skips the Transform.scale wrapper',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const PulseDot(color: Color(0xFF4A7C59), size: 8),
          disableAnimations: true,
        ),
      );

      // Under reduce-motion the widget short-circuits to a plain
      // SizedBox + ColoredBox (no Transform).
      expect(
        find.descendant(
          of: find.byType(PulseDot),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });
}
