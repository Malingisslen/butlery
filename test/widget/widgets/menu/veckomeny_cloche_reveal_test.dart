import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/brand/butlery_cloche.dart';
import 'package:butlery/widgets/common/brand/butlery_cloche_lift.dart';
import 'package:butlery/widgets/menu/veckomeny_cloche_reveal.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('lifts the cover, holds, then hands the week back', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: VeckomenyClocheReveal(onDone: () => done = true),
      ),
    );

    expect(tester.widget<ButleryCloche>(find.byType(ButleryCloche)).lift, 0);

    await tester.pump();
    await tester.pump(ButleryClocheLift.duration);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.widget<ButleryCloche>(find.byType(ButleryCloche)).lift, 1);
    expect(done, isFalse, reason: 'the lifted cloche is held first');

    await tester.pump(VeckomenyClocheReveal.hold);
    expect(done, isTrue);
  });

  testWidgets('hands the week back at once when animations are off', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: createLocalizedTestApp(
          child: VeckomenyClocheReveal(onDone: () => done = true),
        ),
      ),
    );
    await tester.pump();

    expect(done, isTrue);
  });
}
