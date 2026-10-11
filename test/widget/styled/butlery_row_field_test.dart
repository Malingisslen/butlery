// Row fields in editable lists: no box per row, a dividing line under it,
// and a limit without a counter (inmatningsfält riktning A, del 4).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/styled/butlery_row_field.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: SizedBox(width: 320, child: child)),
    ),
  );
}

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    group('ButleryRowField, $mode', () {
      testWidgets('draws no fill and no edge in any state', (tester) async {
        await _pump(
          tester,
          theme,
          const ButleryRowField(hintText: 'Ingrediens 1'),
        );

        final d = tester.widget<TextField>(find.byType(TextField)).decoration!;
        expect(d.filled, isFalse);
        for (final edge in [
          d.border,
          d.enabledBorder,
          d.focusedBorder,
          d.errorBorder,
          d.focusedErrorBorder,
          d.disabledBorder,
        ]) {
          expect(edge, InputBorder.none);
        }
      });

      testWidgets('the row has one dividing line, under it', (tester) async {
        await _pump(
          tester,
          theme,
          const ButleryFieldRow(
            children: [Expanded(child: ButleryRowField())],
          ),
        );

        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(ButleryFieldRow),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final border = (box.decoration as BoxDecoration).border! as Border;
        expect(border.bottom.color, cs.outlineVariant);
        expect(border.bottom.width, AppDimensions.borderWidthStandard);
        expect(border.top, BorderSide.none);
      });
    });
  }

  testWidgets('a row is at least one touch target tall', (tester) async {
    await _pump(
      tester,
      AppTheme.lightTheme,
      const ButleryFieldRow(children: [Text('x')]),
    );

    expect(
      tester.getSize(find.byType(ButleryFieldRow)).height,
      greaterThanOrEqualTo(AppDimensions.minTouchTarget),
    );
  });

  testWidgets('maxLength limits the text and shows no counter', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      AppTheme.lightTheme,
      ButleryRowField(controller: controller, maxLength: 5),
    );

    await tester.enterText(find.byType(TextField), 'abcdefgh');
    await tester.pump();

    expect(controller.text, 'abcde');
    expect(find.text('5/5'), findsNothing);
  });
}
