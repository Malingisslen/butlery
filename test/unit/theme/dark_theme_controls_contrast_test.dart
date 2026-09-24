/// P5-DARK-THEME: the shared control themes read on the dark base.
///
/// ColorScheme.primary is surface.ink #24382C in BOTH schemes, and the dark
/// base is #17251D, so every control that painted cs.primary as a
/// foreground read 1.27:1 in dark mode. Each control below is rendered under
/// the dark theme and its colours are checked against the dark base: 4.5:1
/// for text, 3:1 for graphics (WCAG 1.4.3, 1.4.11).
///
/// Sources: Komponentark v1:491 (the dark rule: paper text, paper 35 % on
/// controls, the tick always paper), :499 (outlined button), :522-525
/// (chips), :532 (checked box), :545 (progress), :556 (chosen row check);
/// Skarmar v12 del 4:104 (dark switch), etapp 2:37 and etapp 4 import:28
/// (--ram-kontroll-a); tokens.json:54-57 (text.primary), :128-131
/// (border.control), :137-152 (action.primary, control.checked),
/// :161-168 (progress), :263 (overlay.paperWash).
///
/// Light mode must be unchanged: the second group pins every touched value
/// to what it resolved to before.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/components/button_themes.dart';

const _darkBase = Color(0xFF17251D);
const _darkRaised = Color(0xFF2F4437);
const _ink = Color(0xFF24382C);
const _paper = Color(0xFFF5F4ED);
const _saffron = Color(0xFFCE7C1E);

const _selected = <WidgetState>{WidgetState.selected};

/// WCAG contrast of [fg] composited over the opaque [bg].
double _contrast(Color fg, Color bg) {
  final a = Color.alphaBlend(fg, bg).computeLuminance();
  final b = bg.computeLuminance();
  final hi = a > b ? a : b, lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

Future<BuildContext> _pump(
  WidgetTester tester,
  ThemeData theme,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return tester.element(find.byType(Scaffold));
}

/// The Material a ButtonStyleButton or chip paints itself with.
Material _materialOf(WidgetTester tester, Finder control) => tester.widget(
  find.descendant(of: control, matching: find.byType(Material)).first,
);

void main() {
  final dark = AppTheme.darkTheme;
  final light = AppTheme.lightTheme;

  test('premise: primary is ink in both schemes, the dark base #17251D', () {
    expect(dark.colorScheme.primary, _ink);
    expect(light.colorScheme.primary, _ink);
    expect(dark.colorScheme.surface, _darkBase);
    expect(dark.colorScheme.surfaceContainerHighest, _darkRaised);
    expect(_contrast(_ink, _darkBase), lessThan(1.3));
  });

  group('dark mode: every touched control reads on #17251D', () {
    testWidgets('outlined button: paper text, paper 40 % outline', (
      tester,
    ) async {
      await _pump(
        tester,
        dark,
        OutlinedButton(onPressed: () {}, child: const Text('Spara offline')),
      );
      final m = _materialOf(tester, find.byType(OutlinedButton));
      expect(m.textStyle!.color, _paper);
      expect(_contrast(m.textStyle!.color!, _darkBase), greaterThan(4.5));
      final side = (m.shape! as OutlinedBorder).side;
      expect(side.color, const Color(0x66F5F4ED));
      expect(_contrast(side.color, _darkBase), greaterThanOrEqualTo(3.0));
    });

    testWidgets('text button: paper text', (tester) async {
      await _pump(
        tester,
        dark,
        TextButton(onPressed: () {}, child: const Text('Visa alla')),
      );
      final m = _materialOf(tester, find.byType(TextButton));
      expect(_contrast(m.textStyle!.color!, _darkBase), greaterThan(4.5));
    });

    testWidgets('named styles: text, secondary and outlined', (tester) async {
      final ctx = await _pump(tester, dark, const SizedBox());
      final cs = Theme.of(ctx).colorScheme;
      for (final style in [
        ButtonThemes.textButtonStyle(cs),
        ButtonThemes.outlinedButtonStyleNamed(cs),
      ]) {
        expect(
          _contrast(style.foregroundColor!.resolve({})!, _darkBase),
          greaterThan(4.5),
        );
      }
      final secondary = ButtonThemes.secondaryButtonStyle(cs);
      expect(
        _contrast(secondary.foregroundColor!.resolve({})!, _darkRaised),
        greaterThan(4.5),
      );
      for (final style in [
        secondary,
        ButtonThemes.outlinedButtonStyleNamed(cs),
      ]) {
        expect(
          _contrast(style.side!.resolve({})!.color, _darkBase),
          greaterThanOrEqualTo(3.0),
        );
      }
    });

    testWidgets('checkbox: ink box, paper tick, as drawn', (tester) async {
      final ctx = await _pump(
        tester,
        dark,
        Checkbox(value: true, onChanged: (_) {}),
      );
      final c = Theme.of(ctx).checkboxTheme;
      final fill = c.fillColor!.resolve(_selected)!;
      final tick = c.checkColor!.resolve(_selected)!;
      // Komponentark v1:532: the checked box stays ink; the tick carries it.
      expect(fill, _ink);
      expect(tick, _paper);
      expect(_contrast(tick, fill), greaterThan(4.5));
      expect(_contrast(tick, _darkBase), greaterThanOrEqualTo(3.0));
    });

    testWidgets('radio: the chosen ring and dot are paper', (tester) async {
      final ctx = await _pump(
        tester,
        dark,
        RadioGroup<int>(
          groupValue: 1,
          onChanged: (_) {},
          child: const Radio<int>(value: 1),
        ),
      );
      final fill = Theme.of(ctx).radioTheme.fillColor!.resolve(_selected)!;
      expect(fill, _paper);
      expect(_contrast(fill, _darkBase), greaterThanOrEqualTo(3.0));
    });

    testWidgets('switch on: ink track with a paper edge and knob', (
      tester,
    ) async {
      final ctx = await _pump(
        tester,
        dark,
        Switch(value: true, onChanged: (_) {}),
      );
      final s = Theme.of(ctx).switchTheme;
      final track = s.trackColor!.resolve(_selected)!;
      final knob = s.thumbColor!.resolve(_selected)!;
      final edge = s.trackOutlineColor!.resolve(_selected)!;
      // tokens.json:145-152 control.checked: ink in dark too; the paper
      // edge carries it on the dark base (Komponentark v1:523).
      expect(track, _ink);
      expect(knob, _paper);
      expect(edge, _paper);
      expect(s.trackOutlineWidth!.resolve(_selected), 1.0);
      expect(_contrast(edge, _darkBase), greaterThanOrEqualTo(3.0));
      expect(_contrast(knob, track), greaterThanOrEqualTo(3.0));
    });

    testWidgets('slider: paper active track and thumb', (tester) async {
      final ctx = await _pump(
        tester,
        dark,
        Slider(value: 0.5, onChanged: (_) {}),
      );
      final s = Theme.of(ctx).sliderTheme;
      expect(
        _contrast(s.activeTrackColor!, _darkBase),
        greaterThanOrEqualTo(3.0),
      );
      expect(_contrast(s.thumbColor!, _darkBase), greaterThanOrEqualTo(3.0));
      // The value bubble is an ink fill; its text is paper.
      expect(
        _contrast(s.valueIndicatorTextStyle!.color!, s.valueIndicatorColor!),
        greaterThan(4.5),
      );
    });

    testWidgets('progress: saffron on paper 18 %', (tester) async {
      final ctx = await _pump(
        tester,
        dark,
        const LinearProgressIndicator(value: 0.4),
      );
      final p = Theme.of(ctx).progressIndicatorTheme;
      expect(p.color, _saffron);
      expect(p.linearTrackColor, const Color(0x2EF5F4ED));
      expect(_contrast(p.color!, _darkBase), greaterThanOrEqualTo(3.0));
      // Saffron on the paper 18 % track is 2.86:1, the drawn and tokened
      // pair (Komponentark v1:545; tokens.json:161-168). It is pinned here
      // so a change is seen; whether it needs 3:1 is left open.
      expect(
        _contrast(p.color!, Color.alphaBlend(p.linearTrackColor!, _darkBase)),
        closeTo(2.86, 0.01),
      );
    });

    testWidgets('scrollbar thumb reads', (tester) async {
      final ctx = await _pump(tester, dark, const SizedBox());
      final thumb = Theme.of(ctx).scrollbarTheme.thumbColor!.resolve({})!;
      expect(_contrast(thumb, _darkBase), greaterThanOrEqualTo(3.0));
    });

    testWidgets('list tile: paper icons, paper chosen row', (tester) async {
      await _pump(
        tester,
        dark,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.edit), title: Text('Redigera')),
            ListTile(
              selected: true,
              leading: Icon(Icons.check),
              title: Text('Efter kategori'),
            ),
          ],
        ),
      );
      final restIcon = IconTheme.of(tester.element(find.byIcon(Icons.edit)));
      final chosenIcon = IconTheme.of(
        tester.element(find.byIcon(Icons.check)),
      );
      final chosenText = DefaultTextStyle.of(
        tester.element(find.text('Efter kategori')),
      ).style.color!;
      for (final color in [restIcon.color!, chosenIcon.color!]) {
        expect(_contrast(color, _darkBase), greaterThanOrEqualTo(3.0));
        expect(_contrast(color, _darkRaised), greaterThanOrEqualTo(3.0));
      }
      // The chosen row sits on primaryContainer, surface.raised in dark.
      expect(_contrast(chosenText, _darkRaised), greaterThan(4.5));
    });

    testWidgets('chips: edged in paper, paper check and label', (
      tester,
    ) async {
      final ctx = await _pump(
        tester,
        dark,
        Wrap(
          children: [
            FilterChip(
              label: const Text('Vegetariskt'),
              selected: false,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Snabbt'),
              selected: true,
              onSelected: (_) {},
            ),
          ],
        ),
      );
      final rest = _materialOf(tester, find.byType(FilterChip).first);
      final chosen = _materialOf(tester, find.byType(FilterChip).last);
      final restSide = (rest.shape! as OutlinedBorder).side;
      final chosenSide = (chosen.shape! as OutlinedBorder).side;
      expect(chosenSide.color, _paper);
      expect(_contrast(restSide.color, _darkBase), greaterThanOrEqualTo(3.0));
      expect(
        _contrast(chosenSide.color, _darkBase),
        greaterThanOrEqualTo(3.0),
      );
      final chip = Theme.of(ctx).chipTheme;
      expect(chip.selectedColor, _ink);
      expect(_contrast(chip.checkmarkColor!, _ink), greaterThan(4.5));
      expect(_contrast(chip.labelStyle!.color!, _ink), greaterThan(4.5));
    });

    test('chip disabled: no fill, sage label (Komponentark v1:525)', () {
      final chip = dark.chipTheme;
      const off = {WidgetState.disabled};
      expect(chip.disabledColor!.a, 0);
      expect(
        WidgetStateProperty.resolveAs<Color?>(chip.labelStyle!.color, off),
        const Color(0xFF93A48D),
      );
      expect(
        WidgetStateProperty.resolveAs<Color?>(chip.labelStyle!.color, {}),
        _paper,
      );
    });

    test('filled backgrounds stay ink with paper', () {
      final cs = dark.colorScheme;
      expect(
        dark.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
        _ink,
      );
      expect(dark.filledButtonTheme.style!.backgroundColor!.resolve({}), _ink);
      expect(dark.floatingActionButtonTheme.backgroundColor, _ink);
      expect(
        ButtonThemes.primaryButtonStyle(cs).backgroundColor!.resolve({}),
        _ink,
      );
    });
  });

  group('light mode: the touched values are unchanged', () {
    final cs = light.colorScheme;

    test('buttons', () {
      expect(
        light.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
        _ink,
      );
      expect(light.outlinedButtonTheme.style!.side!.resolve({})!.color, _ink);
      expect(light.textButtonTheme.style!.foregroundColor!.resolve({}), _ink);
      for (final style in [
        ButtonThemes.textButtonStyle(cs),
        ButtonThemes.secondaryButtonStyle(cs),
        ButtonThemes.outlinedButtonStyleNamed(cs),
      ]) {
        expect(style.foregroundColor!.resolve({}), _ink);
      }
      for (final style in [
        ButtonThemes.secondaryButtonStyle(cs),
        ButtonThemes.outlinedButtonStyleNamed(cs),
      ]) {
        expect(style.side!.resolve({})!.color, _ink);
      }
    });

    test('selection controls', () {
      expect(light.checkboxTheme.fillColor!.resolve(_selected), _ink);
      expect(light.checkboxTheme.checkColor!.resolve(_selected), _paper);
      expect(light.radioTheme.fillColor!.resolve(_selected), _ink);
      expect(light.switchTheme.trackColor!.resolve(_selected), _ink);
      expect(light.switchTheme.thumbColor!.resolve(_selected), _paper);
    });

    test('slider, progress and scrollbar', () {
      final s = light.sliderTheme;
      expect(s.activeTrackColor, _ink);
      expect(s.thumbColor, _ink);
      expect(s.valueIndicatorColor, _ink);
      expect(s.overlayColor, _ink.withValues(alpha: s.overlayColor!.a));
      expect(light.progressIndicatorTheme.color, _ink);
      expect(
        light.scrollbarTheme.thumbColor!.resolve({}),
        _ink.withValues(alpha: 0.6),
      );
    });

    test('list tile and chips', () {
      final t = light.listTileTheme;
      expect(t.iconColor, _ink);
      // Material's default selected colour was cs.primary.
      expect(t.selectedColor, _ink);
      expect((t.textColor! as WidgetStateColor).resolve(_selected), _ink);
      expect(light.chipTheme.selectedColor, _ink);
      // Light sets no chip side and no check colour: Material's defaults.
      expect(light.chipTheme.side, isNull);
      expect(light.chipTheme.checkmarkColor, isNull);
    });
  });
}
