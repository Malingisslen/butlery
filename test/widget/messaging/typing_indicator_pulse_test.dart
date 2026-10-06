// The "skriver …" dots pulse while someone is typing, one loop per
// AppMotion.pulse, and stop when nobody is (produktbeslut R7-4 = B, R8-9 = A).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_motion.dart';
import 'package:butlery/widgets/messaging/typing_indicator.dart';

Widget _app(List<String> names, {bool reduceMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: TypingIndicator(typingUserNames: names)),
    ),
  ),
);

/// The alpha of each of the three 4 dp dots.
List<double> _dotAlphas(WidgetTester tester) => [
  for (final c in tester.widgetList<Container>(
    find.descendant(
      of: find.byType(TypingIndicator),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 4 &&
            w.constraints?.maxHeight == 4,
      ),
    ),
  ))
    (c.decoration! as BoxDecoration).color!.a,
];

void main() {
  testWidgets('the dots keep pulsing, one loop per AppMotion.pulse', (
    tester,
  ) async {
    await tester.pumpWidget(_app(['Anna']));
    await tester.pump(AppMotion.standard);
    final start = _dotAlphas(tester);
    expect(start, hasLength(3));

    await tester.pump(AppMotion.pulseHalf);
    final half = _dotAlphas(tester);
    expect(half, isNot(equals(start)), reason: 'the dots move');

    await tester.pump(AppMotion.pulseHalf);
    final loop = _dotAlphas(tester);
    for (var i = 0; i < 3; i++) {
      expect(loop[i], closeTo(start[i], 0.01), reason: 'one loop is pulse');
    }

    // Still running after several loops: a repeat, not a one-shot.
    await tester.pump(AppMotion.pulse * 3 + AppMotion.pulseHalf);
    expect(_dotAlphas(tester), isNot(equals(start)));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('the pulse stops when nobody is typing', (tester) async {
    await tester.pumpWidget(_app(['Anna']));
    await tester.pump(AppMotion.pulse);
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('under reduced motion the dots stand still', (tester) async {
    await tester.pumpWidget(_app(['Anna'], reduceMotion: true));
    await tester.pump();
    final start = _dotAlphas(tester);
    expect(start, hasLength(3));
    await tester.pump(AppMotion.pulseHalf);
    expect(_dotAlphas(tester), start);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
