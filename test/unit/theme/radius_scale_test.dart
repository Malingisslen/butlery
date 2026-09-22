/// Pins the theme layer to the canonical radius scale (tokens.json
/// space.radius: sharp 0, knob 2, control 8, card 12, pill 999, plus the
/// checkbox's locked 6 from controls.checkbox.radius).
///
/// Buttons and fields are control 8, cards are card 12, chips are pill,
/// sheets round only their top edge at 12, and the checkbox is 6. Radius does
/// not depend on the mode, so every assertion runs for both themes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';

BorderRadius _radiusOf(OutlinedBorder? shape) {
  expect(shape, isA<RoundedRectangleBorder>());
  return (shape! as RoundedRectangleBorder).borderRadius.resolve(
    TextDirection.ltr,
  );
}

OutlinedBorder? _buttonShape(ButtonStyle? style) =>
    style?.shape?.resolve(<WidgetState>{});

void main() {
  const control = BorderRadius.all(Radius.circular(8));
  const card = BorderRadius.all(Radius.circular(12));

  for (final entry in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    final mode = entry.key;
    final theme = entry.value;

    group('radius scale in the $mode theme', () {
      test('buttons take the control radius, 8', () {
        expect(
          _radiusOf(_buttonShape(theme.elevatedButtonTheme.style)),
          control,
        );
        expect(
          _radiusOf(_buttonShape(theme.filledButtonTheme.style)),
          control,
        );
        expect(
          _radiusOf(_buttonShape(theme.outlinedButtonTheme.style)),
          control,
        );
        expect(_radiusOf(_buttonShape(theme.textButtonTheme.style)), control);
      });

      test('fields take the control radius, 8, in every border state', () {
        final input = theme.inputDecorationTheme;
        for (final border in [
          input.border,
          input.enabledBorder,
          input.focusedBorder,
          input.errorBorder,
          input.focusedErrorBorder,
        ]) {
          expect(border, isA<OutlineInputBorder>());
          expect((border! as OutlineInputBorder).borderRadius, control);
        }
      });

      test('cards take the card radius, 12', () {
        expect(_radiusOf(theme.cardTheme.shape as OutlinedBorder?), card);
      });

      test('chips are pills', () {
        expect(
          _radiusOf(theme.chipTheme.shape),
          const BorderRadius.all(Radius.circular(999)),
        );
      });

      test('sheets round the top edge at 12 and keep the bottom sharp', () {
        final radius = _radiusOf(
          theme.bottomSheetTheme.shape as OutlinedBorder?,
        );
        expect(radius.topLeft, const Radius.circular(12));
        expect(radius.topRight, const Radius.circular(12));
        expect(radius.bottomLeft, Radius.zero);
        expect(radius.bottomRight, Radius.zero);
      });

      test('the checkbox keeps its locked radius, 6', () {
        expect(
          _radiusOf(theme.checkboxTheme.shape),
          const BorderRadius.all(Radius.circular(6)),
        );
      });
    });
  }
}
