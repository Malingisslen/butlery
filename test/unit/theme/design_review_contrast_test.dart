/// Pins the contrast of the controls the design review (L1, L3-06, L6-07)
/// found unreadable or unclear in dark mode. Every figure is WCAG contrast of
/// the colours the theme itself produces, against the surface the control
/// stands on: 4.5:1 for text, 3:1 for graphics and cursors.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/button_themes.dart';
import 'package:butlery/views/family/profile_colors.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

double _contrast(Color fg, Color bg) {
  final a = Color.alphaBlend(fg, bg).computeLuminance();
  final b = bg.computeLuminance();
  final hi = a > b ? a : b, lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

const _disabled = <WidgetState>{WidgetState.disabled};
const _selected = <WidgetState>{WidgetState.selected};

void main() {
  testWidgets(
    'L1-05 buttons keep a 48 dp target on a desktop platform',
    (tester) async {
      final buttons = <String, Widget>{
        'IconButton': IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        'ElevatedButton': ElevatedButton(
          onPressed: () {},
          child: const Text('Spara'),
        ),
        'TextButton': TextButton(onPressed: () {}, child: const Text('Avbryt')),
      };
      for (final entry in buttons.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: Center(child: entry.value)),
          ),
        );
        expect(
          tester.getSize(find.byWidget(entry.value)).height,
          greaterThanOrEqualTo(48),
          reason: entry.key,
        );
      }
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('L1-03 the create button on a dark page is the light fill', (
    tester,
  ) async {
    final dark = AppTheme.darkTheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: dark,
        home: const Scaffold(
          body: FloatingActionButtonWidget.message(
            onPressed: null,
            semanticLabel: 'Ny konversation',
          ),
        ),
      ),
    );
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.backgroundColor, dark.floatingActionButtonTheme.backgroundColor);
    expect(
      _contrast(fab.backgroundColor!, dark.colorScheme.surface),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrast(fab.foregroundColor!, fab.backgroundColor!),
      greaterThanOrEqualTo(4.5),
    );
  });

  final themes = {'light': AppTheme.lightTheme, 'dark': AppTheme.darkTheme};

  for (final entry in themes.entries) {
    final name = entry.key;
    final theme = entry.value;
    final cs = theme.colorScheme;
    final base = cs.surface;
    final raised = cs.surfaceContainerHighest;

    group('$name theme', () {
      test(
        'L1-01 cursor and handles reach 3:1, the selection carries text',
        () {
          final sel = theme.textSelectionTheme;
          expect(sel.cursorColor, isNotNull);
          expect(_contrast(sel.cursorColor!, base), greaterThanOrEqualTo(3));
          expect(_contrast(sel.cursorColor!, raised), greaterThanOrEqualTo(3));
          expect(
            _contrast(sel.selectionHandleColor!, base),
            greaterThanOrEqualTo(3),
          );
          expect(sel.selectionColor!.a, 1, reason: 'opaque, never opacity');
          expect(
            _contrast(cs.onSurface, sel.selectionColor!),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(sel.selectionColor!, base),
            greaterThanOrEqualTo(1.5),
            reason: 'the highlight is visible on the page',
          );
        },
      );

      test('L1-02 the refresh arc (primary) reads on its disc', () {
        final disc = theme.progressIndicatorTheme.refreshBackgroundColor;
        expect(disc, isNotNull);
        expect(_contrast(cs.primary, disc!), greaterThanOrEqualTo(3));
        if (name == 'dark') {
          expect(
            _contrast(disc, base),
            greaterThanOrEqualTo(3),
            reason: 'the disc stands out from a dark page',
          );
        }
      });

      test('L1-03 / L6-07 the filled button and the FAB read on the page', () {
        final fab = theme.floatingActionButtonTheme;
        final fill = fab.backgroundColor!;
        expect(_contrast(fill, base), greaterThanOrEqualTo(3));
        expect(_contrast(fill, raised), greaterThanOrEqualTo(3));
        expect(
          _contrast(fab.foregroundColor!, fill),
          greaterThanOrEqualTo(4.5),
        );

        for (final style in [
          theme.elevatedButtonTheme.style!,
          theme.filledButtonTheme.style!,
          ButtonThemes.primaryButtonStyle(cs),
        ]) {
          final bg = style.backgroundColor!.resolve({})!;
          final fg = style.foregroundColor!.resolve({})!;
          expect(bg, fill);
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
        }
      });

      test('L1-03 the extended FAB takes the same fill', () {
        final style = ButtonThemes.extendedFabStyle(cs);
        expect(
          style.backgroundColor!.resolve({}),
          theme.floatingActionButtonTheme.backgroundColor,
        );
      });

      test('L1-04 a disabled IconButton is not drawn like an enabled one', () {
        final style = theme.iconButtonTheme.style!;
        final live = style.foregroundColor!.resolve({})!;
        final dead = style.foregroundColor!.resolve(_disabled)!;
        expect(dead, isNot(live));
        expect(dead, theme.disabledColor);
        expect(_contrast(dead, base), greaterThanOrEqualTo(3));
      });

      test('L1-04 a disabled Checkbox is not drawn like an enabled one', () {
        final box = theme.checkboxTheme;
        final liveFill = box.fillColor!.resolve(_selected)!;
        final deadFill = box.fillColor!.resolve({..._disabled, ..._selected})!;
        expect(deadFill, isNot(liveFill));
        expect(
          _contrast(
            box.checkColor!.resolve({..._disabled, ..._selected})!,
            deadFill,
          ),
          greaterThanOrEqualTo(3),
        );
        final side = box.side! as WidgetStateBorderSide;
        expect(
          side.resolve(_disabled)!.color,
          isNot(side.resolve({})!.color),
        );
      });

      test('L1-05 density is standard, never compact', () {
        expect(theme.visualDensity, VisualDensity.standard);
      });

      test('L1-06 tooltip and popup menu are themed', () {
        final tip = theme.tooltipTheme;
        final deco = tip.decoration! as BoxDecoration;
        expect(
          _contrast(tip.textStyle!.color!, deco.color!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          (deco.borderRadius! as BorderRadius).topLeft.x,
          8,
          reason: 'the control radius',
        );
        final menu = theme.popupMenuTheme;
        expect(menu.color, base);
        expect(menu.shape, isA<RoundedRectangleBorder>());
        expect(menu.elevation, 0);
        expect(
          _contrast(menu.textStyle!.color!, menu.color!),
          greaterThanOrEqualTo(4.5),
        );
      });

      test(
        'L1-07 field error text reads on the page and on a raised layer',
        () {
          final color = theme.inputDecorationTheme.errorStyle!.color!;
          expect(_contrast(color, raised), greaterThanOrEqualTo(4.5));
          expect(_contrast(color, base), greaterThanOrEqualTo(4.5));
        },
      );

      test('L1-19 the text on a filled error, success or tertiary reads', () {
        expect(_contrast(cs.onError, cs.error), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(cs.onTertiary, cs.tertiary),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('L1-09 the off switch knob reaches 3:1 on its track', () {
        final sw = theme.switchTheme;
        final knob = sw.thumbColor!.resolve({})!;
        final track = Color.alphaBlend(sw.trackColor!.resolve({})!, base);
        expect(_contrast(knob, track), greaterThanOrEqualTo(3));
      });
    });
  }

  test('L1-19 the generated status aliases read on their fills', () {
    expect(
      _contrast(AppColorsDark.onError, AppColorsDark.error),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColorsDark.onSuccess, AppColorsDark.success),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('L6-07 dark: the primary and the secondary button stay apart', () {
    final dark = AppTheme.darkTheme;
    final primary = dark.elevatedButtonTheme.style!.backgroundColor!.resolve(
      {},
    )!;
    final secondary = dark.outlinedButtonTheme.style!.backgroundColor!.resolve(
      {},
    )!;
    expect(secondary.a, 0, reason: 'the secondary is an outline, unfilled');
    expect(primary.a, 1);
    expect(
      _contrast(primary, dark.colorScheme.surfaceContainerHighest),
      greaterThanOrEqualTo(3),
      reason: 'the fill reads on the dialog surface',
    );
  });

  test('L6-07 light: the primary button is unchanged ink with paper text', () {
    final light = AppTheme.lightTheme;
    final style = light.elevatedButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), const Color(0xFF24382C));
    expect(style.foregroundColor!.resolve({}), const Color(0xFFF5F4ED));
  });

  group('L3-06 profile colours', () {
    for (final brightness in Brightness.values) {
      final cs = brightness == Brightness.dark
          ? AppTheme.darkTheme.colorScheme
          : AppTheme.lightTheme.colorScheme;
      test(
        'every colour a member can take has 4.5:1 initials, $brightness',
        () {
          for (final hex in kProfileColors) {
            final bg = Color(
              int.parse(hex.substring(1), radix: 16),
            ).withAlpha(255);
            expect(
              _contrast(onProfileColor(cs, bg), bg),
              greaterThanOrEqualTo(4.5),
              reason: hex,
            );
          }
        },
      );
    }

    test('a stored legacy colour is read as its measured shade', () {
      expect(canonicalProfileColor('#b07a3c'), '#B87F3F');
      expect(canonicalProfileColor('#3E6F8E'), '#3E6F8E');
      expect(canonicalProfileColor('#123456'), '#123456');
    });
  });
}
