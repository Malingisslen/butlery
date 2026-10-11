// BUT-2261 finding 12: the "Vad ska vi äta?" dialog in recipe mode; and the
// free-text poll's fields, whose labels stand above the box.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/messaging/poll_creation_dialog.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/field_finder.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> pumpRecipeDialog(WidgetTester tester) async {
    // The phone width the finding was reported at.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: PollCreationDialog(
          creatorId: 'user-1',
          recipeOptions: [
            RecipeFactory.build(id: 'r1', title: 'Köttbullar'),
            RecipeFactory.build(id: 'r2', title: 'Lax'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lays out "Skapa omröstning" with its label', (tester) async {
    await pumpRecipeDialog(tester);

    // A layout failure is reported by the test binding and fails the test on
    // its own; these pin that the button is there, sized and enabled.
    final button = find.widgetWithText(ElevatedButton, 'Skapa omröstning');
    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, greaterThan(0));
    expect(tester.widget<ElevatedButton>(button).enabled, isTrue);
  });

  testWidgets('gives each recipe row its own screen-reader label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpRecipeDialog(tester);

    final row = tester.getSemantics(find.text('Köttbullar'));
    expect(row.label, 'Köttbullar\n4 portioner');
    semantics.dispose();
  });

  testWidgets('the free-text poll names its question and options', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const PollCreationDialog(creatorId: 'user-1'),
      ),
    );
    await tester.pumpAndSettle();

    final create = find.widgetWithText(ElevatedButton, 'Skapa omröstning');
    expect(tester.widget<ElevatedButton>(create).enabled, isFalse);

    await tester.enterText(
      fieldLabelled('Fråga', type: TextField),
      'Vad blir det?',
    );
    await tester.enterText(
      fieldLabelled('Alternativ 1', type: TextField),
      'Lax',
    );
    await tester.pump();
    expect(tester.widget<ElevatedButton>(create).enabled, isFalse);
    await tester.enterText(
      fieldLabelled('Alternativ 2', type: TextField),
      'Tacos',
    );
    await tester.pump();
    expect(tester.widget<ElevatedButton>(create).enabled, isTrue);

    expect(find.byTooltip('Ta bort alternativ'), findsNothing);
    await tester.tap(find.text('Lägg till alternativ'));
    await tester.pump();
    expect(fieldLabelled('Alternativ 3', type: TextField), findsOneWidget);
    expect(find.byTooltip('Ta bort alternativ'), findsNWidgets(3));
  });
}
