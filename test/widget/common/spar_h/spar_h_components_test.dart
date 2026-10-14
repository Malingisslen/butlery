// Spår H: the shared building blocks the view tracks move onto. Each test
// states the behaviour a view relies on when it swaps its raw widget for the
// shared one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';
import 'package:butlery/widgets/common/state/butlery_section_state.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

Future<void> _pumpHome(WidgetTester tester, Widget Function(BuildContext) b) {
  return tester.pumpWidget(
    createLocalizedTestApp(child: Builder(builder: b)),
  );
}

void main() {
  group('ButlerySheetHeader', () {
    testWidgets('the × closes the sheet and is named for what it closes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpHome(
        tester,
        (context) => TextButton(
          onPressed: () => showButlerySheet<void>(
            context: context,
            builder: (_) => const ButlerySheetHeader(
              title: 'Näringsvärden',
              closeLabel: 'Stäng näringsvärden',
            ),
          ),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Näringsvärden'), findsOneWidget);
      expect(find.bySemanticsLabel('Stäng näringsvärden'), findsOneWidget);
      await tester.tap(find.byType(ButleryCloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Näringsvärden'), findsNothing);
      handle.dispose();
    });

    testWidgets('without a closeLabel it draws no ×', (tester) async {
      await _pumpHome(
        tester,
        (_) => const ButlerySheetHeader(title: 'Titel'),
      );
      expect(find.byType(ButleryCloseButton), findsNothing);
    });
  });

  group('ButleryDialog', () {
    testWidgets('confirm pops true on the primary and null on Avbryt', (
      tester,
    ) async {
      bool? result = false;
      await _pumpHome(
        tester,
        (context) => TextButton(
          onPressed: () async => result = await showButleryDialog<bool>(
            context: context,
            builder: (_) => ButleryDialog.confirm(
              title: 'Spara?',
              message: 'Ändringarna sparas.',
              primaryLabel: 'Spara',
            ),
          ),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Avbryt'), findsOneWidget);
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(result, isNull);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('a busy primary keeps its name and locks Avbryt', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        (_) => ButleryDialog.confirm(
          title: 'Sparar',
          primaryLabel: 'Spara',
          busy: true,
        ),
      );
      expect(find.text('Spara'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Avbryt'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('notice offers one Stäng, never OK', (tester) async {
      await _pumpHome(
        tester,
        (_) => ButleryDialog.notice(title: 'Info', message: 'Klart.'),
      );
      expect(find.text('Stäng'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('a disabled primary cannot be pressed', (tester) async {
      await _pumpHome(
        tester,
        (_) => ButleryDialog.confirm(
          title: 'T',
          primaryLabel: 'Spara',
          primaryEnabled: false,
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Spara'))
            .onPressed,
        isNull,
      );
    });
  });

  group('ButleryTextButton', () {
    testWidgets('fires once and a null handler disables it', (tester) async {
      var taps = 0;
      await _pumpHome(
        tester,
        (_) => Column(
          children: [
            ButleryTextButton(label: 'Ångra', onPressed: () => taps++),
            const ButleryTextButton(label: 'Av', onPressed: null),
          ],
        ),
      );
      await tester.tap(find.text('Ångra'));
      expect(taps, 1);
      final off = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Av'),
      );
      expect(off.onPressed, isNull);
    });

    testWidgets('the danger tone paints the error colour', (tester) async {
      await _pumpHome(
        tester,
        (_) => ButleryTextButton(
          label: 'Ta bort',
          tone: ButleryTextButtonTone.danger,
          onPressed: () {},
        ),
      );
      final cs = Theme.of(tester.element(find.text('Ta bort'))).colorScheme;
      final style = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Ta bort'))
          .style!;
      expect(style.foregroundColor!.resolve({}), cs.error);
    });
  });

  group('ButleryMenu and ButleryDropdown', () {
    testWidgets('a menu reports the picked value', (tester) async {
      String? picked;
      await _pumpHome(
        tester,
        (_) => ButleryMenu<String>(
          semanticLabel: 'Fler val',
          onSelected: (v) => picked = v,
          choices: const [
            ButleryMenuChoice(value: 'edit', label: 'Ändra'),
            ButleryMenuChoice(value: 'del', label: 'Ta bort', danger: true),
          ],
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ta bort'));
      await tester.pumpAndSettle();
      expect(picked, 'del');
    });

    testWidgets('a dropdown reports the changed value', (
      tester,
    ) async {
      String? picked;
      await _pumpHome(
        tester,
        (_) => ButleryDropdown<String>(
          value: 'a',
          options: const [
            ButleryDropdownOption(value: 'a', label: 'Lunch'),
            ButleryDropdownOption(value: 'b', label: 'Middag'),
          ],
          semanticLabel: 'Måltid',
          onChanged: (v) => picked = v,
        ),
      );
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Middag').last);
      await tester.pumpAndSettle();
      expect(picked, 'b');
    });
  });

  group('ButleryDivider', () {
    testWidgets('draws the theme hairline and the labelled variant its word', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        (_) => const Column(
          children: [
            ButleryDivider(),
            ButleryLabelledDivider(label: 'eller'),
          ],
        ),
      );
      expect(find.byType(Divider), findsNWidgets(3));
      expect(find.text('eller'), findsOneWidget);
    });
  });

  group('ButleryItemRow', () {
    testWidgets('a tap fires once; a read-only row has no tap target', (
      tester,
    ) async {
      var taps = 0;
      await _pumpHome(
        tester,
        (_) => Column(
          children: [
            ButleryItemRow(title: 'Mejeri', onTap: () => taps++),
            const ButleryItemRow(title: 'Bara text'),
          ],
        ),
      );
      await tester.tap(find.text('Mejeri'));
      expect(taps, 1);
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('the check shows only on the selected row', (tester) async {
      await _pumpHome(
        tester,
        (_) => Column(
          children: [
            ButleryItemRow(
              title: 'Vald',
              selected: true,
              showCheck: true,
              onTap: () {},
            ),
            ButleryItemRow(title: 'Ej vald', showCheck: true, onTap: () {}),
          ],
        ),
      );
      final selectedRow = find.ancestor(
        of: find.text('Vald'),
        matching: find.byType(ButleryItemRow),
      );
      final otherRow = find.ancestor(
        of: find.text('Ej vald'),
        matching: find.byType(ButleryItemRow),
      );
      expect(
        find.descendant(of: selectedRow, matching: find.byType(ButleryIcon)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: otherRow, matching: find.byType(ButleryIcon)),
        findsNothing,
      );
    });
  });

  group('ButlerySectionState', () {
    testWidgets('error names what happened and runs both actions', (
      tester,
    ) async {
      var retried = 0;
      var saved = 0;
      await _pumpHome(
        tester,
        (_) => ButlerySectionState.error(
          message: 'Veckan kunde inte läsas.',
          actionLabel: 'Försök igen',
          onAction: () => retried++,
          secondaryLabel: 'Visa sparad plan',
          onSecondary: () => saved++,
        ),
      );
      expect(find.text('Veckan kunde inte läsas.'), findsOneWidget);
      await tester.tap(find.byKey(ButlerySectionState.actionKey));
      await tester.tap(find.byKey(ButlerySectionState.secondaryKey));
      expect((retried, saved), (1, 1));
    });

    testWidgets('empty offers its action only when it has one', (tester) async {
      await _pumpHome(
        tester,
        (_) => const ButlerySectionState.empty(message: 'Inget här än.'),
      );
      expect(find.text('Inget här än.'), findsOneWidget);
      expect(find.byKey(ButlerySectionState.actionKey), findsNothing);
    });

    testWidgets('loading says what is fetched', (tester) async {
      await _pumpHome(
        tester,
        (_) => const ButlerySectionState.loading(message: 'Hämtar veckan …'),
      );
      expect(find.text('Hämtar veckan …'), findsOneWidget);
    });
  });

  group('ButleryCloseButton and custom actions', () {
    testWidgets('a banner dismiss replaces the default pop', (tester) async {
      var dismissed = 0;
      await _pumpHome(
        tester,
        (_) => ButleryCloseButton(
          semanticLabel: 'Stäng banner',
          onPressed: () => dismissed++,
        ),
      );
      await tester.tap(find.byType(ButleryCloseButton));
      expect(dismissed, 1);
    });

    testWidgets('onPrimary replaces the default pop and Stäng pops', (
      tester,
    ) async {
      var primary = 0;
      await _pumpHome(
        tester,
        (_) => ButleryDialog.confirm(
          title: 'T',
          primaryLabel: 'Gör det',
          onPrimary: () => primary++,
        ),
      );
      await tester.tap(find.text('Gör det'));
      expect(primary, 1);
    });

    testWidgets('a busy primary cannot be pressed twice', (tester) async {
      var primary = 0;
      await _pumpHome(
        tester,
        (_) => ButleryDialog.confirm(
          title: 'T',
          primaryLabel: 'Spara',
          busy: true,
          onPrimary: () => primary++,
        ),
      );
      await tester.tap(find.text('Spara'));
      expect(primary, 0);
    });

    testWidgets('Stäng on a notice closes the dialog', (tester) async {
      await _pumpHome(
        tester,
        (context) => TextButton(
          onPressed: () => showButleryDialog<void>(
            context: context,
            builder: (_) => ButleryDialog.notice(title: 'Info'),
          ),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stäng'));
      await tester.pumpAndSettle();
      expect(find.text('Info'), findsNothing);
    });

    testWidgets('a disabled row ignores taps', (tester) async {
      var taps = 0;
      await _pumpHome(
        tester,
        (_) => ButleryItemRow(title: 'Av', enabled: false, onTap: () => taps++),
      );
      await tester.tap(find.text('Av'));
      expect(taps, 0);
    });

    testWidgets('an empty section offers its action when it has one', (
      tester,
    ) async {
      var taps = 0;
      await _pumpHome(
        tester,
        (_) => ButlerySectionState.empty(
          message: 'Tomt.',
          actionLabel: 'Lägg till',
          onAction: () => taps++,
        ),
      );
      await tester.tap(find.byKey(ButlerySectionState.actionKey));
      expect(taps, 1);
    });

    testWidgets('a dropdown shows the new value when it changes', (
      tester,
    ) async {
      const options = [
        ButleryDropdownOption(value: 'a', label: 'Lunch'),
        ButleryDropdownOption(value: 'b', label: 'Middag'),
      ];
      Widget dropdown(String v) => ButleryDropdown<String>(
        value: v,
        options: options,
        semanticLabel: 'Måltid',
        onChanged: (_) {},
      );
      await _pumpHome(tester, (_) => dropdown('a'));
      expect(find.text('Lunch'), findsOneWidget);
      await _pumpHome(tester, (_) => dropdown('b'));
      expect(find.text('Middag'), findsOneWidget);
    });
  });
}
