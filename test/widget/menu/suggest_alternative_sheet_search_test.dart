import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
