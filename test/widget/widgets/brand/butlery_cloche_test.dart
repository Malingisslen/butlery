import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/brand/butlery_cloche.dart';
import 'package:butlery/widgets/common/brand/start_splash.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('ButleryClochePose', () {
    test('lift runs from the closed pose to the lifted pose', () {
      expect(ButleryClochePose.lift(0), ButleryClochePose.closed);
      final end = ButleryClochePose.lift(1);
      expect(end.coverTurn, ButleryClochePose.lifted.coverTurn);
      expect(end.coverDy, ButleryClochePose.lifted.coverDy);
      expect(end.foodOpacity, 1);
    });

    test('lift clamps outside 0..1', () {
      expect(ButleryClochePose.lift(-1), ButleryClochePose.closed);
      expect(
        ButleryClochePose.lift(2).coverTurn,
        ButleryClochePose.lifted.coverTurn,
      );
    });
  });

  group('StartSplash.poseAt', () {
    test('rests closed at the start and end of the loop', () {
      for (final t in [0.0, 1.0]) {
        final p = StartSplash.poseAt(t);
        expect(p.coverTurn, closeTo(0, 0.01), reason: 't=$t');
        expect(p.coverDy, closeTo(0, 0.01), reason: 't=$t');
        expect(p.coverOpacity, 1, reason: 't=$t');
        expect(p.foodOpacity, 0, reason: 't=$t');
      }
    });

    test('the cover is gone and the food stands in the middle', () {
      final p = StartSplash.poseAt(0.7);
      expect(p.coverOpacity, 0);
      expect(p.foodOpacity, 1);
    });
  });

  group('StartSplash', () {
    testWidgets('shows the tagline and what it waits for', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(child: const StartSplash(message: 'Väntar')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Väntar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with reduced motion the cloche stands still', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: createLocalizedTestApp(child: const StartSplash()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
