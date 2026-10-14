/// Megagenomgång A22: with no photo behind it a hero icon stands on the page,
/// so in dark mode it must read against the page (it was ink on a dark
/// surface, 1.27:1). Over a photo it keeps ink on the paper ring.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_hero_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}

Future<Color> _iconColor(
  WidgetTester tester, {
  required ThemeData theme,
  required bool ringVisible,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: RecipeHeroButton(
          icon: ButleryIcons.arrowLeft,
          onPressed: () {},
          tooltip: 'Tillbaka',
          ringVisible: ringVisible,
        ),
      ),
    ),
  );
  return tester.widget<ButleryIcon>(find.byType(ButleryIcon)).color!;
}

enum _Button { back, menu }

Future<void> _pumpButton(
  WidgetTester tester, {
  required ThemeData theme,
  required _Button button,
  required bool ringVisible,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: switch (button) {
            _Button.back => RecipeHeroButton(
              icon: ButleryIcons.arrowLeft,
              onPressed: () {},
              tooltip: 'Tillbaka',
              ringVisible: ringVisible,
            ),
            _Button.menu => RecipeHeroMenuButton<String>(
              icon: ButleryIcons.arrowLeft,
              tooltip: 'Meny',
              ringVisible: ringVisible,
              itemBuilder: (_) => const [],
              onSelected: (_) {},
            ),
          },
        ),
      ),
    ),
  );
}

Color _icon(WidgetTester tester) =>
    tester.widget<ButleryIcon>(find.byType(ButleryIcon)).color!;

Color _ring(WidgetTester tester) {
  final ring = tester.widget<Container>(
    find.byKey(const ValueKey('recipe-detail-paper-ring')),
  );
  return (ring.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('no photo, dark mode: the icon reads against the page', (
    tester,
  ) async {
    final theme = AppTheme.darkTheme;
    final color = await _iconColor(tester, theme: theme, ringVisible: false);

    expect(_contrast(color, theme.colorScheme.surface), greaterThan(4.5));
  });

  testWidgets('over a photo the icon stays ink on the paper ring, both modes', (
    tester,
  ) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final color = await _iconColor(tester, theme: theme, ringVisible: true);

      expect(color, theme.colorScheme.primary);
      expect(_contrast(color, theme.colorScheme.onPrimary), greaterThan(4.5));
    }
  });

  testWidgets('menu button, no photo, dark mode: the icon reads against the '
      'page', (tester) async {
    final theme = AppTheme.darkTheme;
    await _pumpButton(
      tester,
      theme: theme,
      button: _Button.menu,
      ringVisible: false,
    );

    expect(
      _contrast(_icon(tester), theme.colorScheme.surface),
      greaterThan(4.5),
    );
  });

  for (final button in _Button.values) {
    testWidgets('${button.name} button, no photo, dark mode: hovering puts the '
        'icon on the paper ring as ink', (tester) async {
      final theme = AppTheme.darkTheme;
      await _pumpButton(
        tester,
        theme: theme,
        button: button,
        ringVisible: false,
      );
      final bare = _icon(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(ButleryIcon)));
      await tester.pump();

      expect(_icon(tester), isNot(bare));
      expect(_icon(tester), theme.colorScheme.primary);
      expect(_contrast(_icon(tester), _ring(tester)), greaterThan(4.5));
    });

    testWidgets('${button.name} button, no photo, dark mode: pressing puts the '
        'icon on the paper ring as ink', (tester) async {
      final theme = AppTheme.darkTheme;
      await _pumpButton(
        tester,
        theme: theme,
        button: button,
        ringVisible: false,
      );

      final touch = await tester.startGesture(
        tester.getCenter(find.byType(ButleryIcon)),
      );
      // A tap recognizer reports the press after its press timeout.
      await tester.pump(kPressTimeout + const Duration(milliseconds: 50));

      expect(_icon(tester), theme.colorScheme.primary);
      expect(_contrast(_icon(tester), _ring(tester)), greaterThan(4.5));

      await touch.up();
      await tester.pumpAndSettle();
    });
  }
}
