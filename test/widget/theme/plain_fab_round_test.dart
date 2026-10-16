/// The FAB theme draws a plain FloatingActionButton as a disc in both modes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';

void main() {
  final themes = {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  };

  Widget app(ThemeData theme, Widget Function(BuildContext) fab) {
    return MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) => Scaffold(
            body: const SizedBox.shrink(),
            floatingActionButton: fab(context),
          ),
        ),
      ),
    );
  }

  ShapeBorder fabShape(WidgetTester tester) {
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(FloatingActionButton),
            matching: find.byType(Material),
          )
          .first,
    );
    return material.shape!;
  }

  for (final entry in themes.entries) {
    testWidgets('plain FAB stays round (${entry.key})', (tester) async {
      await tester.pumpWidget(
        app(
          entry.value,
          (_) => FloatingActionButton(
            onPressed: () {},
            child: const ButleryIcon(ButleryIcons.plus),
          ),
        ),
      );
      expect(fabShape(tester), isA<CircleBorder>());
    });
  }
}
