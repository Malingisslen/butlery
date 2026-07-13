/// Voice-transcript assembler tests (voice import plan, roadmap #2).
///
/// Intention: prove that spoken guided-section transcripts assemble into
/// the canonical Swedish recipe text the rule-based parser expects — the
/// cost lever that keeps dictated imports off the paid LLM tier. The
/// ingredient line-split is the risky part: it must split enumerations
/// ("tre ägg och en gul lök") without splitting compound ingredients
/// ("salt och peppar").
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/voice_transcript_assembler.dart';

void main() {
  group('splitSpokenIngredients', () {
    test('splits comma-separated enumeration into lines', () {
      expect(
        splitSpokenIngredients(
          '500 gram köttfärs, 2 deciliter mjölk, en gul lök',
        ),
        ['500 gram köttfärs', '2 deciliter mjölk', 'en gul lök'],
      );
    });

    test('splits "och" before a quantity', () {
      expect(
        splitSpokenIngredients('två deciliter mjölk och tre ägg'),
        ['två deciliter mjölk', 'tre ägg'],
      );
    });

    test('final "och" in an Oxford-style spoken list splits', () {
      expect(
        splitSpokenIngredients(
          'två deciliter mjölk, tre ägg och en gul lök',
        ),
        ['två deciliter mjölk', 'tre ägg', 'en gul lök'],
      );
    });

    test('Swedish decimal commas survive: "1,5 dl" is ONE quantity', () {
      // Whisper renders "en och en halv deciliter" as "1,5 dl" — splitting
      // inside the number corrupts amounts (review finding #2).
      expect(splitSpokenIngredients('1,5 dl grädde'), ['1,5 dl grädde']);
      expect(
        splitSpokenIngredients('500 g köttfärs, 1,5 dl mjölk och två ägg'),
        ['500 g köttfärs', '1,5 dl mjölk', 'två ägg'],
      );
    });

    test('does NOT split compound ingredients without a quantity', () {
      // "salt och peppar" is one line — "och" not followed by a quantity.
      expect(
        splitSpokenIngredients('salt och peppar'),
        ['salt och peppar'],
      );
    });

    test('mixed: compound survives inside an enumeration', () {
      expect(
        splitSpokenIngredients('en burk krossade tomater, salt och peppar'),
        ['en burk krossade tomater', 'salt och peppar'],
      );
    });

    test('"samt" splits like "och"', () {
      expect(
        splitSpokenIngredients('fyra potatisar samt två morötter'),
        ['fyra potatisar', 'två morötter'],
      );
    });

    test('splits on "en halv"/"lite" quantity words', () {
      expect(
        splitSpokenIngredients('ett kilo potatis och en halv citron'),
        ['ett kilo potatis', 'en halv citron'],
      );
      expect(
        splitSpokenIngredients('tre ägg och lite persilja'),
        ['tre ägg', 'lite persilja'],
      );
    });

    test('existing line breaks are trusted verbatim', () {
      expect(
        splitSpokenIngredients('500 g köttfärs\nsalt och peppar\n'),
        ['500 g köttfärs', 'salt och peppar'],
      );
    });

    test('trailing sentence punctuation is stripped per line', () {
      expect(
        splitSpokenIngredients('två ägg och en gul lök.'),
        ['två ägg', 'en gul lök'],
      );
    });

    test('empty transcript yields empty list', () {
      expect(splitSpokenIngredients('   '), isEmpty);
    });
  });

  group('splitSpokenSteps', () {
    test('splits on sentence boundaries', () {
      expect(
        splitSpokenSteps(
          'Blanda köttfärsen med mjölken. Stek i smör tills de är gyllene! '
          'Servera med potatismos.',
        ),
        [
          'Blanda köttfärsen med mjölken.',
          'Stek i smör tills de är gyllene!',
          'Servera med potatismos.',
        ],
      );
    });

    test('abbreviation-free single sentence stays whole', () {
      expect(splitSpokenSteps('Rör ihop allt och servera.'), [
        'Rör ihop allt och servera.',
      ]);
    });
  });

  group('assembleRecipeText', () {
    test('produces the canonical Swedish recipe shape', () {
      final text = assembleRecipeText(
        title: 'Mormors köttbullar.',
        ingredientsTranscript:
            '500 gram köttfärs, två deciliter mjölk, tre ägg och en gul lök, salt och peppar',
        stepsTranscript:
            'Blanda allt till en smet. Rulla bollar och stek i smör.',
      );

      expect(text, '''
Mormors köttbullar

Ingredienser:
500 gram köttfärs
två deciliter mjölk
tre ägg
en gul lök
salt och peppar

Gör så här:
Blanda allt till en smet.
Rulla bollar och stek i smör.''');
    });

    test('title terminal punctuation is stripped (Whisper adds periods)', () {
      final text = assembleRecipeText(
        title: 'Pannkakor.',
        ingredientsTranscript: 'tre ägg',
        stepsTranscript: 'Vispa.',
      );
      expect(text, startsWith('Pannkakor\n'));
    });
  });
}
