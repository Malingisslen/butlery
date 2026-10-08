import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

/// BUT-2276: AppIconButton and FloatingActionButtonWidget are one button node
/// each for a screen reader, carrying their name, also under an interactive
/// ancestor.
void main() {
  Widget iconButton({VoidCallback? onPressed}) => AppIconButton(
    icon: ButleryIcons.close,
    semanticLabel: 'Stäng',
    onPressed: onPressed,
  );

  Widget fab() => FloatingActionButtonWidget(
    semanticLabel: 'Nytt recept',
    onPressed: () {},
    child: const Icon(ButleryIcons.plus),
  );

  final cases = <(String, Widget, String, bool)>[
    ('AppIconButton', iconButton(onPressed: () {}), 'Stäng', true),
    ('disabled AppIconButton', iconButton(), 'Stäng', false),
    (
      'AppIconButton in a tappable ListTile',
      ListTile(
        title: const Text('Rad'),
        onTap: () {},
        trailing: iconButton(onPressed: () {}),
      ),
      'Stäng',
      true,
    ),
    (
      'AppIconButton inside an InkWell',
      InkWell(
        onTap: () {},
        child: iconButton(onPressed: () {}),
      ),
      'Stäng',
      true,
    ),
    ('FloatingActionButtonWidget', fab(), 'Nytt recept', true),
  ];

  for (final (name, widget, label, enabled) in cases) {
    testWidgets('$name has one button node named "$label"', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(createLocalizedTestApp(child: widget));

      // An IconButton names itself through its tooltip, which screen readers
      // announce as the name.
      String nameOf(SemanticsData d) =>
          d.label.isNotEmpty ? d.label : d.tooltip;
      final buttons = find.semantics
          .byFlag(SemanticsFlag.isButton)
          .evaluate()
          .map((n) => n.getSemanticsData())
          .where((d) => nameOf(d) != 'Rad')
          .toList();
      expect(buttons, hasLength(1));
      expect(nameOf(buttons.single), label);
      expect(
        buttons.single.flagsCollection.isEnabled,
        enabled ? Tristate.isTrue : Tristate.isFalse,
      );
      handle.dispose();
    });
  }
}
