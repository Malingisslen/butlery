// The view's one saffron action (Komponentark v1:843-844) and its busy
// state (v1:365, :372): shape and name kept, the plate line along the
// bottom edge, never disabled while it works.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
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

  testWidgets('the busy line is cut to the button corners', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: HeroButton(label: 'Generera', busy: true, onPressed: () {}),
      ),
    );
    await tester.pump();

    final clip = tester.widget<ClipPath>(
      find.ancestor(
        of: find.byType(ButtonPlateLine),
        matching: find.byType(ClipPath),
      ),
    );
    final size = tester.getSize(find.byType(FilledButton));
    final path = clip.clipper!.getClip(size);

    expect(path.contains(Offset(0.5, size.height - 0.5)), isFalse);
    expect(path.contains(Offset(size.width - 0.5, size.height - 0.5)), isFalse);
    expect(path.contains(Offset(size.width / 2, size.height - 0.5)), isTrue);
  });

  testWidgets('the busy label stays centred in the button', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: SizedBox(
          width: 320,
          child: HeroButton(
            label: 'Generera',
            busy: true,
            expand: true,
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final button = tester.getRect(find.byType(FilledButton));
    final label = tester.getCenter(find.text('Generera'));

    expect((label.dx - button.center.dx).abs(), lessThan(1));
    expect((label.dy - button.center.dy).abs(), lessThan(1));
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

  testWidgets('minimumSize replaces the hero minimum', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Row(
          children: [
            HeroButton(
              label: 'Nästa',
              minimumSize: const Size(0, 48),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
    expect(style.minimumSize!.resolve(const {}), const Size(0, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('iconAtEnd puts the icon after the label', (tester) async {
    Widget app({required bool atEnd}) => createLocalizedTestApp(
      child: HeroButton(
        label: 'Nästa',
        icon: ButleryIcons.arrowRight,
        iconAtEnd: atEnd,
        onPressed: () {},
      ),
    );
    double iconMinusLabel() =>
        tester.getCenter(find.byType(ButleryIcon)).dx -
        tester.getCenter(find.text('Nästa')).dx;
    await tester.pumpWidget(app(atEnd: true));
    expect(iconMinusLabel(), greaterThan(0));
    await tester.pumpWidget(app(atEnd: false));
    expect(iconMinusLabel(), lessThan(0));
  });

  testWidgets('content is the face while idle and the label while busy', (
    tester,
  ) async {
    Widget app({required bool busy}) => createLocalizedTestApp(
      child: HeroButton(
        label: 'Snabbspara',
        content: const Text('Två rader'),
        busy: busy,
        onPressed: () {},
      ),
    );
    await tester.pumpWidget(app(busy: false));
    expect(find.text('Två rader'), findsOneWidget);
    await tester.pumpWidget(app(busy: true));
    expect(find.text('Två rader'), findsNothing);
    expect(find.text('Snabbspara'), findsOneWidget);
  });

  // B-158: the primary action on a form or an account page is the dark green
  // button; it shares the hero's face and busy behaviour.
  group('FormButton', () {
    for (final dark in [false, true]) {
      testWidgets('FormButton rests on the filled button colours '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: FormButton(label: 'Spara', onPressed: () {}),
            ),
          ),
        );
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(Material),
          ),
        );
        final filled = theme.filledButtonTheme.style!.backgroundColor!.resolve(
          const {},
        );
        final hero = ComponentThemes.heroButtonStyle(
          theme.colorScheme,
        ).backgroundColor!.resolve(const {});
        expect(material.color, filled);
        expect(material.color, isNot(hero));
      });
    }

    testWidgets('FormButton busy keeps the name and does nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FormButton(
            label: 'Spara',
            busyLabel: 'Sparar …',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ButtonPlateLine), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(FormButton)),
        containsSemantics(label: 'Sparar …', isButton: true),
      );
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
      handle.dispose();
    });

    testWidgets(
      'FormButton idle runs its action and a null action disables it',
      (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: FormButton(label: 'Klar', onPressed: () => taps++),
          ),
        );
        await tester.tap(find.text('Klar'));
        expect(taps, 1);
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const FormButton(label: 'Klar', onPressed: null),
          ),
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      },
    );
  });
}
