// Spår H del 3: the gaps spår B, D and E found in the shared components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/chips/butlery_action_chip.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

Widget _app(Widget child) =>
    createLocalizedTestApp(child: Scaffold(body: child));

ColorScheme _cs(WidgetTester tester, Finder f) =>
    Theme.of(tester.element(f)).colorScheme;

void main() {
  group('ButleryTextButton', () {
    testWidgets('onInk reads in onPrimary and dense pads 8 at the sides', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ButleryTextButton(
            label: 'Släng utkastet',
            tone: ButleryTextButtonTone.onInk,
            dense: true,
            onPressed: () {},
          ),
        ),
      );
      final button = tester.widget<TextButton>(find.byType(TextButton));
      final cs = _cs(tester, find.byType(TextButton));
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        cs.onPrimary,
      );
      expect(
        button.style?.padding?.resolve(<WidgetState>{}),
        const EdgeInsets.symmetric(horizontal: AppDimensions.space8),
      );
    });

    testWidgets('iconAtEnd puts the glyph after the words', (tester) async {
      await tester.pumpWidget(
        _app(
          ButleryTextButton(
            label: 'Allergier',
            icon: ButleryIcons.arrowRight,
            iconAtEnd: true,
            onPressed: () {},
          ),
        ),
      );
      final words = tester.getCenter(find.text('Allergier')).dx;
      final glyph = tester.getCenter(find.byIcon(ButleryIcons.arrowRight)).dx;
      expect(glyph, greaterThan(words));
    });
  });

  group('ButleryChevron, ButleryDivider, ButlerySheetHeader', () {
    testWidgets('a chevron takes its own colour', (tester) async {
      await tester.pumpWidget(_app(const ButleryChevron(color: Colors.red)));
      final icon = tester.widget<ButleryIcon>(find.byType(ButleryIcon));
      expect(icon.color, Colors.red);
    });

    testWidgets('a divider takes its own height', (tester) async {
      await tester.pumpWidget(_app(const ButleryDivider(spacing: 24)));
      expect(tester.getSize(find.byType(Divider)).height, 24);
    });

    testWidgets(
      'the header draws a leading glyph before the title',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            const ButlerySheetHeader(
              title: 'Byt ut',
              closeLabel: 'Stäng',
              leading: ButleryIcon(ButleryIcons.swapHorizontal),
              trailingTopInset: 8,
            ),
          ),
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is ButleryIcon && w.icon == ButleryIcons.swapHorizontal,
          ),
          findsOneWidget,
        );
        final titleX = tester.getTopLeft(find.text('Byt ut')).dx;
        expect(
          tester
              .getCenter(
                find.byWidgetPredicate(
                  (w) =>
                      w is ButleryIcon && w.icon == ButleryIcons.swapHorizontal,
                ),
              )
              .dx,
          lessThan(titleX),
        );
      },
    );
  });

  group('ButlerySheetHeader inset', () {
    testWidgets('trailingTopInset moves the × down by that much', (
      tester,
    ) async {
      Future<double> closeTop(double inset) async {
        await tester.pumpWidget(
          _app(
            ButlerySheetHeader(
              title: 'Titel',
              closeLabel: 'Stäng',
              trailingTopInset: inset,
            ),
          ),
        );
        return tester.getTopLeft(find.byType(IconButton)).dy;
      }

      final flat = await closeTop(0);
      final lowered = await closeTop(8);
      expect(lowered, greaterThan(flat));
    });
  });

  group('ButleryItemRow danger', () {
    testWidgets('title and glyph are drawn in error', (tester) async {
      await tester.pumpWidget(
        _app(
          const ButleryItemRow(
            title: 'Radera',
            leadingIcon: ButleryIcons.trash2,
            danger: true,
          ),
        ),
      );
      final cs = _cs(tester, find.text('Radera'));
      final text = tester.widget<Text>(find.text('Radera'));
      expect(text.style?.color, cs.error);
      final glyph = tester.widget<ButleryIcon>(find.byType(ButleryIcon));
      expect(glyph.color, cs.error);
    });
  });

  group('ButleryDialog', () {
    testWidgets('titleIcon sits on the dialog and primaryIcon on the button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ButleryDialog.confirm(
            title: 'Fortsätt där du slutade',
            titleIcon: ButleryIcons.history,
            primaryLabel: 'Fortsätt',
            primaryIcon: ButleryIcons.camera,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byIcon(ButleryIcons.history),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byIcon(ButleryIcons.camera),
        ),
        findsOneWidget,
      );
      expect(find.text('Fortsätt'), findsOneWidget);
    });
  });

  group('AppIconButton', () {
    testWidgets('filled paints the primary colour', (tester) async {
      await tester.pumpWidget(
        _app(
          AppIconButton(
            icon: ButleryIcons.plus,
            semanticLabel: 'Lägg till',
            onPressed: () {},
            filled: true,
          ),
        ),
      );
      final button = tester.widget<IconButton>(find.byType(IconButton));
      final cs = _cs(tester, find.byType(IconButton));
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        cs.primary,
      );
    });

    testWidgets('busy ignores taps and keeps the name', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          AppIconButton(
            icon: ButleryIcons.send,
            semanticLabel: 'Skicka',
            onPressed: () => taps++,
            busy: true,
          ),
        ),
      );
      await tester.tap(find.byType(IconButton), warnIfMissed: false);
      expect(taps, 0);
      expect(find.bySemanticsLabel('Skicka'), findsOneWidget);
      await tester.pumpWidget(
        _app(
          AppIconButton(
            icon: ButleryIcons.send,
            semanticLabel: 'Skicka',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('ButleryMenu', () {
    testWidgets('a child replaces the glyph, rows carry keys, a divider and '
        'a disabled colour', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _app(
          ButleryMenu<String>(
            semanticLabel: 'Sortera',
            onSelected: (v) => picked = v,
            choices: const [
              ButleryMenuChoice(
                value: 'all',
                label: 'Markera alla 24',
                tabularFigures: true,
                itemKey: Key('select-all'),
              ),
              ButleryMenuChoice(
                value: 'del',
                label: 'Radera valda',
                danger: true,
                dividerBefore: true,
                itemKey: Key('delete'),
              ),
              ButleryMenuChoice(
                value: 'off',
                label: 'Avstängd',
                enabled: false,
              ),
            ],
            child: const Text('Sortera'),
          ),
        ),
      );
      expect(find.byIcon(ButleryIcons.moreVertical), findsNothing);
      await tester.tap(find.text('Sortera'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuDivider), findsOneWidget);
      final all = tester.widget<Text>(find.text('Markera alla 24'));
      expect(
        all.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final off = tester.widget<Text>(find.text('Avstängd'));
      expect(
        off.style?.color,
        AppModeColors.textDisabled(
          _cs(tester, find.text('Avstängd')).brightness,
        ),
      );
      await tester.tap(find.byKey(const Key('delete')));
      await tester.pumpAndSettle();
      expect(picked, 'del');
    });
  });

  group('ButleryDropdown', () {
    testWidgets('label, rich options and an external error', (tester) async {
      await tester.pumpWidget(
        _app(
          ButleryDropdown<String>(
            semanticLabel: 'Behörighet',
            label: 'Roll',
            value: 'view',
            errorText: 'Välj en roll',
            onChanged: (_) {},
            options: const [
              ButleryDropdownOption(
                value: 'view',
                label: 'Läsa',
                subtitle: 'Ser listan',
                icon: ButleryIcons.eye,
              ),
              ButleryDropdownOption(value: 'edit', label: 'Ändra'),
            ],
          ),
        ),
      );
      expect(find.text('Roll'), findsOneWidget);
      expect(find.text('Ser listan'), findsNothing);
      await tester.tap(find.text('Läsa'));
      await tester.pumpAndSettle();
      expect(find.text('Ser listan'), findsWidgets);
      expect(find.byIcon(ButleryIcons.eye), findsWidgets);
      expect(find.text('Välj en roll'), findsOneWidget);
    });

    testWidgets('a validator runs inside a Form', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        _app(
          Form(
            key: key,
            child: ButleryDropdown<String>(
              semanticLabel: 'Typ',
              value: null,
              onChanged: (_) {},
              validator: (v) => v == null ? 'Saknas' : null,
              options: const [
                ButleryDropdownOption(value: 'a', label: 'A'),
              ],
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Saknas'), findsOneWidget);
    });
  });

  group('chips', () {
    testWidgets('action chip presses and choice chip reports selection', (
      tester,
    ) async {
      var pressed = 0;
      bool? chosen;
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              ButleryActionChip(
                label: 'Vegetariskt',
                onPressed: () => pressed++,
              ),
              ButleryChoiceChip(
                label: 'Gram',
                selected: false,
                onSelected: (v) => chosen = v,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Vegetariskt'));
      await tester.tap(find.text('Gram'));
      expect(pressed, 1);
      expect(chosen, isTrue);
    });
  });
}
