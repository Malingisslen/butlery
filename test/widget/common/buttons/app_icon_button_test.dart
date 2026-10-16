// test/widget/common/buttons/app_icon_button_test.dart
//
// Intent: prove [AppIconButton] (the canonical icon-only button for the
// Butlery design system) satisfies WCAG 4.1.2 — a screen reader can find
// the action by its required `semanticLabel`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('AppIconButton', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets('exposes the required semantic label to screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AppIconButton(
            icon: ButleryIcons.share2,
            onPressed: () {},
            semanticLabel: 'Dela recept',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Dela recept'), findsOneWidget);
    });

    testWidgets('meets 48dp minimum touch target via Material IconButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Center(
            child: AppIconButton(
              icon: ButleryIcons.plus,
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
            icon: ButleryIcons.heart,
            onPressed: () => taps++,
            semanticLabel: 'Gilla',
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(taps, 1);
    });

    for (final dark in [false, true]) {
      testWidgets('filled draws the action fill with its own glyph colour in '
          '${dark ? 'dark' : 'light'} mode', (tester) async {
        final brightness = dark ? Brightness.dark : Brightness.light;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: Scaffold(
              body: AppIconButton(
                icon: ButleryIcons.plus,
                onPressed: () {},
                semanticLabel: 'Lägg till',
                filled: true,
              ),
            ),
          ),
        );

        final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
        final fill = style.backgroundColor!.resolve({})!;
        final glyph = style.foregroundColor!.resolve({})!;
        expect(fill, AppModeColors.actionFill(brightness));
        expect(glyph, AppModeColors.onActionFill(brightness));

        double contrast(Color a, Color b) {
          final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
          final lo = identical(hi, a) ? b : a;
          return (hi.computeLuminance() + 0.05) /
              (lo.computeLuminance() + 0.05);
        }

        expect(contrast(fill, glyph), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
