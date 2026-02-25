/// Tests for TextImportNormalizer - text preprocessing utilities for recipe import.
///
/// Covers: decimal protection, sentence splitting, concatenated ingredient
/// splitting, social media cleanup, hashtag removal (BUG-17), and the
/// full preprocessText pipeline.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/import/parsers/text_import_normalizer.dart';

void main() {
  group('TextImportNormalizer', () {
    // ---------------------------------------------------------------
    // BUG-17: Swedish hashtag corruption fix
    // ---------------------------------------------------------------
    group('BUG-17 - Swedish hashtag removal', () {
      test('should fully remove #kottbullar with Swedish chars', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Recept på #köttbullar idag',
        );
        expect(result, isNot(contains('öttbullar')));
        expect(result, isNot(contains('#')));
        expect(result.trim(), equals('Recept på idag'));
      });

      test('should fully remove #gronsakssoppa with Swedish chars', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Smaklig #grönsakssoppa till lunch',
        );
        expect(result, isNot(contains('rönsakssoppa')));
        expect(result, isNot(contains('#')));
        expect(result.trim(), equals('Smaklig till lunch'));
      });

      test('should fully remove #enkel', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          '#enkel middag',
        );
        expect(result, isNot(contains('#')));
        expect(result, isNot(contains('enkel')));
        expect(result.trim(), equals('middag'));
      });

      test('should remove regular English hashtags like #recipe', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'My #recipe for dinner',
        );
        expect(result, isNot(contains('#')));
        expect(result, isNot(contains('recipe')));
        expect(result.trim(), equals('My for dinner'));
      });

      test('should preserve non-hashtag text with Swedish chars', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Koka grönsakerna i 10 minuter',
        );
        expect(result, equals('Koka grönsakerna i 10 minuter'));
      });

      test('should remove multiple Swedish hashtags in one string', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          '#köttfärs #lättlagat #middag Servera med ris',
        );
        expect(result, isNot(contains('#')));
        expect(result.trim(), equals('Servera med ris'));
      });
    });

    // ---------------------------------------------------------------
    // protectDecimals / restoreDecimals
    // ---------------------------------------------------------------
    group('protectDecimals / restoreDecimals', () {
      test('should round-trip 0.75 dl correctly', () {
        const input = '0.75 dl mjölk';
        final protected = TextImportNormalizer.protectDecimals(input);
        expect(protected, isNot(contains('0.75')));
        final restored = TextImportNormalizer.restoreDecimals(protected);
        expect(restored, equals(input));
      });

      test('should round-trip 2.5 msk correctly', () {
        const input = '2.5 msk olja';
        final protected = TextImportNormalizer.protectDecimals(input);
        expect(protected, isNot(contains('2.5')));
        final restored = TextImportNormalizer.restoreDecimals(protected);
        expect(restored, equals(input));
      });

      test('should leave text without decimals unchanged', () {
        const input = 'Koka pastan i vatten';
        final protected = TextImportNormalizer.protectDecimals(input);
        expect(protected, equals(input));
        final restored = TextImportNormalizer.restoreDecimals(protected);
        expect(restored, equals(input));
      });

      test('should protect multiple decimals in one string', () {
        const input = '0.5 dl + 1.25 msk';
        final protected = TextImportNormalizer.protectDecimals(input);
        expect(protected, isNot(contains('0.5')));
        expect(protected, isNot(contains('1.25')));
        final restored = TextImportNormalizer.restoreDecimals(protected);
        expect(restored, equals(input));
      });
    });

    // ---------------------------------------------------------------
    // smartSentenceSplit
    // ---------------------------------------------------------------
    group('smartSentenceSplit', () {
      test('should split at period + capital letter', () {
        final result = TextImportNormalizer.smartSentenceSplit(
          'Koka pastan. Stek köttet.',
        );
        expect(result, contains('\n'));
        final lines = result.split('\n');
        expect(lines.length, greaterThanOrEqualTo(2));
        expect(lines[0].trim(), equals('Koka pastan.'));
        expect(lines[1].trim(), equals('Stek köttet.'));
      });

      test('should preserve "ca." abbreviation', () {
        final result = TextImportNormalizer.smartSentenceSplit(
          'Koka i ca. 10 minuter.',
        );
        expect(result, contains('ca.'));
        // Should NOT split after ca.
        expect(result, isNot(contains('ca.\n')));
      });

      test('should preserve "ev." abbreviation', () {
        final result = TextImportNormalizer.smartSentenceSplit(
          'Tillsätt ev. lite salt.',
        );
        expect(result, contains('ev.'));
        expect(result, isNot(contains('ev.\n')));
      });

      test('should preserve "t.ex." abbreviation', () {
        final result = TextImportNormalizer.smartSentenceSplit(
          'Använd en krydda t.ex. paprika.',
        );
        expect(result, contains('t.ex.'));
        expect(result, isNot(contains('t.ex.\n')));
      });

      test('should preserve decimal numbers during splitting', () {
        final result = TextImportNormalizer.smartSentenceSplit(
          'Tillsätt 0.5 dl grädde. Rör om.',
        );
        expect(result, contains('0.5'));
        // Should still split at sentence boundary
        final lines = result.split('\n');
        expect(lines.length, greaterThanOrEqualTo(2));
      });

      test('should split before Swedish action verbs after period', () {
        final result = TextImportNormalizer.smartSentenceSplit(
          'Klar med ingredienser.stek i 5 min',
        );
        expect(result, contains('\n'));
        final lines = result.split('\n');
        expect(lines.length, greaterThanOrEqualTo(2));
        expect(lines.last.trim(), startsWith('stek'));
      });

      test('should split before "koka" after period', () {
        final result = TextImportNormalizer.smartSentenceSplit(
          'Fyll kastrullen.koka i 10 min',
        );
        final lines = result.split('\n');
        expect(lines.length, greaterThanOrEqualTo(2));
      });

      test('should split at period + Swedish capital letters (A-O)', () {
        final result = TextImportNormalizer.smartSentenceSplit(
          'Skala potatisen. Ösa upp på tallriken.',
        );
        final lines = result.split('\n');
        expect(lines.length, greaterThanOrEqualTo(2));
        expect(lines[1].trim(), startsWith('Ö'));
      });

      test('should not split within a sentence without period', () {
        const input = 'Koka pastan med salt och vatten';
        final result = TextImportNormalizer.smartSentenceSplit(input);
        expect(result, equals(input));
      });
    });

    // ---------------------------------------------------------------
    // splitConcatenatedIngredients
    // ---------------------------------------------------------------
    group('splitConcatenatedIngredients', () {
      test('should split word+digit+unit concatenation into separate lines',
          () {
        // Use a word that does not contain a Swedish section header substring
        // to isolate Pattern 1 (letters followed by digit + unit)
        final result = TextImportNormalizer.splitConcatenatedIngredients(
          'socker2 msk',
        );
        final lines =
            result.split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines.length, greaterThanOrEqualTo(2));
        expect(lines[0].trim(), equals('socker'));
        expect(lines[1].trim(), equals('2 msk'));
      });

      test('should also split words containing Swedish section substrings', () {
        // "oystersås" contains "sås" which matches Pattern 2 as a section
        // header, so it gets split further into "oyster" + "sås"
        final result = TextImportNormalizer.splitConcatenatedIngredients(
          'oystersås2 msk',
        );
        final lines =
            result.split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines.length, greaterThanOrEqualTo(3));
        expect(lines, contains('oyster'));
      });

      test('should leave properly spaced text without unit-words unchanged',
          () {
        // Use a word that does not contain a Swedish section header substring
        const input = '2 msk socker';
        final result = TextImportNormalizer.splitConcatenatedIngredients(input);
        expect(result.trim(), equals(input));
      });

      test('should split ALL CAPS headers from following content', () {
        final result = TextImportNormalizer.splitConcatenatedIngredients(
          'INGREDIENSERSmör 2 msk',
        );
        expect(result, contains('\n'));
        final lines = result.split('\n');
        expect(lines[0].trim(), equals('INGREDIENSER'));
      });

      test('should handle decimal measurements in concatenation', () {
        final result = TextImportNormalizer.splitConcatenatedIngredients(
          'socker0.5 dl',
        );
        final lines = result.split('\n');
        expect(lines.length, greaterThanOrEqualTo(2));
        expect(lines.last.trim(), equals('0.5 dl'));
      });

      test('should split multiple concatenated ingredients', () {
        final result = TextImportNormalizer.splitConcatenatedIngredients(
          'soja1 msk socker2 dl',
        );
        final lines =
            result.split('\n').where((l) => l.trim().isNotEmpty).toList();
        expect(lines.length, greaterThanOrEqualTo(3));
      });

      test('should split portioner pattern from surrounding text', () {
        final result = TextImportNormalizer.splitConcatenatedIngredients(
          'middag4 portioner',
        );
        expect(result, contains('\n'));
        // Pattern 3 splits before "4 portioner", Pattern 3b may further
        // split after the digit+portioner token, so just verify the split
        // happens and the core content is preserved
        expect(result, contains('middag'));
        expect(result, contains('4'));
        expect(result, contains('portion'));
      });
    });

    // ---------------------------------------------------------------
    // cleanSocialMediaFormatting
    // ---------------------------------------------------------------
    group('cleanSocialMediaFormatting', () {
      test('should remove fire emoji separators', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Bra recept 🔥🔥🔥 prova detta',
        );
        expect(result, isNot(contains('🔥')));
        expect(result.trim(), equals('Bra recept prova detta'));
      });

      test('should remove sparkle emoji separators', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          '✨ Nytt recept ✨',
        );
        expect(result, isNot(contains('✨')));
      });

      test('should remove star emoji separators', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          '⭐🌟 Topp 10 recept 🌟⭐',
        );
        expect(result, isNot(contains('⭐')));
        expect(result, isNot(contains('🌟')));
      });

      test('should collapse excessive exclamation marks', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Så gott!!!',
        );
        expect(result, equals('Så gott!'));
      });

      test('should collapse excessive dots to ellipsis', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Blanda allt......',
        );
        expect(result, equals('Blanda allt...'));
      });

      test('should remove hashtags with Swedish chars (BUG-17)', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          '#köttfärs #lättlagat vanlig text',
        );
        expect(result, isNot(contains('#')));
        expect(result, contains('vanlig text'));
      });

      test('should collapse multiple spaces into one', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'extra   mellanrum   här',
        );
        expect(result, equals('extra mellanrum här'));
      });

      test('should remove Instagram line separators (dashes)', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Ingredienser\n----------\n2 dl mjölk',
        );
        expect(result, isNot(contains('----------')));
      });

      test('should remove Instagram line separators (underscores)', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Ingredienser\n___________\n2 dl mjölk',
        );
        expect(result, isNot(contains('___________')));
      });

      test('should remove Instagram line separators (equals)', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          'Ingredienser\n==========\n2 dl mjölk',
        );
        expect(result, isNot(contains('==========')));
      });

      test('should handle combined social media artifacts', () {
        final result = TextImportNormalizer.cleanSocialMediaFormatting(
          '🔥 Bästa receptet!!! #foodie #matlagning 💥',
        );
        expect(result, isNot(contains('🔥')));
        expect(result, isNot(contains('💥')));
        expect(result, isNot(contains('#')));
        expect(result, contains('Bästa receptet!'));
      });
    });

    // ---------------------------------------------------------------
    // preprocessText (full pipeline)
    // ---------------------------------------------------------------
    group('preprocessText', () {
      test('should clean hashtags, concatenated ingredients, and decimals', () {
        final result = TextImportNormalizer.preprocessText(
          '#köttfärs #enkel socker2 dl med 0.5 dl grädde',
        );
        // Hashtags removed
        expect(result, isNot(contains('#')));
        expect(result, isNot(contains('köttfärs')));
        // Concatenated ingredients split
        expect(result, contains('2 dl'));
        // Decimals preserved
        expect(result, contains('0.5 dl'));
      });

      test('should format "2dl" as "2 dl"', () {
        final result =
            TextImportNormalizer.preprocessText('Tillsätt 2dl mjölk');
        expect(result, contains('2 dl'));
      });

      test('should format "100g" as "100 g"', () {
        final result = TextImportNormalizer.preprocessText('100g smör');
        expect(result, contains('100 g'));
      });

      test('should format "1.5msk" as "1.5 msk"', () {
        final result = TextImportNormalizer.preprocessText('1.5msk olivolja');
        expect(result, contains('1.5 msk'));
      });

      test('should normalize multiple line breaks', () {
        final result = TextImportNormalizer.preprocessText(
          'Rad 1\n\n\nRad 2',
        );
        // Multiple newlines should be collapsed to single
        expect(result, isNot(contains('\n\n')));
      });

      test('should add line break after ingredient headers', () {
        final result = TextImportNormalizer.preprocessText('Ingredienser2 dl');
        expect(result, contains('Ingredienser\n'));
      });

      test('should add line break after instruction headers', () {
        final result = TextImportNormalizer.preprocessText(
          'Gör så här stek i 5 min',
        );
        expect(result, contains('gör så här\n'));
      });

      test('should add line break before common instruction words', () {
        final result = TextImportNormalizer.preprocessText(
          'allting klart Servera med ris',
        );
        expect(result, contains('\nServera'));
      });

      test('should handle an empty string', () {
        final result = TextImportNormalizer.preprocessText('');
        expect(result, equals(''));
      });

      test('should handle already clean text', () {
        final result = TextImportNormalizer.preprocessText(
          '2 dl mjölk\n100 g smör',
        );
        expect(result, contains('2 dl mjölk'));
        expect(result, contains('100 g smör'));
      });

      test('should handle full Instagram recipe with social media artifacts',
          () {
        final result = TextImportNormalizer.preprocessText(
          '🔥 BÄSTA PASTAN!!! #pasta #middag #lättlagat\n'
          '----------\n'
          'Ingredienser\n'
          'pasta400g vatten1dl\n'
          'Gör så här\n'
          'Koka pastan i 8 min.Servera med sås.',
        );
        // Emojis removed
        expect(result, isNot(contains('🔥')));
        // Hashtags removed
        expect(result, isNot(contains('#')));
        // Line separators removed
        expect(result, isNot(contains('----------')));
        // Measurements formatted
        expect(result, contains('400 g'));
        expect(result, contains('1 dl'));
        // Sentences split
        expect(result, contains('Koka'));
        expect(result, contains('Servera'));
      });
    });
  });
}
