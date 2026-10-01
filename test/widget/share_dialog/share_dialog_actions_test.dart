// BUT-2183: the selection summary of the share dialog is a tinted notice
// (B83-2 = A: tint fill, no border), and the warning one carries text.warning,
// not the status-warning colour that fails AA as text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/share_dialog/share_dialog_actions.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  BoxDecoration decorationAround(WidgetTester tester, Finder of) => tester
      .widgetList<Container>(
        find.ancestor(of: of, matching: find.byType(Container)),
      )
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.color != null);

  Future<void> pumpSummary(
    WidgetTester tester,
    ThemeData theme,
    int selectedCount,
  ) => tester.pumpWidget(
    createLocalizedTestApp(
      child: Theme(
        data: theme,
        child: Builder(
          builder: (context) => ShareDialogActions.buildSelectionSummary(
            context,
            selectedCount,
            'recept',
          ),
        ),
      ),
    ),
  );

  group('ShareDialogActions.buildSelectionSummary', () {
    for (final (name, theme, tint, warningText, successTint) in [
      (
        'light',
        AppTheme.lightTheme,
        const Color(0xFFF0EEE2),
        const Color(0xFF8A5212),
        const Color(0xFFDFE8DC),
      ),
      (
        'dark',
        AppTheme.darkTheme,
        const Color(0xFF2F4437),
        const Color(0xFFDCA968),
        const Color(0xFF2F4437),
      ),
    ]) {
      testWidgets(
        '$name: no selection is surface.tint.warning with text.warning',
        (
          tester,
        ) async {
          await pumpSummary(tester, theme, 0);

          final label = find.text('Välj minst en vän för att dela');
          expect(label, findsOneWidget);
          final box = decorationAround(tester, label);
          expect(box.color, tint);
          expect(box.border, isNull);
          expect(tester.widget<Text>(label).style?.color, warningText);
        },
      );

      testWidgets('$name: a selection is surface.tint.success, no border', (
        tester,
      ) async {
        await pumpSummary(tester, theme, 2);

        final box = decorationAround(tester, find.byType(Text));
        expect(box.color, successTint);
        expect(box.border, isNull);
      });
    }
  });
}
