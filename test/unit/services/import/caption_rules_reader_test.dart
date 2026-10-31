import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/services/import/caption_rules_reader.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_support/base_unit_test.dart';

const _structured = '''Krämig pasta

Ingredienser:
300 g pasta
2 dl grädde
1 vitlöksklyfta

Gör så här:
Koka pastan enligt paketet.
Fräs vitlöken och häll i grädden, låt puttra.''';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<Recipe?> read(String text, {String? fallbackTitle}) =>
      CaptionRulesReader().read(
        text,
        artefactType: SourceArtefactType.tiktokCaption,
        sourceUrl: 'https://www.tiktok.com/@a/video/1',
        fallbackTitle: fallbackTitle,
      );

  test('a caption laid out as a recipe is read without AI, keeping the raw '
      'caption and the post it came from', () async {
    final recipe = await read(_structured);

    expect(recipe, isNotNull);
    expect(recipe!.title, 'Krämig pasta');
    expect(recipe.ingredients, hasLength(3));
    expect(recipe.instructions, isNotEmpty);
    expect(recipe.sourceUrl, 'https://www.tiktok.com/@a/video/1');
    expect(recipe.core.sourceArtefact?.type, SourceArtefactType.tiktokCaption);
    expect(recipe.core.sourceArtefact?.payload, _structured);
  });

  test('a caption of hashtags finds no recipe, although the text parser '
      'calls it a success', () async {
    expect(
      await read('Bästa pastan jag gjort! Följ för mer #pasta #middag'),
      isNull,
    );
  });

  test('steps without ingredients find no recipe', () async {
    expect(
      await read(
        'Krämig pasta på 15 min. Koka pastan, fräs vitlök i smör, häll i '
        'grädde och parmesan, blanda. Klart! #pasta',
      ),
      isNull,
    );
  });

  test(
    'a title made from a hashtag line gives way to the fallback title',
    () async {
      final recipe = await read(
        '#pasta #middag\n\n$_structured'.replaceFirst('Krämig pasta\n\n', ''),
        fallbackTitle: 'Krämig pasta',
      );

      expect(recipe, isNotNull);
      expect(recipe!.title, 'Krämig pasta');
    },
  );

  group('holdsRecipe', () {
    Recipe recipeWith(List<String> ingredients, List<String> steps) =>
        Recipe.personal(
          title: 'x',
          description: '',
          mealType: 'dinner',
          ingredients: ingredients,
          instructions: steps,
        );

    test('needs at least two ingredients and one step', () {
      expect(
        CaptionRulesReader.holdsRecipe(recipeWith(['a', 'b'], ['c'])),
        isTrue,
      );
      expect(
        CaptionRulesReader.holdsRecipe(recipeWith(['a'], ['c'])),
        isFalse,
      );
      expect(
        CaptionRulesReader.holdsRecipe(recipeWith(['a', 'b'], [])),
        isFalse,
      );
      expect(CaptionRulesReader.holdsRecipe(null), isFalse);
    });

    test('blank lines count as nothing', () {
      expect(
        CaptionRulesReader.holdsRecipe(recipeWith(['a', ' '], ['c'])),
        isFalse,
      );
      expect(
        CaptionRulesReader.holdsRecipe(recipeWith(['a', 'b'], [' '])),
        isFalse,
      );
    });

    test('a failed read never counts, whatever recipe it carries', () {
      expect(
        CaptionRulesReader.foundRecipe(ImportResult.failure('nej')),
        isFalse,
      );
    });
  });
}
