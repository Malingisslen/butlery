// The chat and comment composer: round ends, the shared edge and fill, and
// growth to four lines before it scrolls (inmatningsfält riktning A, del 4).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/styled/butlery_composer_field.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  TextEditingController? controller,
  bool enabled = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: ButleryComposerField(
              hintText: 'Skriv ett meddelande',
              controller: controller,
              enabled: enabled,
            ),
          ),
        ),
      ),
    ),
  );
}

InputDecoration _decoration(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!;

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    group('ButleryComposerField, $mode', () {
      testWidgets('has round ends and the control edge', (tester) async {
        await _pump(tester, theme);

        final resting =
            _decoration(tester).enabledBorder! as OutlineInputBorder;
        expect(
          resting.borderRadius,
          BorderRadius.circular(AppDimensions.minTouchTarget / 2),
        );
        expect(resting.borderSide.color, cs.outline);
        expect(resting.borderSide.width, AppDimensions.borderWidthStandard);
      });

      testWidgets('keeps its edge at focus', (
        tester,
      ) async {
        await _pump(tester, theme);

        final decoration = _decoration(tester);
        expect(decoration.focusedBorder, decoration.enabledBorder);
        expect(decoration.border, decoration.enabledBorder);
      });

      testWidgets('takes the theme fill', (tester) async {
        await _pump(tester, theme);

        // The field leaves filled and fillColor to the input theme.
        expect(_decoration(tester).filled, isNull);
        expect(_decoration(tester).fillColor, isNull);
        expect(theme.inputDecorationTheme.filled, isTrue);
      });

      testWidgets('disabled: the surface.disabled edge', (tester) async {
        await _pump(tester, theme, enabled: false);

        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        final disabled =
            _decoration(tester).disabledBorder! as OutlineInputBorder;
        expect(
          disabled.borderSide.color,
          AppModeColors.surfaceDisabled(cs.brightness),
        );
      });
    });
  }

  group('ButleryComposerField growth', () {
    testWidgets('is one touch target tall when empty', (tester) async {
      await _pump(tester, AppTheme.lightTheme);

      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(AppDimensions.minTouchTarget),
      );
    });

    testWidgets('grows to four lines, then scrolls inside', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(tester, AppTheme.lightTheme, controller: controller);
      final oneLine = tester.getSize(find.byType(TextField)).height;

      controller.text = 'a\nb\nc\nd';
      await tester.pump();
      final fourLines = tester.getSize(find.byType(TextField)).height;
      expect(fourLines, greaterThan(oneLine));

      controller.text = 'a\nb\nc\nd\ne\nf\ng\nh';
      await tester.pump();
      expect(tester.getSize(find.byType(TextField)).height, fourLines);
    });
  });
}
