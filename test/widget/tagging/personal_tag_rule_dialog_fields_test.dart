import 'package:butlery/models/tagging/personal_tag_rule.dart';
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

  Future<void> openFromHost(
    WidgetTester tester,
    void Function(PersonalTagRule?) onResult,
  ) async {
    final tag = PersonalTagBuilder().withId('t1').withName('Snabbt').build();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showDialog<PersonalTagRule>(
                  context: context,
                  builder: (_) => PersonalTagRuleDialog(
                    availableTags: [tag],
                    preselectedTagId: 't1',
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Avbryt while idle closes the dialog with a null result', (
    tester,
  ) async {
    // Non-null start so a dialog that never completes cannot read as null.
    PersonalTagRule? result = PersonalTagRule.create(
      tagId: 'sentinel',
      name: 'sentinel',
      conditions: const [],
    );
    await openFromHost(tester, (r) => result = r);
    expect(find.byType(PersonalTagRuleDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
    await tester.pumpAndSettle();

    expect(find.byType(PersonalTagRuleDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('Avbryt is disabled in the frame where a save starts', (
    tester,
  ) async {
    await openFromHost(tester, (_) {});

    await tester.enterText(fieldLabelled('Regelnamn'), 'Snabba rätter');
    final conditionValue = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(conditionValue.last, 'pasta');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Skapa'));
    // The save pops the route in the same call, so this single frame still
    // shows the dialog while it animates out.
    await tester.pump();

    expect(find.byType(PersonalTagRuleDialog), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Avbryt'))
          .onPressed,
      isNull,
    );
  });
}
