// BUT-2371: the error state draws its glyph. buildErrorState took icon,
// iconColor and iconSize and drew none of them, so every StateWidget.error
// showed no error mark at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

Widget _wrap(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('the error state draws triangle-alert ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(theme, StateWidget.error(message: 'Listan kunde inte hämtas.')),
      );
      final icon = tester.widget<ButleryIcon>(find.byType(ButleryIcon));
      expect(icon.icon, ButleryIcons.triangleAlert);
      expect(icon.color, theme.colorScheme.error);
    });
  }

  testWidgets('the glyph sits above what happened', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppTheme.lightTheme,
        StateWidget.error(message: 'Listan kunde inte hämtas.'),
      ),
    );
    final glyph = tester.getRect(find.byType(ButleryIcon));
    final text = tester.getRect(find.text('Listan kunde inte hämtas.'));
    expect(glyph.bottom, lessThanOrEqualTo(text.top));
  });

  testWidgets('a caller may swap the glyph, for example to wifi-off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AppTheme.lightTheme,
        const StateWidget(
          type: StateType.error,
          message: 'Ingen anslutning.',
          icon: ButleryIcons.wifiOff,
        ),
      ),
    );
    final icon = tester.widget<ButleryIcon>(find.byType(ButleryIcon));
    expect(icon.icon, ButleryIcons.wifiOff);
  });

  testWidgets('the screen reader reads the text, not the glyph', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        AppTheme.lightTheme,
        StateWidget.error(message: 'Listan kunde inte hämtas.'),
      ),
    );
    expect(find.bySemanticsLabel('Listan kunde inte hämtas.'), findsOneWidget);
    handle.dispose();
  });
}
