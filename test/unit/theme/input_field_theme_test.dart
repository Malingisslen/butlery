// The app's input theme draws the field Komponentark v1 §07 and §11 specify:
// paper with a 1 px border.control edge at rest, surface.raised only when
// disabled, a 1.5 px danger edge in error. The rest edge must clear 3:1
// against the paper it sits on (WCAG 1.4.11), in both modes.

import 'dart:math' as math;

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _fill(ThemeData t, Set<WidgetState> states) =>
    WidgetStateProperty.resolveAs(t.inputDecorationTheme.fillColor!, states);

BorderSide _side(InputBorder? b) => (b! as OutlineInputBorder).borderSide;

void main() {
  for (final entry in {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  }.entries) {
    final t = entry.value;
    final cs = t.colorScheme;
    final theme = t.inputDecorationTheme;

    group('${entry.key} field', () {
      test('rests on paper; surface.raised is the disabled fill', () {
        expect(_fill(t, {}), cs.surface);
        expect(_fill(t, {WidgetState.focused}), cs.surface);
        expect(_fill(t, {WidgetState.disabled}), cs.surfaceContainerHighest);
      });

      test('the rest edge is border.control at 1 px and clears 3:1', () {
        final side = _side(theme.enabledBorder);
        expect(side.color, cs.outline);
        expect(side.width, AppDimensions.borderWidthStandard);
        // The dark edge is translucent paper; measure what is drawn.
        final drawn = Color.alphaBlend(side.color, cs.surface);
        expect(_contrast(drawn, cs.surface), greaterThanOrEqualTo(3.0));
      });

      test('hover shares the disabled fill, so the edge tells them apart', () {
        expect(theme.hoverColor, cs.surfaceContainerHighest);
        expect(
          _side(theme.disabledBorder).color,
          AppModeColors.surfaceDisabled(cs.brightness),
        );
        expect(
          _side(theme.disabledBorder).color,
          isNot(_side(theme.enabledBorder).color),
        );
      });

      test('an error is a 1.5 px danger edge', () {
        final side = _side(theme.errorBorder);
        expect(side.color, cs.error);
        expect(side.width, AppDimensions.borderWidthOutlinedEdge);
      });
    });
  }
}
