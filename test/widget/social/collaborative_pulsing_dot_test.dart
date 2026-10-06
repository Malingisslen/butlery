/// The live-editing dot pulses on the shared loop, motion.durations.pulse
/// (produktbeslut R7-4 = B), and stands still under reduced motion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_motion.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_live_widgets.dart';

void main() {
  Widget app({bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(
        child: CollaborativeLiveWidgets.pulsingDot(const Color(0xFF8A5212)),
      ),
    ),
  );

  double dotAlpha(WidgetTester tester) {
    final dot = tester.widget<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    return (dot.decoration! as BoxDecoration).color!.a;
  }

  test('the pulse loop is 1200 ms', () {
    expect(AppMotion.pulse, const Duration(milliseconds: 1200));
  });

  // R8-9 = A: one loop is AppMotion.pulse, faint to full and back.
  testWidgets('one pulse loop takes the dot to full and back', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(dotAlpha(tester), closeTo(0.3, 0.01));

    await tester.pump(AppMotion.pulse ~/ 2);
    expect(dotAlpha(tester), closeTo(1.0, 0.01));

    await tester.pump(AppMotion.pulse ~/ 2);
    expect(dotAlpha(tester), closeTo(0.3, 0.01));
  });

  testWidgets('reduced motion: the dot stands still at full', (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    expect(dotAlpha(tester), closeTo(1.0, 0.01));

    await tester.pump(AppMotion.pulse ~/ 2);
    expect(dotAlpha(tester), closeTo(1.0, 0.01));
  });
}
