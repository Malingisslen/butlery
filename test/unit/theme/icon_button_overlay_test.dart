/// Pins the icon-button overlay to surface.raised on pressed and hovered
/// (B83-1 = A, BUT-2183, produktbeslut-2026-09-30.json): "Tryck och
/// muspekare på rader, kort och ikonknappar ger samma upphöjda färg
/// överallt, surface.raised ... Flutters genomskinliga gråton används inte."
/// Filled/outlined/text/elevated buttons are NOT part of this decision and
/// must keep the shared no-tint overlay (`_noFocusTint`): focus alone
/// carries the ring, and pressed/hovered fall through to Material's default.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/button_themes.dart';

void main() {
  for (final t in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    group('icon button overlay, ${t.brightness}', () {
      final cs = t.colorScheme;
      final overlay = ButtonThemes.iconButtonTheme(cs).style!.overlayColor!;

      test('pressed resolves to surface.raised', () {
        expect(
          overlay.resolve({WidgetState.pressed}),
          cs.surfaceContainerHighest,
        );
      });

      test('hovered resolves to surface.raised', () {
        expect(
          overlay.resolve({WidgetState.hovered}),
          cs.surfaceContainerHighest,
        );
      });

      test('pressed AND hovered together still resolve to surface.raised', () {
        expect(
          overlay.resolve({WidgetState.pressed, WidgetState.hovered}),
          cs.surfaceContainerHighest,
        );
      });

      test('a focused button that is pressed or hovered still resolves to '
          'surface.raised', () {
        expect(
          overlay.resolve({WidgetState.focused, WidgetState.pressed}),
          cs.surfaceContainerHighest,
        );
        expect(
          overlay.resolve({WidgetState.focused, WidgetState.hovered}),
          cs.surfaceContainerHighest,
        );
      });

      test('focused keeps the shared no-tint behaviour (the ring alone)', () {
        expect(overlay.resolve({WidgetState.focused}), Colors.transparent);
      });

      test('no interaction state resolves to null (Material default)', () {
        expect(overlay.resolve({}), isNull);
      });
    });
  }

  test(
    'filled/outlined/text/elevated buttons are untouched: pressed/hovered '
    'still fall through to null, never surface.raised',
    () {
      final cs = AppTheme.lightTheme.colorScheme;
      for (final overlay in [
        ButtonThemes.elevatedButtonTheme(cs).style!.overlayColor!,
        ButtonThemes.filledButtonTheme(cs).style!.overlayColor!,
        ButtonThemes.outlinedButtonTheme(cs).style!.overlayColor!,
        ButtonThemes.textButtonTheme(cs).style!.overlayColor!,
      ]) {
        expect(overlay.resolve({WidgetState.pressed}), isNull);
        expect(overlay.resolve({WidgetState.hovered}), isNull);
        expect(overlay.resolve({WidgetState.focused}), Colors.transparent);
      }
    },
  );

  testWidgets(
    "the app theme's wired IconButtonThemeData resolves the same way "
    '(end-to-end: app_theme.dart -> ComponentThemes -> ButtonThemes)',
    (tester) async {
      late ColorScheme cs;
      late IconButtonThemeData themed;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                cs = Theme.of(context).colorScheme;
                themed = Theme.of(context).iconButtonTheme;
                return const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.star),
                );
              },
            ),
          ),
        ),
      );

      final overlay = themed.style!.overlayColor!;
      expect(
        overlay.resolve({WidgetState.pressed}),
        cs.surfaceContainerHighest,
      );
      expect(
        overlay.resolve({WidgetState.hovered}),
        cs.surfaceContainerHighest,
      );
    },
  );
}
