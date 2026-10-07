import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/tagging/tag_editor_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('the tag editor action row lays out under the app theme', (
    tester,
  ) async {
    final recipe = Recipe(
      core: RecipeCore(
        id: 'r1',
        title: 'Köttbullar',
        description: '',
        ingredients: const [],
        instructions: const [],
        mealType: 'Middag',
        createdBy: 'u1',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      type: RecipeType.personal,
    );

    await tester.pumpWidget(
      createLocalizedTestApp(child: TagEditorDialog(recipe: recipe)),
    );

    expect(tester.takeException(), isNull);
  });
}
