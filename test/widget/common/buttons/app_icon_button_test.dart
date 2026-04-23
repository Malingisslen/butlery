// test/widget/common/buttons/app_icon_button_test.dart
//
// Intent: prove [AppIconButton] (the canonical icon-only button for the
// Butlery design system) satisfies WCAG 4.1.2 — a screen reader can find
// the action by its required `semanticLabel`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/theme/app_dimensions.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('AppIconButton', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets('exposes the required semantic label to screen readers',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AppIconButton(
            icon: Icons.share,
            onPressed: () {},
            semanticLabel: 'Dela recept',
          ),
        ),
      );

      // AppIconButton wraps IconButton in an explicit Semantics node so the
      // label is visible in the semantic tree for TalkBack/VoiceOver, not
      // just in the tooltip overlay.
      expect(find.bySemanticsLabel('Dela recept'), findsOneWidget);
    });

    testWidgets('meets 48dp minimum touch target via Material IconButton',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Center(
            child: AppIconButton(
              icon: Icons.add,
              onPressed: () {},
              semanticLabel: 'Lägg till',
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
    });

    testWidgets('invokes onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AppIconButton(
            icon: Icons.favorite,
            onPressed: () => taps++,
            semanticLabel: 'Gilla',
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
