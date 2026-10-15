// Spår H del 4: the ink primary and the status chip button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/butlery_ink_button.dart';
import 'package:butlery/widgets/common/buttons/butlery_status_chip_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

Widget _themed(Widget child, {required bool dark}) => MaterialApp(
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('ButleryInkButton', () {
    testWidgets('light: the theme fill, no style of its own', (tester) async {
      await tester.pumpWidget(
        _themed(
          ButleryInkButton(label: 'Börja laga', onPressed: () {}),
          dark: false,
        ),
      );
      final button = tester.widget<FilledButton>(
        find.bySubtype<FilledButton>(),
      );
      expect(button.style, isNull);
    });

    testWidgets('dark: no fill, a paper outline and paper text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          ButleryInkButton(label: 'Börja laga', onPressed: () {}),
          dark: true,
        ),
      );
      final cs = Theme.of(tester.element(find.text('Börja laga'))).colorScheme;
      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      expect(style.backgroundColor?.resolve({}), Colors.transparent);
      expect(style.foregroundColor?.resolve({}), cs.onSurface);
      final side = style.side!.resolve({})!;
      expect(side.color, cs.onSurface);
      expect(side.width, AppDimensions.borderWidthOutlinedEdge);
    });

    testWidgets('a tap fires and null disables', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _themed(
          ButleryInkButton(
            label: 'Lägg i inköpslistan',
            onPressed: () => taps++,
          ),
          dark: false,
        ),
      );
      await tester.tap(find.text('Lägg i inköpslistan'));
      expect(taps, 1);
      await tester.pumpWidget(
        _themed(
          const ButleryInkButton(label: 'Lägg i inköpslistan', onPressed: null),
          dark: false,
        ),
      );
      expect(
        tester.widget<FilledButton>(find.bySubtype<FilledButton>()).onPressed,
        isNull,
      );
    });

    testWidgets('an icon is drawn before the words, in dark too', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          ButleryInkButton(
            label: 'Börja laga',
            icon: ButleryIcons.check,
            onPressed: () {},
          ),
          dark: true,
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.bySubtype<FilledButton>())
            .style
            ?.side
            ?.resolve({}),
        isNotNull,
      );
      expect(
        tester.getTopLeft(find.byIcon(ButleryIcons.check)).dx,
        lessThan(tester.getTopLeft(find.text('Börja laga')).dx),
      );
      expect(find.text('Börja laga'), findsOneWidget);
      expect(find.bySubtype<FilledButton>(), findsOneWidget);
      expect(find.byIcon(ButleryIcons.check), findsOneWidget);
    });
  });

  group('ButleryStatusChipButton', () {
    OutlinedButton button(WidgetTester tester) =>
        tester.widget<OutlinedButton>(find.bySubtype<OutlinedButton>());

    testWidgets('success: success words and edge, 0.5 wide', (tester) async {
      await tester.pumpWidget(
        _themed(
          ButleryStatusChipButton(
            label: 'Lagat idag',
            icon: ButleryIcons.circleCheck,
            onPressed: () {},
          ),
          dark: false,
        ),
      );
      final colors = tester.element(find.text('Lagat idag')).modeColors;
      final style = button(tester).style!;
      expect(style.foregroundColor?.resolve({}), colors.success);
      final side = style.side!.resolve({})!;
      expect(side.color, colors.success);
      expect(side.width, AppDimensions.borderWidthThin);
    });

    testWidgets('gold: starGold edge behind onWarningContainer words', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          ButleryStatusChipButton(
            label: 'Betygsätt som hushåll',
            icon: ButleryIcons.users,
            tone: ButleryStatusChipTone.gold,
            onPressed: () {},
          ),
          dark: false,
        ),
      );
      final colors = tester
          .element(find.text('Betygsätt som hushåll'))
          .modeColors;
      final style = button(tester).style!;
      expect(style.foregroundColor?.resolve({}), colors.onWarningContainer);
      expect(style.side!.resolve({})!.color, colors.starGold);
    });

    testWidgets('disabled: text.disabled on a surface.disabled edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          const ButleryStatusChipButton(
            label: 'Lagat idag',
            icon: ButleryIcons.circleCheck,
            onPressed: null,
          ),
          dark: true,
        ),
      );
      final style = button(tester).style!;
      expect(
        style.foregroundColor?.resolve({WidgetState.disabled}),
        AppModeColors.textDisabled(Brightness.dark),
      );
      expect(
        style.side!.resolve({})!.color,
        AppModeColors.surfaceDisabled(Brightness.dark),
      );
    });

    testWidgets('it stays small and a tap fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _themed(
          ButleryStatusChipButton(
            label: 'Lagat idag',
            icon: ButleryIcons.circleCheck,
            onPressed: () => taps++,
          ),
          dark: false,
        ),
      );
      expect(
        button(tester).style!.tapTargetSize,
        MaterialTapTargetSize.padded,
      );
      // The padding makes the tap area 48 dp; the drawn button inside hugs its
      // words instead of filling the row.
      expect(
        tester.getSize(find.bySubtype<OutlinedButton>()).height,
        AppDimensions.minTouchTarget,
      );
      final drawn = find
          .descendant(
            of: find.bySubtype<OutlinedButton>(),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.getSize(drawn).height,
        lessThan(AppDimensions.controlVisualHeight),
      );
      expect(tester.getSize(drawn).width, lessThan(200));
      await tester.tap(find.text('Lagat idag'));
      expect(taps, 1);
    });
  });
}
