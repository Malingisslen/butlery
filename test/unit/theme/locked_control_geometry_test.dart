// P5-U34: locked control geometry.
//
// Komponentark v1:33 ("Låst geometri") and §03 :134-176 draw the controls
// with fixed sizes, and tokens.json controls (:803-866) carries them. These
// tests measure what the theme can lock and keep it from drifting.
//
// Not measured here, because Flutter's Material controls hard-code them and
// no ThemeData field reaches them: the checkbox's 24 px box (Flutter draws
// 18), the radio's 19 px (Flutter 20 with a 2 px ring), and the toggle's
// 34 × 20 track with a 16 px knob (Material 3 draws 52 × 32). Those need
// Butlery's own controls; see the track report.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: Center(child: child)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder visibleChip() => find
        .descendant(
          of: find.byType(FilterChip),
          matching: find.byType(Material),
        )
        .first;

    group(
      'chip ($name) — tokens.json controls.chip, Komponentark v1:134-140',
      () {
        testWidgets('34 px visible inside a 48 dp hit area', (tester) async {
          await pump(
            tester,
            FilterChip(label: const Text('Vego'), onSelected: (_) {}),
          );

          expect(tester.getSize(visibleChip()).height, 34);
          expect(tester.getSize(find.byType(FilterChip)).height, 48);
        });

        testWidgets('13 px padding inside a 1 px edge before the label', (
          tester,
        ) async {
          await pump(
            tester,
            FilterChip(label: const Text('Vego'), onSelected: (_) {}),
          );

          final left = tester.getTopLeft(visibleChip()).dx;
          final label = tester.getTopLeft(find.text('Vego')).dx;
          expect(label - left, 1 + 13);
          final right = tester.getTopRight(visibleChip()).dx;
          final labelEnd = tester.getTopRight(find.text('Vego')).dx;
          expect(right - labelEnd, 13 + 1);
        });

        testWidgets('selected: the label follows the check as drawn (12 + 6)', (
          tester,
        ) async {
          await pump(
            tester,
            FilterChip(
              selected: true,
              label: const Text('Vego'),
              onSelected: (_) {},
            ),
          );

          final left = tester.getTopLeft(visibleChip()).dx;
          final label = tester.getTopLeft(find.text('Vego')).dx;
          expect(label - left, 1 + 13 + 12 + 6);
          expect(tester.getSize(visibleChip()).height, 34);
        });

        testWidgets('avatar and delete icon keep a 6 px gap to the label', (
          tester,
        ) async {
          const avatarKey = Key('avatar');
          const deleteKey = Key('delete');
          await pump(
            tester,
            InputChip(
              avatar: const SizedBox(key: avatarKey, width: 18, height: 18),
              label: const Text('Anna'),
              onDeleted: () {},
              deleteIcon: const SizedBox(key: deleteKey, width: 18, height: 18),
            ),
          );

          final avatarEnd = tester.getTopRight(find.byKey(avatarKey)).dx;
          final labelStart = tester.getTopLeft(find.text('Anna')).dx;
          expect(labelStart - avatarEnd, 6);
          final labelEnd = tester.getTopRight(find.text('Anna')).dx;
          final deleteStart = tester.getTopLeft(find.byKey(deleteKey)).dx;
          expect(deleteStart - labelEnd, 6);
        });

        test('a pill', () {
          final shape = theme.chipTheme.shape! as RoundedRectangleBorder;
          expect(
            shape.borderRadius,
            const BorderRadius.all(Radius.circular(AppDimensions.radiusPill)),
          );
        });
      },
    );

    group('checkbox ($name) — tokens.json controls.checkbox', () {
      test('radius 6 and a 1.5 px edge', () {
        final shape = theme.checkboxTheme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(6));
        expect(theme.checkboxTheme.side!.width, 1.5);
      });

      testWidgets('48 dp hit area', (tester) async {
        await pump(tester, Checkbox(value: true, onChanged: (_) {}));

        expect(tester.getSize(find.byType(Checkbox)), const Size(48, 48));
      });
    });

    group('radio and toggle ($name) — 48 dp hit area', () {
      testWidgets('radio', (tester) async {
        await pump(
          tester,
          RadioGroup<int>(
            groupValue: 1,
            onChanged: (_) {},
            child: const Radio<int>(value: 1),
          ),
        );

        expect(tester.getSize(find.byType(Radio<int>)), const Size(48, 48));
      });

      testWidgets('toggle', (tester) async {
        await pump(tester, Switch(value: true, onChanged: (_) {}));

        expect(tester.getSize(find.byType(Switch)).height, 48);
      });
    });

    group('buttons ($name) — tokens.json controls.button', () {
      for (final (kind, button) in [
        ('filled', FilledButton(onPressed: () {}, child: const Text('Spara'))),
        (
          'outlined',
          OutlinedButton(onPressed: () {}, child: const Text('Spara')),
        ),
        ('text', TextButton(onPressed: () {}, child: const Text('Spara'))),
      ]) {
        testWidgets('$kind is 46-48 high with a 14/600 label', (tester) async {
          await pump(tester, button);

          final height = tester.getSize(find.byWidget(button)).height;
          expect(height, inInclusiveRange(46, 48));
          final label = tester.widget<RichText>(
            find.descendant(
              of: find.byWidget(button),
              matching: find.byType(RichText),
            ),
          );
          expect(label.text.style?.fontSize, 14);
          expect(label.text.style?.fontWeight, FontWeight.w600);
          expect(AppTextStyles.buttonText.fontWeight, FontWeight.w600);
        });
      }
    });
  }
}
