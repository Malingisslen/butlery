// The view's one saffron action (Komponentark v1:843-844) and its busy
// state (v1:365, :372): shape and name kept, the plate line along the
// bottom edge, never disabled while it works.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  // BUT-2219: a long name wraps instead of ending in "…".
  testWidgets('a very long label wraps instead of being cut', (tester) async {
    const long = 'Spara receptet och lägg till det i veckans meny direkt';
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: SizedBox(
          width: 150,
          child: HeroButton(label: long, onPressed: () {}),
        ),
      ),
    );
    final label = find.text(long);
    final text = tester.widget<Text>(label);
    expect(text.overflow, isNull);
    expect(text.maxLines, isNull);
    expect(tester.takeException(), isNull);
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(
      tester.getSize(label).height,
      greaterThan(paragraph.preferredLineHeight * 1.5),
    );
  });

  for (final dark in [false, true]) {
    testWidgets('rests on the hero colours (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: HeroButton(label: 'Generera', onPressed: () {}),
          ),
        ),
      );
      final hero = ComponentThemes.heroButtonStyle(theme.colorScheme);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, hero.backgroundColor!.resolve(const {}));
    });
  }

  testWidgets('busy keeps the name, shows the plate line, does nothing', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: HeroButton(
          label: 'Generera',
          busyLabel: 'Planerar veckan …',
          busy: true,
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ButtonPlateLine), findsOneWidget);
    expect(find.text('Planerar veckan …'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(HeroButton)),
      containsSemantics(label: 'Planerar veckan …', isButton: true),
    );
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(taps, 0);
    // Busy is not disabled: the button keeps its surface (v1:365).
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    handle.dispose();
  });

  testWidgets('idle runs its action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: HeroButton(label: 'Klar', onPressed: () => taps++),
      ),
    );
    await tester.tap(find.text('Klar'));
    expect(taps, 1);
    expect(find.byType(ButtonPlateLine), findsNothing);
  });
}
