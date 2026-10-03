// BUT-2207: the info state's default icon is text.primary (onSurface). It
// was cs.primary, which is surface.ink in dark mode: ink on the dark surface.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/state/message_states.dart';

Widget _wrap(ThemeData theme) => MaterialApp(
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(
    body: Builder(
      builder: (context) =>
          MessageStates.buildInfoState(context, title: 'Inget här'),
    ),
  ),
);

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('the default info icon is text.primary ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(theme));
      final icon = tester.widget<ButleryIcon>(find.byType(ButleryIcon));
      expect(icon.color, theme.colorScheme.onSurface);
    });
  }

  testWidgets('in dark mode the default info icon is not surface.ink', (
    tester,
  ) async {
    final theme = AppTheme.darkTheme;
    await tester.pumpWidget(_wrap(theme));
    final icon = tester.widget<ButleryIcon>(find.byType(ButleryIcon));
    expect(icon.color, isNot(theme.colorScheme.primary));
  });
}
