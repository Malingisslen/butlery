// BUT-2183 5n: the conflict field card leaves the old opacity steps. Each
// value row is the mode's surface tint (success for the user's version,
// warning for the collaborator's) with the 4 px accent bar kept; the label
// above the value is the on-colour text of its kind, never the status colour
// itself. Runs in both modes and asserts fills, bars and text colours.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/realtime/conflict_diff_view.dart';

late AppLocalizations _sv;

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(
        body: ConflictDiffFieldCard(
          field: ConflictFieldDiff(
            fieldKey: 'title',
            localText: 'Min titel',
            remoteText: 'Deras titel',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

BoxDecoration _rowAbove(WidgetTester tester, Finder of) =>
    tester
            .widget<Container>(
              find
                  .ancestor(
                    of: of,
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is Container &&
                          w.decoration is BoxDecoration &&
                          (w.decoration! as BoxDecoration).border != null,
                    ),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

Color? _color(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

void main() {
  setUpAll(() async {
    _sv = await AppLocalizations.delegate.load(const Locale('sv', 'SE'));
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    group('conflict field card, $mode', () {
      testWidgets(
        'the user\'s version is the success tint with a success bar and an '
        'onSuccessContainer label',
        (tester) async {
          await _pump(tester, theme);

          final label = find.text(_sv.conflictDiffLocalLabel);
          final row = _rowAbove(tester, label);
          expect(row.color, modeColors.surfaceTintSuccess);
          expect(
            (row.border! as Border).left.color,
            modeColors.success,
          );
          expect(_color(tester, label), modeColors.onSuccessContainer);
          expect(_color(tester, find.text('Min titel')), cs.onSurface);
        },
      );

      testWidgets(
        'the collaborator\'s version is the warning tint with a warning bar '
        'and a text.warning label',
        (tester) async {
          await _pump(tester, theme);

          final label = find.text(_sv.conflictDiffRemoteLabel);
          final row = _rowAbove(tester, label);
          expect(row.color, modeColors.surfaceTintWarning);
          expect(
            (row.border! as Border).left.color,
            modeColors.warning,
          );
          expect(
            _color(tester, label),
            AppModeColors.textWarning(theme.brightness),
          );
          expect(_color(tester, find.text('Deras titel')), cs.onSurface);
        },
      );
    });
  }
}
