/// BUT-2506: pasted recipes lost ingredient rows (some carrying allergens)
/// and sometimes the title. One case per cause.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/layout/line_reflow.dart';
import 'package:butlery/services/import/parsers/heading_word_lists.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/import/parsers/text_import_normalizer.dart';
import 'package:butlery/services/import/text_import_strategy.dart';

Future<List<String>> _ingredients(String text) async =>
    (await TextImportStrategy().import(text)).recipe!.ingredients;

void main() {
  group('isValidIngredient', () {
    test('keeps serving rows that carry an allergen', () {
      expect(
        RecipeSectionDetector.isValidIngredient(
          'Riven parmesan till servering.',
        ),
        isTrue,
      );
      expect(
        RecipeSectionDetector.isValidIngredient('Ströbröd att strö över'),
        isTrue,
      );
    });

    test('still refuses a step of the same length', () {
      expect(
        RecipeSectionDetector.isValidIngredient(
          'skär laxen i tärningar och stek dem snabbt.',
        ),
        isFalse,
      );
    });

    test('a store offer is page text', () {
      expect(
        HeadingWordLists.isStoreOffer('Köp 3 betala för 2 på all pasta'),
        isTrue,
      );
      expect(
        RecipeSectionDetector.isValidIngredient(
          'Köp 3 betala för 2 på all pasta',
        ),
        isFalse,
      );
    });
  });

  group('inline ingredient list', () {
    test('every item under "Ingredienser:" becomes its own row', () async {
      final rows = await _ingredients(
        'Enkel tomatsoppa\n\n'
        'Ingredienser: 1 gul lök, 2 burkar krossade tomater, 5 dl buljong, salt\n\n'
        'Gör så här: Fräs löken mjuk. Tillsätt tomater och buljong och koka.',
      );
      expect(rows.join('|'), contains('lök'));
      expect(rows.join('|'), contains('krossade tomater'));
      expect(rows.last, 'salt');
    });

    test('the header colon never starts the first step', () {
      final out = TextImportNormalizer.preprocessText(
        'Soppa\nIngredienser: 1 lök, 2 dl vatten\nGör så här: Fräs löken mjuk.',
      );
      expect(out.split('\n').where((l) => l.startsWith(':')), isEmpty);
    });

    test('a method sentence with commas is left whole', () {
      final out = TextImportNormalizer.preprocessText(
        'Soppa\nIngredienser\n1 lök\nGör så här\nTillsätt 2 dl vatten, 3 ägg, salt.',
      );
      expect(out, contains('Tillsätt 2 dl vatten, 3 ägg, salt.'));
    });

    test('a decimal comma is not an item break', () {
      final rows = TextImportNormalizer.preprocessText(
        'Soppa\nIngredienser: 0,5 dl grädde, 2 ägg, salt\nGör så här: Koka.',
      ).split('\n');
      expect(rows, containsAll(['0,5 dl grädde', '2 ägg', 'salt']));
      expect(rows, isNot(contains('0')));
    });

    test('a note after an item stays with it', () {
      final rows = TextImportNormalizer.preprocessText(
        'Soppa\nIngredienser: 1 lök, skuren i tärningar, 2 dl vatten, helst kallt\nGör så här: Koka.',
      ).split('\n');
      expect(rows, contains('1 lök, skuren i tärningar'));
      expect(rows, contains('2 dl vatten, helst kallt'));
    });

    test('the comma split only happens straight under the header', () {
      final out = TextImportNormalizer.preprocessText(
        'Soppa\nIngredienser\n1 lök\nGör så här\nKoka 2 dl vatten, 3 ägg, 1 msk smör.',
      );
      expect(out, contains('Koka 2 dl vatten, 3 ägg, 1 msk smör.'));
    });
  });

  group('hyphenated word', () {
    test('a word cut over two lines is one row', () async {
      expect(
        joinHyphenatedWords('2 tsk stött kar-\ndemumma'),
        '2 tsk stött kardemumma',
      );
      expect(
        joinHyphenatedWords('Potatis-\noch purjolökssoppa'),
        'Potatis- och purjolökssoppa',
      );
    });
  });

  group('title', () {
    test(
      'a lowercase one-word dish name above a quantity row is the title',
      () async {
        final result = await TextImportStrategy().import(
          'korvstroganoff\n\n400 g falukorv\n1 gul lök\n2 dl matlagningsgrädde\n\n'
          'Gör så här\nStek korven. Tillsätt grädden och låt sjuda.',
        );
        expect(result.recipe!.title, 'korvstroganoff');
      },
    );
  });
}
