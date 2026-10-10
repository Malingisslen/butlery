// The one row and section every page under Mer draws. These tests drive the
// rows as a user does: tap them, and read what a screen reader is told.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

Future<ColorScheme> _pump(WidgetTester tester, Widget child) async {
  late ColorScheme cs;
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: Builder(
        builder: (context) {
          cs = Theme.of(context).colorScheme;
          return child;
        },
      ),
    ),
  );
  return cs;
}

SemanticsData _data(WidgetTester tester, String label) => tester
    .getSemantics(find.bySemanticsLabel(RegExp('^$label')))
    .getSemanticsData();

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  group('ButleryListSection', () {
    testWidgets('draws the overline in capitals only when it has a title, '
        'and as a heading of its own', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ListView(
          children: [
            ButleryListSection(
              title: 'Tillsammans',
              rows: [ButleryListRow(label: 'Notiser', onTap: () {})],
            ),
          ],
        ),
      );

      expect(find.text('TILLSAMMANS'), findsOneWidget);
      final heading = _data(tester, 'TILLSAMMANS');
      expect(heading.flagsCollection.isHeader, isTrue);
      // The row under it is not swallowed into the heading's node.
      expect(heading.label, 'TILLSAMMANS');
      handle.dispose();
    });

    testWidgets('a section without a title draws no overline text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        ListView(
          children: [
            ButleryListSection(
              rows: [ButleryListRow(label: 'Logga ut', onTap: () {})],
            ),
          ],
        ),
      );

      expect(find.text('Logga ut'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
      expect(
        find.semantics.byFlag(SemanticsFlag.isHeader),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('a divider sits between rows and never after the last', (
      tester,
    ) async {
      await _pump(
        tester,
        ListView(
          children: [
            ButleryListSection(
              rows: [
                ButleryListRow(label: 'A', onTap: () {}),
                ButleryListRow(label: 'B', onTap: () {}),
                ButleryListRow(label: 'C', onTap: () {}),
              ],
            ),
            ButleryListSection(
              rows: [ButleryListRow(label: 'Ensam', onTap: () {})],
            ),
          ],
        ),
      );

      final first = find.ancestor(
        of: find.text('A'),
        matching: find.byType(ButleryListSection),
      );
      final alone = find.ancestor(
        of: find.text('Ensam'),
        matching: find.byType(ButleryListSection),
      );
      expect(
        find.descendant(of: first, matching: find.byType(Divider)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: alone, matching: find.byType(Divider)),
        findsNothing,
      );
    });
  });

  group('ButleryListRow', () {
    testWidgets('a nav row is one button named by its label and a tap on '
        'its text runs onTap', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        ButleryListRow(
          label: 'Notiser',
          subtitle: 'Vad du får höra av',
          value: 'På',
          onTap: () => taps++,
        ),
      );

      final data = _data(tester, 'Notiser');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.text('Notiser'));
      expect(taps, 1);
      // The value and the subtitle are part of the same row, not other taps.
      await tester.tap(find.text('På'));
      expect(taps, 2);
      handle.dispose();
    });

    testWidgets('a toggle row flips from a tap anywhere on the row and says '
        'whether it is on', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <bool>[];
      var checked = false;
      late StateSetter rebuild;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ButleryListRow.toggle(
              label: 'Lägg till i skafferiet',
              subtitle: 'När du bockar av en vara',
              checked: checked,
              onChanged: changes.add,
            );
          },
        ),
      );

      var data = _data(tester, 'Lägg till i skafferiet');
      expect(data.flagsCollection.isToggled, Tristate.isFalse);
      expect(data.flagsCollection.isButton, isFalse);

      // The subtitle, not the switch, is tapped: the whole row is the control.
      await tester.tap(find.text('När du bockar av en vara'));
      expect(changes, [true]);

      rebuild(() => checked = true);
      await tester.pump();
      data = _data(tester, 'Lägg till i skafferiet');
      expect(data.flagsCollection.isToggled, Tristate.isTrue);

      await tester.tap(find.text('Lägg till i skafferiet'));
      expect(changes, [true, false]);
      handle.dispose();
    });

    testWidgets('a danger row is drawn in the theme error colour and a nav '
        'row is not', (tester) async {
      var taps = 0;
      final cs = await _pump(
        tester,
        Column(
          children: [
            ButleryListRow.danger(label: 'Radera kontot', onTap: () => taps++),
            ButleryListRow(label: 'Logga ut', onTap: () {}),
          ],
        ),
      );

      expect(_textColor(tester, 'Radera kontot'), cs.error);
      expect(_textColor(tester, 'Logga ut'), isNot(cs.error));

      await tester.tap(find.text('Radera kontot'));
      expect(taps, 1);
    });

    testWidgets('a long value takes at most 45 % of the row, on one line, '
        'and leaves the chevron at the end', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const longValue = 'mycket.langt.namn.som.inte.ryms@exempel.example.com';
      await _pump(
        tester,
        ButleryListRow(label: 'E-postadress', value: longValue, onTap: () {}),
      );

      final rowWidth = tester.getSize(find.byType(ButleryListRow)).width;
      final valueText = tester.widget<Text>(find.text(longValue));
      expect(
        tester.getSize(find.text(longValue)).width,
        lessThanOrEqualTo(rowWidth * 0.45),
      );
      expect(valueText.maxLines, 1);
      expect(valueText.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an info row shows its value and is not a button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const ButleryListRow.info(label: 'Version', value: '1.2.3'),
      );

      expect(find.text('1.2.3'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      final data = _data(tester, 'Version');
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('a count is drawn only above zero, and read as its '
        'countLabel', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Column(
          children: [
            ButleryListRow(
              label: 'Vänner & grupper',
              count: 3,
              countLabel: '3 väntar på dig',
              onTap: () {},
            ),
            ButleryListRow(
              label: 'Meddelanden',
              count: 0,
              countLabel: '0 väntar på dig',
              onTap: () {},
            ),
          ],
        ),
      );

      final withCount = find.ancestor(
        of: find.text('Vänner & grupper'),
        matching: find.byType(ButleryListRow),
      );
      expect(
        find.descendant(of: withCount, matching: find.byType(SaffronCount)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: withCount, matching: find.text('3')),
        findsOneWidget,
      );
      expect(_data(tester, 'Vänner & grupper').value, '3 väntar på dig');

      final noCount = find.ancestor(
        of: find.text('Meddelanden'),
        matching: find.byType(ButleryListRow),
      );
      expect(
        find.descendant(of: noCount, matching: find.byType(SaffronCount)),
        findsNothing,
      );
      expect(_data(tester, 'Meddelanden').value, isEmpty);
      handle.dispose();
    });
  });
}
