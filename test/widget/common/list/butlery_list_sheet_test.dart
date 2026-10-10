// The bottom sheets Mer opens for a choice: the picked value comes back to
// the caller, the current one is marked for a screen reader, and dismissing
// the sheet answers nothing.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

const _options = <(String, String)>[
  ('system', 'Följ telefonen'),
  ('light', 'Ljust'),
  ('dark', 'Mörkt'),
];

class _Opener {
  _Opener(this.tester);

  final WidgetTester tester;
  String? result = 'unanswered';

  Future<void> open({String selected = 'light'}) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showButleryChoiceSheet<String>(
                context,
                title: 'Tema',
                options: _options,
                selected: selected,
              );
            },
            child: const Text('Öppna'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öppna'));
    await tester.pumpAndSettle();
  }
}

SemanticsData _row(WidgetTester tester, String label) => tester
    .getSemantics(find.bySemanticsLabel(RegExp('^$label')))
    .getSemanticsData();

void main() {
  group('showButleryChoiceSheet', () {
    testWidgets('returns the value of the row that was tapped and closes', (
      tester,
    ) async {
      final opener = _Opener(tester);
      await opener.open();

      expect(find.text('Tema'), findsOneWidget);
      for (final option in _options) {
        expect(find.text(option.$2), findsOneWidget);
      }

      await tester.tap(find.text('Mörkt'));
      await tester.pumpAndSettle();

      expect(opener.result, 'dark');
      expect(find.text('Tema'), findsNothing);
    });

    testWidgets('tapping the row that is already selected still answers '
        'with it', (tester) async {
      final opener = _Opener(tester);
      await opener.open(selected: 'light');

      await tester.tap(find.text('Ljust'));
      await tester.pumpAndSettle();

      expect(opener.result, 'light');
    });

    testWidgets('marks only the current choice as selected for a screen '
        'reader', (tester) async {
      final handle = tester.ensureSemantics();
      final opener = _Opener(tester);
      await opener.open(selected: 'light');

      expect(
        _row(tester, 'Ljust').flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        _row(tester, 'Mörkt').flagsCollection.isSelected,
        Tristate.isFalse,
      );
      expect(
        _row(tester, 'Följ telefonen').flagsCollection.isSelected,
        Tristate.isFalse,
      );
      // Every choice is a button that can be activated.
      expect(_row(tester, 'Mörkt').flagsCollection.isButton, isTrue);
      expect(_row(tester, 'Mörkt').hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('dismissing the sheet answers null', (tester) async {
      final opener = _Opener(tester);
      await opener.open();

      // Tap the scrim above the sheet.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(find.text('Tema'), findsNothing);
      expect(opener.result, isNull);
    });
  });

  group('showButleryListSheet', () {
    testWidgets('hands its rows the sheet context, so a row can close the '
        'sheet with a value', (tester) async {
      int? result = -1;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showButleryListSheet<int>(
                  context,
                  title: 'Säkerhetskopia',
                  rows: (sheetContext) => [
                    ButleryListRow(
                      label: 'Ladda ner',
                      onTap: () => Navigator.of(sheetContext).pop(1),
                    ),
                    ButleryListRow(
                      label: 'Återställ',
                      onTap: () => Navigator.of(sheetContext).pop(2),
                    ),
                  ],
                );
              },
              child: const Text('Öppna'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öppna'));
      await tester.pumpAndSettle();
      expect(find.text('Säkerhetskopia'), findsOneWidget);

      await tester.tap(find.text('Återställ'));
      await tester.pumpAndSettle();

      expect(result, 2);
      expect(find.text('Säkerhetskopia'), findsNothing);
    });
  });
}
