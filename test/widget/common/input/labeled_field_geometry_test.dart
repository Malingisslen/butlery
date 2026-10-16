import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/butlery_field_border.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/input/labeled_field.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final mode = theme.brightness.name;

    Future<void> pump(WidgetTester tester, Widget field) => tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: field),
        ),
      ),
    );

    Rect drawnBox(WidgetTester tester) => textFieldInputBox(
      tester.renderObject<RenderBox>(find.byType(LabeledField)),
      visual: true,
    )!;

    testWidgets('$mode: the field is 48 tall and its box is drawn 40', (
      tester,
    ) async {
      await pump(tester, const LabeledField(child: TextField()));
      expect(
        tester.getSize(find.byType(TextField)).height,
        AppDimensions.minTouchTarget,
      );
      final box = drawnBox(tester);
      expect(box.height, AppDimensions.controlVisualHeight);
      expect(box.center.dy, AppDimensions.minTouchTarget / 2);
    });

    testWidgets('$mode: a bare field takes the theme border that draws 40', (
      tester,
    ) async {
      await pump(tester, const LabeledField(child: TextField()));
      final theme = Theme.of(tester.element(find.byType(LabeledField)));
      final themed = theme.inputDecorationTheme;
      for (final border in [
        themed.enabledBorder,
        themed.focusedBorder,
        themed.errorBorder,
        themed.focusedErrorBorder,
        themed.disabledBorder,
      ]) {
        expect(border, isA<ButleryFieldBorder>());
      }
    });

    testWidgets('$mode: the semantics node of the field is 48', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const LabeledField(child: TextField()));
      final node = tester.getSemantics(find.byType(EditableText));
      expect(node.rect.height, AppDimensions.minTouchTarget);
      handle.dispose();
    });

    testWidgets('$mode: a tap above or below the drawn box focuses it', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pump(tester, LabeledField(child: TextField(focusNode: focus)));
      final field = tester.getRect(find.byType(TextField));

      for (final y in [field.top + 2, field.bottom - 2]) {
        focus.unfocus();
        await tester.pump();
        await tester.tapAt(Offset(field.center.dx, y));
        await tester.pump();
        expect(focus.hasFocus, isTrue, reason: 'tap at y=$y');
      }
    });

    testWidgets('$mode: StyledInput is 48 tall with its box drawn 40', (
      tester,
    ) async {
      await pump(tester, const StyledInput.text(hint: 'Namn'));
      expect(
        tester.getSize(find.byType(TextField)).height,
        AppDimensions.minTouchTarget,
      );
      final box = textFieldInputBox(
        tester.renderObject<RenderBox>(find.byType(LabeledField)),
        visual: true,
      )!;
      expect(box.height, AppDimensions.controlVisualHeight);
      // The ring reads the box as ButleryFieldBorder draws it, so the
      // field's own border must be one.
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(decoration.enabledBorder, isA<ButleryFieldBorder>());
      expect(decoration.focusedBorder, isA<ButleryFieldBorder>());
    });

    testWidgets('$mode: a field taller than the touch target is drawn whole', (
      tester,
    ) async {
      await pump(
        tester,
        const LabeledField(child: TextField(minLines: 3, maxLines: 3)),
      );
      final field = tester.getRect(find.byType(TextField));
      expect(field.height, greaterThan(AppDimensions.minTouchTarget));
      expect(drawnBox(tester).height, field.height);
    });
  }
}
