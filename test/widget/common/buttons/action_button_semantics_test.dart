import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

/// BUT-2253: a screen reader meets each ActionButtons button once — one
/// button node carrying the name, not an outer Semantics button around the
/// Material button's own node.
void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
  });

  for (final (name, build, expectedLabel, enabled)
      in <
        (
          String,
          Widget Function(BuildContext),
          String,
          bool,
        )
      >[
        (
          'actionButton',
          (context) => ActionButtons.actionButton(
            context,
            label: 'Spara',
            onPressed: () {},
          ),
          'Spara',
          true,
        ),
        (
          'outlinedButton with a semanticLabel',
          (context) => ActionButtons.outlinedButton(
            context,
            label: 'Avböj',
            semanticLabel: 'Avböj Erik Sandell',
            onPressed: () {},
          ),
          'Avböj Erik Sandell',
          true,
        ),
        (
          'disabled actionButton',
          (context) => ActionButtons.actionButton(context, label: 'Spara'),
          'Spara',
          false,
        ),
        (
          'textButton',
          (context) => ActionButtons.textButton(
            context,
            label: 'Hoppa över',
            onPressed: () {},
          ),
          'Hoppa över',
          true,
        ),
        (
          'largeButton',
          (context) => ActionButtons.largeButton(
            context,
            label: 'Arkivera',
            icon: ButleryIcons.archive,
            onPressed: () {},
          ),
          'Arkivera',
          true,
        ),
      ]) {
    testWidgets('$name is one button node named "$expectedLabel"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(child: Builder(builder: build)),
      );

      final buttons = find.semantics
          .byFlag(SemanticsFlag.isButton)
          .evaluate()
          .toList();
      expect(buttons, hasLength(1));
      final data = buttons.single.getSemanticsData();
      expect(data.label, expectedLabel);
      expect(
        data.flagsCollection.isEnabled,
        enabled ? Tristate.isTrue : Tristate.isFalse,
      );
      handle.dispose();
    });
  }
}
