/// Pins the hero (saffron) button style to its token pairs and guards the
/// ink primaries against drifting to saffron (decision D4).
///
/// Sources: tokens.json:81-91,
/// :137-144 and the contrast pairs at :657-666.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/button_themes.dart';

const _saffron = Color(0xFFD68523);
const _saffronPressed = Color(0xFF9A5C14);
const _inkDeep = Color(0xFF17251D);
const _paper = Color(0xFFF5F4ED);
const _ink = Color(0xFF24382C);
const _greenLight = Color(0xFF8FB89A);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final t in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    group('hero style, ${t.brightness}', () {
      final style = ButtonThemes.heroButtonStyle(t.colorScheme);
      Color? bg(Set<WidgetState> s) => style.backgroundColor!.resolve(s);
      Color? fg(Set<WidgetState> s) => style.foregroundColor!.resolve(s);
      const pressed = {WidgetState.pressed};

      test('rests on saffron with deep ink text', () {
        expect(bg({}), _saffron);
        expect(fg({}), _inkDeep);
        expect(bg({}), AppColors.actionPrimary);
      });

      test('pressed switches both to paper on deep saffron', () {
        expect(bg(pressed), _saffronPressed);
        expect(fg(pressed), _paper);
      });

      test('both pairs meet 4.5:1, and the crossed pairs would not', () {
        expect(_contrast(fg({})!, bg({})!), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(fg(pressed)!, bg(pressed)!),
          greaterThanOrEqualTo(4.5),
        );
        // Why the pair must switch together (B-14).
        expect(_contrast(_inkDeep, _saffronPressed), lessThan(4.5));
        expect(_contrast(_paper, _saffron), lessThan(4.5));
      });

      test('the pair switches at once, without an ink tint on press', () {
        expect(style.animationDuration, Duration.zero);
        expect(style.overlayColor!.resolve(pressed), Colors.transparent);
        expect(
          style.overlayColor!.resolve({WidgetState.focused}),
          Colors.transparent,
        );
      });

      test('disabled is the filled disabled state, and focus the ring', () {
        const disabled = {WidgetState.disabled};
        expect(bg(disabled), isNot(_saffron));
        expect(bg(disabled)!.a, 1.0);
        expect(style.backgroundBuilder, isNotNull);
      });

      test('dark draws a paperWash edge at rest, light and disabled none', () {
        final rest = style.side!.resolve({});
        if (t.brightness == Brightness.dark) {
          expect(rest!.width, 1.5);
          expect(rest.color, AppModeColors.paperWash(Brightness.dark));
        } else {
          expect(rest, isNull);
        }
        expect(style.side!.resolve({WidgetState.disabled}), isNull);
      });

      test(
        'the primaries take action.fill: ink in light, greenLight in dark',
        () {
          final cs = t.colorScheme;
          final fill = t.brightness == Brightness.dark ? _greenLight : _ink;
          expect(cs.primary, _ink);
          expect(
            t.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
            fill,
          );
          expect(t.filledButtonTheme.style!.backgroundColor!.resolve({}), fill);
          expect(
            ButtonThemes.primaryButtonStyle(cs).backgroundColor!.resolve({}),
            fill,
          );
          expect(
            ButtonThemes.extendedFabStyle(cs).backgroundColor!.resolve({}),
            fill,
          );
          expect(t.floatingActionButtonTheme.backgroundColor, fill);
        },
      );
    });
  }

  test('ThemeData.highlightColor is the pressed step on raised (BUT-2205)', () {
    expect(AppTheme.lightTheme.highlightColor, const Color(0xFFB4BFA6));
    expect(AppTheme.darkTheme.highlightColor, const Color(0xFF17251D));
  });

  testWidgets('a pressed hero button paints paper on deep saffron', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: ElevatedButton(
                style: ButtonThemes.heroButtonStyle(
                  AppTheme.lightTheme.colorScheme,
                ),
                onPressed: () {},
                child: const Text('Spara recept'),
              ),
            ),
          ),
        ),
      ),
    );
    Material material() => tester.widget<Material>(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Material),
      ),
    );
    expect(material().color, _saffron);
    expect(material().textStyle?.color, _inkDeep);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ElevatedButton)),
    );
    await tester.pump();
    expect(material().color, _saffronPressed);
    expect(material().textStyle?.color, _paper);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(material().color, _saffron);
    expect(material().textStyle?.color, _inkDeep);
  });
}
