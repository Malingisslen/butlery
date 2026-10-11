import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/menu/suggest_alternative_sheet.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets(
    'the shared search box narrows the dishes and its clear restores them',
    (
      tester,
    ) async {
      final recipes = [
        RecipeFactory.build(id: 'a', title: 'Ärtsoppa', imageUrls: const []),
        RecipeFactory.build(id: 'b', title: 'Lasagne', imageUrls: const []),
      ];
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => SuggestAlternativeSheet.show(
                context,
                availableRecipes: recipes,
              ),
              child: const Text('öppna'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öppna'));
      await tester.pumpAndSettle();

      expect(find.byType(ButlerySearchBox), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'lasa');
      await tester.pump();
      expect(find.text('Ärtsoppa'), findsNothing);
      expect(find.text('Lasagne'), findsOneWidget);

      await tester.tap(find.byIcon(ButleryIcons.x));
      await tester.pump();
      expect(find.text('Ärtsoppa'), findsOneWidget);
    },
  );

  group('with no dish to offer', () {
    Future<void> open(
      WidgetTester tester,
      List<Recipe> recipes, {
      List<String> exclude = const [],
    }) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => SuggestAlternativeSheet.show(
                context,
                availableRecipes: recipes,
                excludeRecipeIds: exclude,
              ),
              child: const Text('öppna'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öppna'));
      await tester.pumpAndSettle();
    }

    bool fieldEnabled(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

    testWidgets('an empty library turns the search off and says so', (
      tester,
    ) async {
      await open(tester, const []);
      expect(fieldEnabled(tester), isFalse);
      expect(find.text('Inget att söka i ännu'), findsOneWidget);
      expect(
        find.text(AppLocalizationsSv().menuVoteNoAlternatives),
        findsOneWidget,
      );
    });

    testWidgets('every dish already on the menu counts as none to offer', (
      tester,
    ) async {
      await open(
        tester,
        [
          RecipeFactory.build(id: 'a', title: 'Ärtsoppa', imageUrls: const []),
        ],
        exclude: const ['a'],
      );
      expect(fieldEnabled(tester), isFalse);
      expect(find.text('Inget att söka i ännu'), findsOneWidget);
    });

    testWidgets('a dish to offer keeps the search on', (tester) async {
      await open(tester, [
        RecipeFactory.build(id: 'a', title: 'Ärtsoppa', imageUrls: const []),
      ]);
      expect(fieldEnabled(tester), isTrue);
      expect(find.text('Inget att söka i ännu'), findsNothing);
    });
  });
}
