/// The busy button (P4-U01): Komponentark v1:307, :365, :372; Grafisk manual
/// v6:423; produktregler.md:902.
///
/// A busy button keeps its surface and its name, or says what it does
/// ("Sparar …"), and gets the plate line along its bottom edge: 4 px, the
/// button's own text colour on a track of that colour at 18 %. Never a
/// spinner, never "Laddar …". It is one semantics node, read once.
library;

import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/button_themes.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

enum _Variant { hero, inkPrimary, outline }

Widget _button(BuildContext context, _Variant v) {
  switch (v) {
    case _Variant.hero:
      final theme = Theme.of(context);
      return BusyButtonSemantics(
        busy: true,
        name: 'Spara recept',
        busyLabel: 'Sparar …',
        child: ElevatedButton(
          onPressed: PlateLineButton.ignore,
          style: PlateLineButton.busyStyle(
            ButtonThemes.heroButtonStyle(theme.colorScheme),
            theme.elevatedButtonTheme.style,
          ),
          child: const Text('Sparar …'),
        ),
      );
    case _Variant.inkPrimary:
      return ActionButtons.primaryButton(
        context,
        label: 'Spara recept',
        loadingText: 'Sparar …',
        isLoading: true,
        isExpanded: true,
        onPressed: () {},
      );
    case _Variant.outline:
      return ActionButtons.outlinedButton(
        context,
        label: 'Spara recept',
        loadingText: 'Sparar …',
        isLoading: true,
        isExpanded: true,
        onPressed: () {},
      );
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Variant v, {
  required ThemeData theme,
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: Builder(builder: (c) => _button(c, v)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

final Finder _anyButton = find.byWidgetPredicate((w) => w is ButtonStyleButton);

Finder _buttonMaterial() =>
    find.descendant(of: _anyButton, matching: find.byType(Material)).first;

Color? _textColor(WidgetTester tester) => tester
    .widget<RichText>(
      find.descendant(of: _anyButton, matching: find.byType(RichText)),
    )
    .text
    .style
    ?.color;

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    for (final v in _Variant.values) {
      group('${v.name} in $mode', () {
        testWidgets('the line lies along the bottom edge, 4 px, full width', (
          tester,
        ) async {
          await _pump(tester, v, theme: theme);
          final button = tester.getRect(_buttonMaterial());
          final track = tester.getRect(find.byKey(ButtonPlateLine.trackKey));
          expect(track.height, PlateLine.thickness);
          expect(track.bottom, closeTo(button.bottom, 0.01));
          expect(track.left, closeTo(button.left, 0.01));
          expect(track.width, closeTo(button.width, 0.01));
          final seg = tester.getRect(find.byKey(ButtonPlateLine.segmentKey));
          expect(seg.left, closeTo(button.left, 0.01));
          expect(
            seg.width,
            closeTo(button.width * ButtonPlateLine.segmentWidth, 0.01),
          );
        });

        testWidgets('the line is the button text colour; its track follows '
            'the opacity ladder', (tester) async {
          await _pump(tester, v, theme: theme);
          final fg = _textColor(tester)!;
          final seg =
              tester
                      .widget<DecoratedBox>(
                        find.byKey(ButtonPlateLine.segmentKey),
                      )
                      .decoration
                  as BoxDecoration;
          expect(seg.color, fg);
          final track = tester
              .widget<ColoredBox>(find.byKey(ButtonPlateLine.trackKey))
              .color;
          if (v == _Variant.outline) {
            // On paper the ladder allows only 0.02 and 0.04 (tokens.json
            // opacityLadder), so an unfilled button's track is token
            // progressTrack: #E6EAD9 light, rgba(245,244,237,0.18) dark.
            expect(
              track,
              mode == 'light'
                  ? const Color(0xFFE6EAD9)
                  : const Color(0x2EF5F4ED),
            );
            expect(track, isNot(fg.withValues(alpha: 0.18)));
          } else {
            // A filled button: its foreground on 18 % (opacityLadder.onInk).
            expect(track, fg.withValues(alpha: ButtonPlateLine.trackAlpha));
          }
          if (v == _Variant.hero) {
            // Komponentark v1:372: ink #17251D on saffron #CE7C1E.
            expect(fg, const Color(0xFF17251D));
            expect(
              tester.widget<Material>(_buttonMaterial()).color,
              const Color(0xFFCE7C1E),
            );
          }
        });

        testWidgets('keeps its surface, shows the busy label, no spinner', (
          tester,
        ) async {
          await _pump(tester, v, theme: theme);
          expect(find.text('Sparar …'), findsOneWidget);
          expect(find.text('Laddar …'), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          // Busy is not disabled: the button is enabled for Flutter, so it
          // keeps its surface and colours (Komponentark v1:365).
          final b = tester.widget<ButtonStyleButton>(_anyButton);
          expect(b.enabled, isTrue);
        });

        testWidgets('one semantics node, busy label, not activatable', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await _pump(tester, v, theme: theme);
          expect(find.bySemanticsLabel('Sparar …'), findsOneWidget);
          final data = tester
              .getSemantics(find.bySemanticsLabel('Sparar …'))
              .getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.flagsCollection.isEnabled, Tristate.isFalse);
          expect(data.value, isEmpty, reason: 'the label already says it');
          handle.dispose();
        });
      });
    }
  }

  testWidgets('without a busy label the button keeps its name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => ActionButtons.primaryButton(
            context,
            label: 'Spara recept',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Spara recept'), findsOneWidget);
    expect(find.text('Laddar …'), findsNothing);
    final data = tester
        .getSemantics(find.bySemanticsLabel('Spara recept'))
        .getSemanticsData();
    // The busy state is machine-readable (Komponentark v1:365).
    expect(data.value, 'Laddar');
    handle.dispose();
  });

  testWidgets('presses do nothing while busy', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => ActionButtons.primaryButton(
            context,
            label: 'Spara',
            isLoading: true,
            onPressed: () => pressed++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Spara'), warnIfMissed: false);
    await tester.pump();
    expect(pressed, 0);
  });

  testWidgets('the line pulses in place and stands still on reduced motion', (
    tester,
  ) async {
    await _pump(tester, _Variant.hero, theme: AppTheme.lightTheme);
    expect(tester.hasRunningAnimations, isTrue);
    final start = tester.getRect(find.byKey(ButtonPlateLine.segmentKey));
    await tester.pump(PlateLine.pulseHalfCycle);
    expect(tester.getRect(find.byKey(ButtonPlateLine.segmentKey)), start);

    await _pump(
      tester,
      _Variant.hero,
      theme: AppTheme.lightTheme,
      reduceMotion: true,
    );
    await tester.pump(PlateLine.pulseHalfCycle);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
