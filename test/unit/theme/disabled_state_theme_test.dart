/// Pins the disabled state of the themed controls to the canonical tokens,
/// in both modes, and checks that no disabled colour is carried by opacity.
///
/// Sources: Komponentark v1:164 (radio), :174 (switch), :373 (filled
/// button), :383 (outlined button), :423 and :514 (field); Grafisk manual
/// v6:167 and :423; tokens.json surface.disabled, surface.raised,
/// text.secondary, text.disabled.onRaised.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/button_themes.dart';

const _disabled = <WidgetState>{WidgetState.disabled};
const _disabledSelected = <WidgetState>{
  WidgetState.disabled,
  WidgetState.selected,
};

class _Mode {
  const _Mode({
    required this.name,
    required this.theme,
    required this.surfaceDisabled,
    required this.surfaceRaised,
    required this.textSecondary,
    required this.textDisabled,
    required this.filledDisabledText,
  });

  final String name;
  final ThemeData theme;
  final Color surfaceDisabled;
  final Color surfaceRaised;
  final Color textSecondary;
  final Color textDisabled;
  final Color filledDisabledText;
}

void main() {
  final modes = [
    _Mode(
      name: 'light',
      theme: AppTheme.lightTheme,
      surfaceDisabled: const Color(0xFFA9B2A0),
      surfaceRaised: const Color(0xFFE6EAD9),
      textSecondary: const Color(0xFF627061),
      textDisabled: const Color(0xFF788477),
      filledDisabledText: const Color(0xFF24382C),
    ),
    _Mode(
      name: 'dark',
      theme: AppTheme.darkTheme,
      surfaceDisabled: const Color(0xFF4A5C50),
      surfaceRaised: const Color(0xFF2F4437),
      textSecondary: const Color(0xFF93A48D),
      textDisabled: const Color(0xFF93A48D),
      // Open decision: the drawn #93A48D has no token pair; paper is kept.
      filledDisabledText: const Color(0xFFF5F4ED),
    ),
  ];

  test('the expected values are the generated members', () {
    expect(modes[0].surfaceDisabled, AppColors.surfaceDisabled);
    expect(modes[1].surfaceDisabled, AppColorsDark.surfaceDisabled);
    expect(modes[0].textDisabled, AppColors.textDisabled);
    expect(modes[1].textDisabled, AppColorsDark.textDisabled);
  });

  for (final m in modes) {
    group('disabled state in the ${m.name} theme', () {
      final t = m.theme;

      test('filled and elevated buttons: surface.disabled with ink text', () {
        for (final style in [
          t.elevatedButtonTheme.style!,
          t.filledButtonTheme.style!,
          ButtonThemes.primaryButtonStyle(t.colorScheme),
          ButtonThemes.dangerButtonStyle(t.colorScheme),
        ]) {
          expect(style.backgroundColor!.resolve(_disabled), m.surfaceDisabled);
          expect(
            style.foregroundColor!.resolve(_disabled),
            m.filledDisabledText,
          );
        }
      });

      test('enabled filled buttons keep their ink rest colours', () {
        final style = t.filledButtonTheme.style!;
        expect(style.backgroundColor!.resolve({}), t.colorScheme.primary);
        expect(style.foregroundColor!.resolve({}), t.colorScheme.onPrimary);
      });

      test('outlined buttons: surface.disabled edge, text.secondary text', () {
        for (final style in [
          t.outlinedButtonTheme.style!,
          ButtonThemes.outlinedButtonStyleNamed(t.colorScheme),
          ButtonThemes.deleteButtonStyle(t.colorScheme),
          ButtonThemes.secondaryButtonStyle(t.colorScheme),
        ]) {
          final side = style.side!.resolve(_disabled)!;
          expect(side.color, m.surfaceDisabled);
          expect(side.width, 1.5);
          expect(style.foregroundColor!.resolve(_disabled), m.textSecondary);
        }
      });

      test('the outlined focus ring still shows on an enabled button', () {
        final style = t.outlinedButtonTheme.style!;
        final focused = style.side!.resolve({WidgetState.focused})!;
        final rest = style.side!.resolve({})!;
        expect(focused, isNot(rest));
      });

      test('text buttons: text.disabled.onRaised', () {
        for (final style in [
          t.textButtonTheme.style!,
          ButtonThemes.textButtonStyle(t.colorScheme),
        ]) {
          expect(style.foregroundColor!.resolve(_disabled), m.textDisabled);
        }
      });

      test('fields: 1 px surface.disabled edge on surface.raised', () {
        final border =
            t.inputDecorationTheme.disabledBorder! as OutlineInputBorder;
        expect(border.borderSide.color, m.surfaceDisabled);
        expect(border.borderSide.width, 1);
        expect(t.inputDecorationTheme.fillColor, m.surfaceRaised);
      });

      test('switch: raised track, disabled edge and knob, off and on', () {
        final s = t.switchTheme;
        for (final states in [_disabled, _disabledSelected]) {
          expect(s.trackColor!.resolve(states), m.surfaceRaised);
          expect(s.trackOutlineColor!.resolve(states), m.surfaceDisabled);
          expect(s.trackOutlineWidth!.resolve(states), 1.0);
          expect(s.thumbColor!.resolve(states), m.surfaceDisabled);
        }
      });

      test('switch on: opaque ink track with a paper knob', () {
        final s = t.switchTheme;
        final track = s.trackColor!.resolve({WidgetState.selected})!;
        expect(track, const Color(0xFF24382C));
        expect(track.a, 1.0);
        expect(
          s.thumbColor!.resolve({WidgetState.selected}),
          const Color(0xFFF5F4ED),
        );
      });

      test('radio: surface.disabled ring on surface.raised', () {
        final r = t.radioTheme;
        for (final states in [_disabled, _disabledSelected]) {
          expect(r.fillColor!.resolve(states), m.surfaceDisabled);
          expect(r.backgroundColor!.resolve(states), m.surfaceRaised);
        }
      });

      test('a disabled list row label is text.secondary', () {
        final color = t.listTileTheme.textColor! as WidgetStateColor;
        expect(color.resolve(_disabled), m.textSecondary);
        expect(color.resolve({}), t.colorScheme.onSurface);
        expect(color.resolve({WidgetState.selected}), t.colorScheme.primary);
      });

      test('no disabled colour is carried by opacity', () {
        final colors = <Color?>[
          t.elevatedButtonTheme.style!.backgroundColor!.resolve(_disabled),
          t.elevatedButtonTheme.style!.foregroundColor!.resolve(_disabled),
          t.outlinedButtonTheme.style!.foregroundColor!.resolve(_disabled),
          t.outlinedButtonTheme.style!.side!.resolve(_disabled)!.color,
          t.textButtonTheme.style!.foregroundColor!.resolve(_disabled),
          (t.inputDecorationTheme.disabledBorder! as OutlineInputBorder)
              .borderSide
              .color,
          t.switchTheme.trackColor!.resolve(_disabled),
          t.switchTheme.thumbColor!.resolve(_disabled),
          t.switchTheme.trackOutlineColor!.resolve(_disabled),
          t.radioTheme.fillColor!.resolve(_disabled),
          t.radioTheme.backgroundColor!.resolve(_disabled),
          t.listTileTheme.textColor,
        ];
        for (final c in colors) {
          final resolved = c is WidgetStateColor ? c.resolve(_disabled) : c;
          expect(resolved!.a, 1.0);
        }
      });
    });
  }

  testWidgets('a disabled ElevatedButton paints surface.disabled', (
    tester,
  ) async {
    for (final m in modes) {
      await tester.pumpWidget(
        MaterialApp(
          theme: m.theme,
          home: const Scaffold(
            body: Center(
              child: ElevatedButton(onPressed: null, child: Text('Spara')),
            ),
          ),
        ),
      );
      // MaterialApp animates between themes; let it settle on this mode.
      await tester.pumpAndSettle();
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, m.surfaceDisabled, reason: m.name);
    }
  });
}
