/// Megagenomgång A23: a greyed Spara says why.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/recipe_form/recipe_save_blocker.dart';
import 'package:butlery/widgets/recipe/recipe_form/save_blocked_hint.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  testWidgets('each missing piece has its own sentence', (tester) async {
    const expected = {
      RecipeSaveBlocker.title: 'Skriv en titel för att kunna spara.',
      RecipeSaveBlocker.ingredients:
          'Lägg till minst en ingrediens för att kunna spara.',
      RecipeSaveBlocker.instructions:
          'Lägg till minst ett steg för att kunna spara.',
    };
    for (final entry in expected.entries) {
      await tester.pumpWidget(
        createLocalizedTestApp(child: SaveBlockedHint(blocker: entry.key)),
      );

      expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
    }
  });
}
