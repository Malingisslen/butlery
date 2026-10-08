// BUT-2183: a chosen selection's summary is a tinted notice (tint fill, no
// border); with nothing chosen it is a neutral hint, not a warning.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
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
    for (final (name, theme, successTint) in [
      ('light', AppTheme.lightTheme, const Color(0xFFDFE8DC)),
      ('dark', AppTheme.darkTheme, const Color(0xFF2F4437)),
    ]) {
      testWidgets(
        '$name: no selection is a neutral hint with no glyph and no '
        'warning colour',
        (tester) async {
          await pumpSummary(tester, theme, 0);

          final label = find.text('Välj vem du vill dela med.');
          expect(label, findsOneWidget);
          expect(find.byWidgetPredicate((w) => w is Icon), findsNothing);
          final color = tester.widget<Text>(label).style?.color;
          expect(color, theme.colorScheme.onSurfaceVariant);
          expect(color, isNot(AppModeColors.textWarning(theme.brightness)));
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
