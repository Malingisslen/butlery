// BUT-2155: a chosen chip's label is paper on the ink fill in both modes, and
// the progress theme carries the progress tokens in both modes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';

Color? _label(ThemeData theme, Set<WidgetState> states) {
  final color = theme.chipTheme.labelStyle!.color!;
  return color is WidgetStateColor ? color.resolve(states) : color;
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    test('a chosen chip label is onPrimary on the primary fill ($name)', () {
      final cs = theme.colorScheme;
      expect(theme.chipTheme.selectedColor, cs.primary);
      expect(_label(theme, {WidgetState.selected}), cs.onPrimary);
      expect(_label(theme, {}), cs.onSurface);
      expect(
        _label(theme, {WidgetState.selected, WidgetState.disabled}),
        cs.onPrimary,
      );
    });
  }

  test('the progress theme is saffron on its track in both modes', () {
    final light = AppTheme.lightTheme.progressIndicatorTheme;
    final dark = AppTheme.darkTheme.progressIndicatorTheme;
    expect(light.color, AppColors.progressIndicator);
    expect(light.linearTrackColor, AppColors.progressTrack);
    expect(light.circularTrackColor, AppColors.progressTrack);
    expect(dark.color, AppColorsDark.progressIndicator);
    expect(dark.linearTrackColor, AppColorsDark.progressTrack);
  });
}
