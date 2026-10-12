import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';

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

    testWidgets('$mode: the box is drawn 40 and the frame is 48', (
      tester,
    ) async {
      await pump(tester, const LabeledField(child: TextField()));
      expect(
        tester.getSize(find.byType(TextField)).height,
        AppDimensions.controlVisualHeight,
      );
      expect(
        tester.getSize(find.byType(LabeledField)).height,
        AppDimensions.minTouchTarget,
      );
    });

    testWidgets('$mode: a tap in the pad above or below the box focuses it', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pump(tester, LabeledField(child: TextField(focusNode: focus)));
      final box = tester.getRect(find.byType(TextField));

      for (final y in [box.top - 2, box.bottom + 2]) {
        focus.unfocus();
        await tester.pump();
        await tester.tapAt(Offset(box.center.dx, y));
        await tester.pump();
        expect(focus.hasFocus, isTrue, reason: 'tap at y=$y');
      }
    });

    testWidgets('$mode: a tap on the box focuses it', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pump(tester, LabeledField(child: TextField(focusNode: focus)));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('$mode: a tap in the pad leaves a read-only field alone', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pump(
        tester,
        LabeledField(
          child: TextField(focusNode: focus, readOnly: true),
        ),
      );
      final box = tester.getRect(find.byType(TextField));
      await tester.tapAt(Offset(box.center.dx, box.top - 2));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });
  }
}
