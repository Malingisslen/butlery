import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/dislike_vocabulary.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/ingredient_exclusion.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu_service.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

Recipe _with(String id, List<String> ingredients) => RecipeFactory.build(
  id: id,
  title: id,
  mealType: 'middag',
  ingredients: ingredients,
);

void main() {
  bool excludes(String word, List<String> ingredients) =>
      IngredientExclusion.recipeContainsWord(_with('r', ingredients), word);

  group('"utan X" for a word the dislike vocabulary knows', () {
    test('gives the same answer as "ogillar X" for every key', () {
      final lines = <List<String>>[
        ['2 gula lökar'],
        ['1 vitlök'],
        ['2 vitlöksklyftor'],
        ['1 rödlök'],
        ['1 purjolök'],
        ['1 st lök'],
        ['löken, skivad'],
        ['champinjoner'],
        ['tomatpuré'],
        ['olivolja'],
        ['paprikapulver'],
        ['1 röd paprika'],
        ['mjölk'],
      ];
      for (final key in DislikeVocabulary.keys) {
        for (final ings in lines) {
          expect(
            excludes(key, ings),
            DislikeVocabulary.recipeContainsAny(_with('r', ings), {key}),
            reason: '"utan $key" vs "ogillar $key" on $ings',
          );
        }
      }
    });

    test(
      '"utan lök" keeps a recipe whose only onion-family item is vitlök',
      () {
        expect(excludes('lök', ['2 vitlöksklyftor', '1 vitlök']), isFalse);
      },
    );

    test('"utan lök" drops lök, löken, lökar and the listed compounds', () {
      for (final line in [
        '1 lök',
        'löken',
        '2 lökar',
        '1 rödlök',
        '1 gullök',
        '1 purjolök',
        '1 salladslök',
        '2 schalottenlökar',
      ]) {
        expect(excludes('lök', [line]), isTrue, reason: line);
      }
    });

    test('"utan vitlök" drops vitlök and its compounds but not plain lök', () {
      expect(excludes('vitlök', ['2 vitlöksklyftor']), isTrue);
      expect(excludes('vitlök', ['1 vitlökspulver']), isTrue);
      expect(excludes('vitlök', ['1 gul lök']), isFalse);
    });
  });

  group('"utan X" for a free-text word', () {
    test('matches the word and inflected forms', () {
      expect(excludes('linser', ['2 dl röda linser']), isTrue);
      expect(excludes('linser', ['linserna, sköljda']), isTrue);
      expect(excludes('lins', ['1 dl lins']), isTrue);
    });

    test('matches compounds that start with the word', () {
      expect(excludes('fisk', ['2 msk fisksås']), isTrue);
      expect(excludes('fisk', ['400 g fiskbullar']), isTrue);
      expect(excludes('räkor', ['räkor']), isTrue);
      expect(excludes('räk', ['1 dl räkcocktail']), isTrue);
    });

    test('over-excludes a longer word with the same start', () {
      expect(excludes('ost', ['300 g ostron']), isTrue);
    });

    test('does not match a word that merely contains it', () {
      expect(excludes('ost', ['2 dl bostongurka']), isFalse);
    });
  });

  group('through MenuService', () {
    test(
      '"utan lök" keeps the vitlök-only recipe and drops the lök one',
      () async {
        final service = MenuService(
          lexiconProvider: const CodeLexiconProvider(),
        );
        final menu = await service.generateMenuFromPrompt(
          'en middag utan lök',
          [
            _with('with-onion', ['1 gul lök', '500 g nötfärs']),
            _with('garlic-only', ['3 vitlöksklyftor', '500 g nötfärs']),
          ],
        );

        final ids = [
          for (final l in menu.values)
            for (final r in l) r.id,
        ];
        expect(ids, ['garlic-only']);
      },
    );
  });
}
