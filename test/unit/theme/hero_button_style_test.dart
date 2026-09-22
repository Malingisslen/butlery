/// Pins the hero (saffron) button style to its token pairs and guards the
/// ink primaries against drifting to saffron (decision D4).
///
/// Sources: Komponentark v1:370-373 and :843-844; tokens.json:81-91,
/// :137-144 and the contrast pairs at :657-666; beslutslogg B-14.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/button_themes.dart';

const _saffron = Color(0xFFCE7C1E);
const _saffronPressed = Color(0xFF9A5C14);
const _inkDeep = Color(0xFF17251D);
const _paper = Color(0xFFF5F4ED);
const _ink = Color(0xFF24382C);

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

      test('the ink primaries stay ink', () {
        final cs = t.colorScheme;
        expect(cs.primary, _ink);
        expect(t.elevatedButtonTheme.style!.backgroundColor!.resolve({}), _ink);
        expect(t.filledButtonTheme.style!.backgroundColor!.resolve({}), _ink);
        expect(
          ButtonThemes.primaryButtonStyle(cs).backgroundColor!.resolve({}),
          _ink,
        );
        expect(
          ButtonThemes.extendedFabStyle(cs).backgroundColor!.resolve({}),
          _ink,
        );
        expect(t.floatingActionButtonTheme.backgroundColor, _ink);
      });
    });
  }

  test('ThemeData.highlightColor is untouched (D4)', () {
    expect(
      AppTheme.lightTheme.highlightColor,
      AppColors.rust.withValues(alpha: 0.12),
    );
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
