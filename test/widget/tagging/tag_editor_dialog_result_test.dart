import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/chips/butlery_removable_chip.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/widgets/tagging/tag_editor_dialog.dart';

import '../../infrastructure/helpers/tagging_test_helper.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

// Callers persist only when the dialog resolves to a non-null value, so the
// cancel path must never hand back the edited overrides.
void main() {
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
      tagResult: TaggingTestHelper.createTagResult(tags: {'kyckling'}),
    ),
    type: RecipeType.personal,
  );

  final sentinel = TagOverrides(
    addedTags: const {'sentinel'},
    removedTags: const {},
    allergenOverrides: const {},
    dietaryOverrides: const {},
    lastEditedAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> openAndEdit(
    WidgetTester tester,
    void Function(TagOverrides?) onResult,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                onResult(await TagEditorDialog.show(context, recipe)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ugnsrätt');
    await tester.tap(find.byTooltip('Lägg till tagg'));
    await tester.pumpAndSettle();
    expect(find.byType(ButleryRemovableChip), findsNWidgets(2));
  }

  testWidgets(
    'Avbryt closes the tag editor and resolves to null even after an edit',
    (tester) async {
      TagOverrides? result = sentinel;
      var resolved = false;
      await openAndEdit(tester, (r) {
        result = r;
        resolved = true;
      });

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(find.byType(TagEditorDialog), findsNothing);
      expect(resolved, isTrue);
      expect(result, isNull);
    },
  );

  testWidgets('Spara resolves to the edited overrides', (tester) async {
    TagOverrides? result;
    await openAndEdit(tester, (r) => result = r);

    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    expect(find.byType(TagEditorDialog), findsNothing);
    expect(result, isNotNull);
    expect(result!.addedTags, contains('ugnsrätt'));
  });
}
