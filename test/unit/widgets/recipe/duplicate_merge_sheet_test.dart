import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/recipe/duplicate_merge_sheet.dart';

Recipe _makeRecipe({
  String id = 'test-id',
  String title = 'Test Recipe',
  String description = '',
  List<String> ingredients = const [],
  List<String> instructions = const [],
  int? timeMinutes,
  int? portions,
  List<String> imageUrls = const [],
  String? sourceUrl,
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      timeMinutes: timeMinutes,
      portions: portions,
      imageUrls: imageUrls,
      sourceUrl: sourceUrl,
      mealType: 'dinner',
    ),
    type: RecipeType.personal,
  );
}

void main() {
  group('DuplicateMergeResult.buildMergedRecipe', () {
    test('prefers more ingredients from new recipe', () {
      final existing = _makeRecipe(
        id: 'existing-1',
        ingredients: ['mjol', 'agg'],
      );
      final newRecipe = _makeRecipe(
        id: 'new-1',
        ingredients: ['mjol', 'agg', 'mjolk', 'smor'],
      );

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.ingredients.length, 4);
      expect(merged.ingredients, newRecipe.ingredients);
    });

    test('prefers more instructions from existing recipe', () {
      final existing = _makeRecipe(
        id: 'existing-1',
        instructions: ['step 1', 'step 2', 'step 3'],
      );
      final newRecipe = _makeRecipe(
        id: 'new-1',
        instructions: ['step 1'],
      );

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.instructions.length, 3);
    });

    test('prefers non-null time from new recipe', () {
      final existing = _makeRecipe(id: 'existing-1', timeMinutes: null);
      final newRecipe = _makeRecipe(id: 'new-1', timeMinutes: 30);

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.timeMinutes, 30);
    });

    test('keeps existing time when new is null', () {
      final existing = _makeRecipe(id: 'existing-1', timeMinutes: 45);
      final newRecipe = _makeRecipe(id: 'new-1', timeMinutes: null);

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.timeMinutes, 45);
    });

    test('prefers new recipe images when available', () {
      final existing = _makeRecipe(id: 'existing-1', imageUrls: []);
      final newRecipe = _makeRecipe(
        id: 'new-1',
        imageUrls: ['https://example.com/image.jpg'],
      );

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.imageUrls.length, 1);
    });

    test('keeps existing images when new has none', () {
      final existing = _makeRecipe(
        id: 'existing-1',
        imageUrls: ['https://example.com/old.jpg'],
      );
      final newRecipe = _makeRecipe(id: 'new-1', imageUrls: []);

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.imageUrls.length, 1);
    });

    test('preserves existing recipe id', () {
      final existing = _makeRecipe(id: 'existing-1');
      final newRecipe = _makeRecipe(id: 'new-1');

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.id, 'existing-1');
    });

    test('prefers non-null sourceUrl', () {
      final existing = _makeRecipe(id: 'existing-1', sourceUrl: null);
      final newRecipe = _makeRecipe(
        id: 'new-1',
        sourceUrl: 'https://example.com/recipe',
      );

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.sourceUrl, 'https://example.com/recipe');
    });

    test('prefers longer description', () {
      final existing = _makeRecipe(
        id: 'existing-1',
        description: 'Short',
      );
      final newRecipe = _makeRecipe(
        id: 'new-1',
        description:
            'A much longer and more detailed description of the recipe',
      );

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.description, newRecipe.description);
    });

    test('prefers non-null portions', () {
      final existing = _makeRecipe(id: 'existing-1', portions: null);
      final newRecipe = _makeRecipe(id: 'new-1', portions: 4);

      final result = DuplicateMergeResult(
        choice: DuplicateMergeChoice.mergeBestFields,
        existingRecipe: existing,
        newRecipe: newRecipe,
        similarityScore: 0.8,
      );

      final merged = result.buildMergedRecipe();
      expect(merged.portions, 4);
    });
  });

  group('DuplicateMergeChoice', () {
    test('all enum values exist', () {
      expect(DuplicateMergeChoice.values, hasLength(4));
      expect(DuplicateMergeChoice.values,
          contains(DuplicateMergeChoice.keepExisting));
      expect(DuplicateMergeChoice.values,
          contains(DuplicateMergeChoice.replaceWithNew));
      expect(DuplicateMergeChoice.values,
          contains(DuplicateMergeChoice.saveAsNew));
      expect(DuplicateMergeChoice.values,
          contains(DuplicateMergeChoice.mergeBestFields));
    });
  });
}
