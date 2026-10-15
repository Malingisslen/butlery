import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/tagging/tag_editor_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Recipe recipe() => Recipe(
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

  // The heading above the add-tag field is its visible label, so the field
  // carries the same words for screen readers, and an empty tag is refused
  // with the error glyph.
  testWidgets('the add-tag field is named and refuses an empty tag', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(child: TagEditorDialog(recipe: recipe())),
    );
    await tester.pumpAndSettle();

    final field = find.byType(TextFormField);
    // The section heading and the field's own wrapper both carry the words.
    expect(find.bySemanticsLabel('Lägg till ny tagg'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Lägg till tagg'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: field, matching: find.text('Ange en tagg')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: field,
        matching: find.byWidgetPredicate(
          (w) => w is ButleryIcon && w.icon == ButleryIcons.info,
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

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
