// The rule dialog's name field and tag dropdown follow Komponentark v1 §11:
// each label stands above its box, and a refused form shows each error
// with a glyph.

import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/tagging/personal_tag_rule_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/builders/personal_tag_builder.dart';
import '../../infrastructure/helpers/field_finder.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: PersonalTagRuleDialog(
          availableTags: [PersonalTagBuilder().withName('Snabbt').build()],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder glyphIn(Finder field) => find.descendant(
    of: field,
    matching: find.byWidgetPredicate(
      (w) => w is ButleryIcon && w.icon == ButleryIcons.info,
    ),
  );

  testWidgets('the name and tag labels stand above their boxes', (
    tester,
  ) async {
    await pumpDialog(tester);

    for (final (label, type) in [
      ('Regelnamn', TextFormField),
      ('Tillämpa på tagg', DropdownButtonFormField<String>),
    ]) {
      expect(fieldLabelled(label, type: type), findsOneWidget, reason: label);
      expect(
        find.descendant(
          of: find.byType(InputDecorator),
          matching: find.text(label),
        ),
        findsNothing,
        reason: label,
      );
    }
  });

  testWidgets('an empty name and no tag are refused with a glyph each', (
    tester,
  ) async {
    await pumpDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Skapa'));
    await tester.pumpAndSettle();

    final name = fieldLabelled('Regelnamn');
    expect(
      find.descendant(of: name, matching: find.text('Ange ett regelnamn')),
      findsOneWidget,
    );
    expect(glyphIn(name), findsOneWidget);
    expect(
      glyphIn(
        fieldLabelled(
          'Tillämpa på tagg',
          type: DropdownButtonFormField<String>,
        ),
      ),
      findsOneWidget,
    );
  });
}
