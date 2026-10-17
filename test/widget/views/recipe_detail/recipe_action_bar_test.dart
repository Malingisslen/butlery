import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/views/recipe_detail/recipe_action_bar.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late AppLocalizations l10n;
  var started = 0;
  var saved = 0;
  var listed = 0;

  Future<void> pump(
    WidgetTester tester, {
    required bool isOthersRecipe,
    bool allAtHome = false,
    double width = 400,
  }) async {
    started = saved = listed = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: width,
                child: RecipeActionBar(
                  isOthersRecipe: isOthersRecipe,
                  onStartCooking: () => started++,
                  onSaveToMyKitchen: () => saved++,
                  onAddToShoppingList: () => listed++,
                  addToShoppingListLabel: 'Lägg 2 varor i inköpslistan',
                  allAtHome: allAtHome,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('own recipe: start cooking and add to the list', (tester) async {
    await pump(tester, isOthersRecipe: false);

    await tester.tap(
      find.byKey(const ValueKey('test-recipe-detail-start-cooking')),
    );
    await tester.tap(
      find.byKey(const ValueKey('test-recipe-detail-add-to-list')),
    );
    expect([started, saved, listed], [1, 0, 1]);
    expect(
      find.byKey(const ValueKey('test-recipe-detail-save-copy')),
      findsNothing,
    );
  });

  testWidgets("someone else's recipe: save leads, start cooking follows", (
    tester,
  ) async {
    await pump(tester, isOthersRecipe: true);

    final save = tester.getTopLeft(
      find.byKey(const ValueKey('test-recipe-detail-save-copy')),
    );
    final start = tester.getTopLeft(
      find.byKey(const ValueKey('test-recipe-detail-start-cooking')),
    );
    expect(save.dx, lessThan(start.dx));

    await tester.tap(
      find.byKey(const ValueKey('test-recipe-detail-save-copy')),
    );
    expect([started, saved, listed], [0, 1, 0]);
  });

  testWidgets('pantry covers everything: text instead of the list button', (
    tester,
  ) async {
    await pump(tester, isOthersRecipe: false, allAtHome: true);

    expect(find.byKey(RecipeActionBar.allAtHomeKey), findsOneWidget);
    expect(find.text(l10n.recipeAllAtHome), findsOneWidget);
    expect(
      find.byKey(const ValueKey('test-recipe-detail-add-to-list')),
      findsNothing,
    );
  });

  testWidgets('below 360 dp the buttons stack', (tester) async {
    await pump(tester, isOthersRecipe: false, width: 320);

    final start = tester.getTopLeft(
      find.byKey(const ValueKey('test-recipe-detail-start-cooking')),
    );
    final list = tester.getTopLeft(
      find.byKey(const ValueKey('test-recipe-detail-add-to-list')),
    );
    expect(list.dy, greaterThan(start.dy));
    expect(list.dx, start.dx);
  });
}
