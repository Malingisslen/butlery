import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/chips/butlery_action_chip.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/common/chips/butlery_removable_chip.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('ButleryFilterChip', () {
    testWidgets('draws the unselected avatar only while the chip is off', (
      tester,
    ) async {
      var selected = false;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: StatefulBuilder(
            builder: (context, setState) => ButleryFilterChip(
              label: 'Vego',
              selected: selected,
              unselectedAvatar: const Icon(Icons.circle, key: Key('avatar')),
              onSelected: (v) => setState(() => selected = v),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('avatar')), findsOneWidget);

      await tester.tap(find.text('Vego'));
      await tester.pumpAndSettle();

      expect(selected, isTrue);
      expect(find.byKey(const Key('avatar')), findsNothing);
    });
  });

  group('ButleryStaticChip', () {
    testWidgets('shows words or a placeholder widget', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const Column(
            children: [
              ButleryStaticChip(label: '+3'),
              ButleryStaticChip(labelWidget: SizedBox(key: Key('skeleton'))),
            ],
          ),
        ),
      );
      expect(find.text('+3'), findsOneWidget);
      expect(find.byKey(const Key('skeleton')), findsOneWidget);
    });

    test('refuses both or neither of label and labelWidget', () {
      expect(() => ButleryStaticChip(), throwsAssertionError);
      expect(
        () => ButleryStaticChip(label: 'a', labelWidget: const SizedBox()),
        throwsAssertionError,
      );
    });
  });

  group('ButleryActionChip', () {
    testWidgets('strikes the words through and shows the glyph', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ButleryActionChip(
            label: 'vegansk',
            icon: ButleryIcons.undo,
            struckThrough: true,
            tooltip: 'Klicka för att återställa',
            onPressed: () => pressed++,
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('vegansk')).style?.decoration,
        TextDecoration.lineThrough,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ButleryIcon && w.icon == ButleryIcons.undo,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('vegansk'));
      expect(pressed, 1);
      expect(find.byTooltip('Klicka för att återställa'), findsOneWidget);
    });
  });

  group('ButleryRemovableChip', () {
    testWidgets('names the chip in a tooltip and removes through the ×', (
      tester,
    ) async {
      var removed = 0;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ButleryRemovableChip(
            label: 'ugnsrätt',
            removeLabel: 'Ta bort',
            icon: ButleryIcons.user,
            tooltip: 'Tillagd av dig',
            onRemove: () => removed++,
          ),
        ),
      );
      expect(find.byTooltip('Tillagd av dig'), findsOneWidget);

      await tester.tap(find.byTooltip('Ta bort'));
      expect(removed, 1);
    });
  });
}
