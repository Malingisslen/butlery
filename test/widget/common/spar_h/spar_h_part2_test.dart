// Spår H del 2: the gaps the view tracks found in the shared components.

import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/chips/butlery_removable_chip.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/list/butlery_radio_row.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

Widget _app(Widget child) =>
    createLocalizedTestApp(child: Scaffold(body: child));

Color? _edgeColour(WidgetTester tester) {
  final boxes = tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .where((b) => b.position == DecorationPosition.foreground);
  if (boxes.isEmpty) return null;
  return ((boxes.first.decoration as BoxDecoration).border! as Border)
      .top
      .color;
}

void main() {
  group('ButleryRemovableChip', () {
    testWidgets('the × calls onRemove and is named for what it removes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var removed = 0;
      await tester.pumpWidget(
        _app(
          ButleryRemovableChip(
            label: 'Anna',
            removeLabel: 'Ta bort Anna',
            onRemove: () => removed++,
          ),
        ),
      );
      expect(find.text('Anna'), findsOneWidget);
      expect(find.byTooltip('Ta bort Anna'), findsOneWidget);
      await tester.tap(find.byTooltip('Ta bort Anna'));
      expect(removed, 1);
      handle.dispose();
    });
  });

  group('StyledInput', () {
    testWidgets('passes capitalisation, autocorrect and submit through', (
      tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        _app(
          StyledInput(
            label: 'Namn',
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            onSubmitted: (v) => submitted = v,
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textCapitalization, TextCapitalization.words);
      expect(field.autocorrect, isFalse);
      await tester.enterText(find.byType(TextField), 'Gruppen');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, 'Gruppen');
    });

    testWidgets('.text takes textCapitalization', (tester) async {
      await tester.pumpWidget(
        _app(
          const StyledInput.text(
            label: 'Titel',
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textCapitalization, TextCapitalization.sentences);
    });
  });

  group('ButleryRadioRow', () {
    testWidgets('a tap moves the group value', (tester) async {
      String? chosen = 'a';
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => RadioGroup<String>(
              groupValue: chosen,
              onChanged: (v) => setState(() => chosen = v),
              child: const Column(
                children: [
                  ButleryRadioRow<String>(title: 'Första', value: 'a'),
                  ButleryRadioRow<String>(title: 'Andra', value: 'b'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Andra'));
      await tester.pump();
      expect(chosen, 'b');
      expect(
        tester.getSize(find.byType(RadioListTile<String>).first).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('ButleryRadioRow disabled', () {
    testWidgets('a disabled row ignores taps and shows its subtitle', (
      tester,
    ) async {
      String? chosen = 'a';
      await tester.pumpWidget(
        _app(
          RadioGroup<String>(
            groupValue: chosen,
            onChanged: (v) => chosen = v,
            child: const ButleryRadioRow<String>(
              title: 'Andra',
              subtitle: 'Förklaring',
              value: 'b',
              enabled: false,
            ),
          ),
        ),
      );
      expect(find.text('Förklaring'), findsOneWidget);
      await tester.tap(find.text('Andra'), warnIfMissed: false);
      expect(chosen, 'a');
    });
  });

  group('ButleryItemRow', () {
    testWidgets('a long press fires on a row with no tap', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(ButleryItemRow(title: 'Anna', onLongPress: () => pressed++)),
      );
      await tester.longPress(find.text('Anna'));
      expect(pressed, 1);
    });

    testWidgets('the error edge is drawn and a subtitle widget replaces text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ButleryItemRow(
            title: 'Anna',
            edge: ButleryItemRowEdge.error,
            subtitleWidget: Text('Kunde inte tas bort'),
          ),
        ),
      );
      expect(find.text('Kunde inte tas bort'), findsOneWidget);
      final cs = Theme.of(tester.element(find.text('Anna'))).colorScheme;
      expect(_edgeColour(tester), cs.error);
    });

    testWidgets('selected edge uses ink and none draws no edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ButleryItemRow(
            title: 'Anna',
            edge: ButleryItemRowEdge.selected,
          ),
        ),
      );
      final cs = Theme.of(tester.element(find.text('Anna'))).colorScheme;
      expect(_edgeColour(tester), cs.onSurface);
      await tester.pumpWidget(_app(const ButleryItemRow(title: 'Anna')));
      expect(_edgeColour(tester), isNull);
    });

    testWidgets('excludeTitleSemantics keeps the title out of the node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          ButleryItemRow(
            title: 'Anna',
            excludeTitleSemantics: true,
            onTap: () {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('Anna'), findsNothing);
      await tester.pumpWidget(
        _app(ButleryItemRow(title: 'Anna', onTap: () {})),
      );
      expect(find.bySemanticsLabel('Anna'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ButleryTextButton', () {
    testWidgets('semanticLabel replaces the visible words and keeps the tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          ButleryTextButton(
            label: 'Avbryt',
            semanticLabel: 'Avbryt förfrågan',
            tone: ButleryTextButtonTone.warning,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.bySemanticsLabel('Avbryt förfrågan'), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Avbryt förfrågan'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Avbryt förfrågan'));
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('warning reads in text.warning', (tester) async {
      await tester.pumpWidget(
        _app(
          ButleryTextButton(
            label: 'Avbryt',
            tone: ButleryTextButtonTone.warning,
            onPressed: () {},
          ),
        ),
      );
      final cs = Theme.of(tester.element(find.text('Avbryt'))).colorScheme;
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppModeColors.textWarning(cs.brightness),
      );
    });

    testWidgets('onErrorBanner reads in onErrorContainer', (tester) async {
      await tester.pumpWidget(
        _app(
          ButleryTextButton(
            label: 'Försök igen',
            tone: ButleryTextButtonTone.onErrorBanner,
            onPressed: () {},
          ),
        ),
      );
      final cs = Theme.of(tester.element(find.text('Försök igen'))).colorScheme;
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        cs.onErrorContainer,
      );
    });
  });

  group('ButleryProgressDialog', () {
    testWidgets('says what is happening and offers no button', (tester) async {
      await tester.pumpWidget(
        _app(const ButleryProgressDialog(message: 'Laddar upp bilden')),
      );
      expect(find.text('Laddar upp bilden'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('passes a measured value on to the plate line', (tester) async {
      await tester.pumpWidget(
        _app(const ButleryProgressDialog(message: 'Laddar', value: 0.5)),
      );
      final line = tester.widget<PlateLineMessage>(
        find.byType(PlateLineMessage),
      );
      expect(line.value, 0.5);
    });
  });
}
