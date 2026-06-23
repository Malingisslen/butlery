/// Integration tests for MODUL1 ingredient processing pipeline
///
/// Tests the complete ingredient processing flow from raw user input
/// through preprocessing, parsing, and normalization.

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';

void main() {
  group('IngredientProcessor Integration Tests', () {
    group('Pattern A - Full Pipeline (Raw User Input)', () {
      test('handles approximations with ranges', () {
        final input = 'ca 3-5 dl mjölk';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 5.0, reason: 'Should take maximum from range');
        expect(result.unit, 'dl');
        expect(result.originalName, 'mjölk');
        expect(result.normalizedName, 'mjölk');
        expect(result.preprocessingFlags?.hadApproximation, true);
        expect(result.preprocessingFlags?.hadRange, true);
      });

      test('preserves diet descriptors', () {
        final input = 'ca 2 dl glutenfri mjölk';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 2.0);
        expect(result.unit, 'dl');
        expect(
          result.normalizedName,
          'glutenfri mjölk',
          reason: 'Diet descriptors must be preserved',
        );
        expect(result.preprocessingFlags?.hadApproximation, true);
      });

      test('removes parentheses and instructions', () {
        final input = '3 dl mjölk (kall) till gröten';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 3.0);
        expect(result.unit, 'dl');
        expect(result.originalName, 'mjölk');
        expect(result.preprocessingFlags?.hadParentheses, true);
        expect(result.preprocessingFlags?.hadInstruction, true);
      });

      test('preserves compound ingredient names', () {
        final input = '1 krm vitpeppar';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 1.0);
        expect(result.unit, 'krm');
        expect(
          result.normalizedName,
          'vitpeppar',
          reason: 'Compound names should not be split to "peppar"',
        );
        expect(
          result.isKnown,
          true,
          reason: 'vitpeppar should be in known ingredients',
        );
      });

      test('preserves "med [flavor]" products', () {
        final input = '1 burk mayo med lime och jalapeño';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 1.0);
        expect(result.unit, 'burk');
        expect(
          result.normalizedName,
          contains('med'),
          reason: 'Product flavor descriptions should be preserved',
        );
      });

      test('removes preparation words', () {
        final input = '2 dl hackad lök';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 2.0);
        expect(result.unit, 'dl');
        expect(
          result.originalName,
          'hackad lök',
          reason: 'Original should keep preparation word for display',
        );
        expect(
          result.normalizedName,
          'lök',
          reason: 'Normalized should remove preparation word for grouping',
        );
      });

      test('handles complex real-world example', () {
        final input = 'cirka 2-3 dl glutenfri mjölk (kall) till gröten';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 3.0, reason: 'Max from range');
        expect(result.unit, 'dl');
        expect(
          result.normalizedName,
          'glutenfri mjölk',
          reason: 'Diet descriptor preserved, parentheses/instruction removed',
        );
        expect(result.preprocessingFlags?.hadApproximation, true);
        expect(result.preprocessingFlags?.hadRange, true);
        expect(result.preprocessingFlags?.hadParentheses, true);
        expect(result.preprocessingFlags?.hadInstruction, true);
      });

      test('handles ASCII fractions from parser', () {
        final input = '1 1/2 dl grädde';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 1.5);
        expect(result.unit, 'dl');
        expect(result.originalName, 'grädde');
      });

      test('handles compound ingredients with "och"', () {
        final input = '1 tsk salt och peppar';
        final result = IngredientProcessor.processRawIngredient(input);

        // Note: IngredientParser.parseIngredient doesn't use parseCompoundIngredient
        // So this tests the single-ingredient flow
        expect(result.quantity, 1.0);
        expect(result.unit, 'tsk');
        // Will parse as "salt och peppar" (compound name in single string)
      });
    });

    group('Pattern B - Parse + Normalize (Database Data)', () {
      test('normalizes existing database ingredients', () {
        final input = '2 dl hackad lök';
        final result = IngredientProcessor.parseAndNormalize(input);

        expect(result.quantity, 2.0);
        expect(result.unit, 'dl');
        expect(result.originalName, 'hackad lök');
        expect(result.normalizedName, 'lök');
        expect(
          result.preprocessingFlags,
          null,
          reason: 'Pattern B skips preprocessing',
        );
      });

      test('handles clean ingredient strings', () {
        final input = '3 dl mjölk';
        final result = IngredientProcessor.parseAndNormalize(input);

        expect(result.quantity, 3.0);
        expect(result.unit, 'dl');
        expect(result.originalName, 'mjölk');
        expect(result.normalizedName, 'mjölk');
      });
    });

    group('Pattern C - Normalize Only (Parsed Names)', () {
      test('normalizes parsed ingredient names', () {
        final input = 'hackad lök';
        final result = IngredientProcessor.normalizeIngredientName(input);

        expect(result.normalized, 'lök');
        expect(result.removedWords, contains('hackad'));
      });

      test('preserves diet descriptors in normalization', () {
        final input = 'glutenfri pasta';
        final result = IngredientProcessor.normalizeIngredientName(input);

        expect(result.normalized, 'glutenfri pasta');
        expect(result.removedWords, isEmpty);
      });

      test('identifies known ingredients', () {
        final input = 'mjölk';
        final result = IngredientProcessor.normalizeIngredientName(input);

        expect(result.isKnown, true);
        expect(result.category, 'dairy');
      });
    });

    group('Batch Processing', () {
      test('processes multiple raw ingredients', () {
        final inputs = [
          'ca 3 dl mjölk',
          '2-3 ägg',
          '1 msk smör',
        ];

        final results = IngredientProcessor.processRawIngredients(inputs);

        expect(results.length, 3);
        expect(results[0].quantity, 3.0);
        expect(results[1].quantity, 3.0, reason: 'Max from range');
        expect(results[2].quantity, 1.0);
      });

      test('batch parse and normalize', () {
        final inputs = [
          '2 dl hackad lök',
          '1 dl riven ost',
        ];

        final results = IngredientProcessor.parseAndNormalizeMany(inputs);

        expect(results.length, 2);
        expect(results[0].normalizedName, 'lök');
        expect(results[1].normalizedName, 'ost');
      });
    });

    group('Helper Methods', () {
      test('preprocessOnly returns cleaned text', () {
        final input = 'ca 3-5 dl mjölk (kall)';
        final result = IngredientProcessor.preprocessOnly(input);

        expect(result, '5 dl mjölk');
      });

      test('needsPreprocessing detects dirty text', () {
        expect(IngredientProcessor.needsPreprocessing('ca 3 dl mjölk'), true);
        expect(IngredientProcessor.needsPreprocessing('3 dl mjölk'), false);
      });

      test('getPreprocessingChanges provides details', () {
        final input = 'ca 3-5 dl mjölk';
        final changes = IngredientProcessor.getPreprocessingChanges(input);

        expect(changes['hadApproximation'], true);
        expect(changes['hadRange'], true);
        expect(changes['before'], input);
        expect(changes['after'], '5 dl mjölk');
      });
    });

    group('Display and Normalized Strings', () {
      test('toDisplayString uses original name', () {
        final result = IngredientProcessor.processRawIngredient(
          '2 dl hackad lök',
        );

        expect(result.toDisplayString(), '2.0 dl hackad lök');
      });

      test('toNormalizedString uses normalized name', () {
        final result = IngredientProcessor.processRawIngredient(
          '2 dl hackad lök',
        );

        expect(result.toNormalizedString(), 'dl lök');
      });
    });

    group('Edge Cases', () {
      test('handles empty input gracefully', () {
        final result = IngredientProcessor.processRawIngredient('');

        expect(result.quantity, 1.0);
        expect(result.unit, '');
        expect(result.originalName, '');
      });

      test('handles whitespace-only input', () {
        final result = IngredientProcessor.processRawIngredient('   ');

        expect(result.originalName, '');
      });

      test('handles ingredients with only name (no quantity)', () {
        final result = IngredientProcessor.processRawIngredient('salt');

        expect(result.quantity, 1.0);
        expect(result.unit, '');
        expect(result.normalizedName, 'salt');
      });

      test('handles multiple spaces in ingredient', () {
        final input = '2   dl    mjölk';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 2.0);
        expect(result.unit, 'dl');
        expect(result.originalName, 'mjölk');
      });
    });

    group('Real-World Recipe Import Scenarios', () {
      test('handles messy social media copy/paste', () {
        final input = '• ca 3-5 dl mjölk (eller grädde)';
        // Note: Bullet cleanup happens in text_import_strategy before this
        final withoutBullet = input.replaceAll(RegExp(r'^[•\-\*\d+\.]\s*'), '');
        final result = IngredientProcessor.processRawIngredient(withoutBullet);

        expect(result.quantity, 5.0);
        expect(result.unit, 'dl');
        // "eller grädde" handled by normalization
      });

      test('handles OCR errors with extra spaces', () {
        final input = '2  -  3   dl   mjölk';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 3.0, reason: 'Max from range');
        expect(result.unit, 'dl');
      });

      test('handles Swedish recipe blog format', () {
        final input = 'ca 4 dl vetemjöl (eller dinkel)';
        final result = IngredientProcessor.processRawIngredient(input);

        expect(result.quantity, 4.0);
        expect(result.unit, 'dl');
        expect(result.originalName, 'vetemjöl');
        expect(result.preprocessingFlags?.hadApproximation, true);
        expect(result.preprocessingFlags?.hadParentheses, true);
      });
    });
  });
}
