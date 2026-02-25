/// Unit tests for IngredientProcessor - unified ingredient processing pipeline
///
/// Tests Phase 1 additions:
/// - Confidence score propagation from normalization to ProcessedIngredient
/// - additionalKnown parameter forwarding in batch methods
/// - Pattern A/B/C processing correctness
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';

void main() {
  group('IngredientProcessor', () {
    group('ProcessedIngredient', () {
      test('should default confidence to 0.5', () {
        const processed = ProcessedIngredient(
          quantity: 1.0,
          unit: '',
          originalName: 'test',
          normalizedName: 'test',
          originalRawText: 'test',
        );
        expect(processed.confidence, 0.5);
      });

      test('should accept explicit confidence', () {
        const processed = ProcessedIngredient(
          quantity: 1.0,
          unit: 'dl',
          originalName: 'mjölk',
          normalizedName: 'mjölk',
          originalRawText: '1 dl mjölk',
          confidence: 0.95,
        );
        expect(processed.confidence, 0.95);
      });

      test('toString should include confidence', () {
        const processed = ProcessedIngredient(
          quantity: 2.0,
          unit: 'dl',
          originalName: 'mjölk',
          normalizedName: 'mjölk',
          originalRawText: '2 dl mjölk',
          confidence: 0.8,
        );
        final str = processed.toString();
        expect(str, contains('confidence: 0.8'));
      });

      test('toString should include category when present', () {
        const processed = ProcessedIngredient(
          quantity: 1.0,
          unit: '',
          originalName: 'mjölk',
          normalizedName: 'mjölk',
          originalRawText: 'mjölk',
          category: 'dairy',
          confidence: 0.8,
        );
        final str = processed.toString();
        expect(str, contains('category: dairy'));
      });

      test('toString should include [known] marker when isKnown', () {
        const processed = ProcessedIngredient(
          quantity: 1.0,
          unit: '',
          originalName: 'mjölk',
          normalizedName: 'mjölk',
          originalRawText: 'mjölk',
          isKnown: true,
        );
        final str = processed.toString();
        expect(str, contains('[known]'));
      });
    });

    group('Pattern A: processRawIngredient', () {
      test('should propagate confidence from normalization', () {
        final result = IngredientProcessor.processRawIngredient('2 dl mjölk');
        expect(result.confidence, 0.8);
        expect(result.isKnown, isTrue);
      });

      test('should return high confidence for compound names', () {
        final result =
            IngredientProcessor.processRawIngredient('1 tsk vitpeppar');
        expect(result.confidence, 1.0);
        expect(result.normalizedName, 'vitpeppar');
      });

      test('should return 0.95 confidence for Firestore-known ingredients', () {
        final result = IngredientProcessor.processRawIngredient(
          '1 msk tahini',
          additionalKnown: {'tahini'},
        );
        expect(result.confidence, 0.95);
        expect(result.isKnown, isTrue);
      });

      test('should return low confidence for unknown ingredients', () {
        final result =
            IngredientProcessor.processRawIngredient('1 st xyzfooditem');
        expect(result.confidence, 0.3);
        expect(result.isKnown, isFalse);
      });

      test('should parse quantity and unit correctly', () {
        final result =
            IngredientProcessor.processRawIngredient('2 dl hackad lök');
        expect(result.quantity, 2.0);
        expect(result.unit, 'dl');
        expect(result.normalizedName, 'lök');
        expect(result.originalRawText, '2 dl hackad lök');
      });
    });

    group('Pattern B: parseAndNormalize', () {
      test('should propagate confidence', () {
        final result = IngredientProcessor.parseAndNormalize('2 dl hackad lök');
        expect(result.confidence, 0.8);
        expect(result.normalizedName, 'lök');
        expect(result.originalName, 'hackad lök');
      });

      test('should forward additionalKnown', () {
        final result = IngredientProcessor.parseAndNormalize(
          '1 msk harissa',
          additionalKnown: {'harissa'},
        );
        expect(result.confidence, 0.95);
        expect(result.isKnown, isTrue);
        expect(result.normalizedName, 'harissa');
      });

      test('should preserve original raw text', () {
        final result = IngredientProcessor.parseAndNormalize('3 st stora ägg');
        expect(result.originalRawText, '3 st stora ägg');
      });
    });

    group('Pattern C: normalizeIngredientName', () {
      test('should return NormalizationResult with confidence', () {
        final result = IngredientProcessor.normalizeIngredientName('vitpeppar');
        expect(result, isA<NormalizationResult>());
        expect(result.confidence, 1.0);
        expect(result.normalized, 'vitpeppar');
      });

      test('should forward additionalKnown', () {
        final result = IngredientProcessor.normalizeIngredientName(
          'tahini',
          additionalKnown: {'tahini'},
        );
        expect(result.isKnown, isTrue);
        expect(result.confidence, 0.95);
      });
    });

    group('batch methods with additionalKnown', () {
      test('processRawIngredients should forward additionalKnown', () {
        final results = IngredientProcessor.processRawIngredients(
          ['1 msk tahini', '2 dl mjölk'],
          additionalKnown: {'tahini'},
        );
        expect(results, hasLength(2));
        expect(results[0].isKnown, isTrue);
        expect(results[0].confidence, 0.95);
        expect(results[1].isKnown, isTrue);
        expect(results[1].confidence, 0.8);
      });

      test('parseAndNormalizeMany should forward additionalKnown', () {
        final results = IngredientProcessor.parseAndNormalizeMany(
          ['harissa', 'hackad lök'],
          additionalKnown: {'harissa'},
        );
        expect(results, hasLength(2));
        expect(results[0].isKnown, isTrue);
        expect(results[0].normalizedName, 'harissa');
        expect(results[1].normalizedName, 'lök');
      });

      test('normalizeIngredientNames should forward additionalKnown', () {
        final results = IngredientProcessor.normalizeIngredientNames(
          ['tahini', 'lök'],
          additionalKnown: {'tahini'},
        );
        expect(results, hasLength(2));
        expect(results[0].isKnown, isTrue);
        expect(results[0].confidence, 0.95);
        expect(results[1].isKnown, isTrue);
      });
    });

    group('toDisplayString and toNormalizedString', () {
      test('toDisplayString should use original name with unit', () {
        const processed = ProcessedIngredient(
          quantity: 2.0,
          unit: 'dl',
          originalName: 'hackad lök',
          normalizedName: 'lök',
          originalRawText: '2 dl hackad lök',
        );
        expect(processed.toDisplayString(), '2.0 dl hackad lök');
      });

      test('toDisplayString should omit unit when empty', () {
        const processed = ProcessedIngredient(
          quantity: 3.0,
          unit: '',
          originalName: 'ägg',
          normalizedName: 'ägg',
          originalRawText: '3 ägg',
        );
        expect(processed.toDisplayString(), 'ägg');
      });

      test('toNormalizedString should use normalized name', () {
        const processed = ProcessedIngredient(
          quantity: 2.0,
          unit: 'dl',
          originalName: 'hackad lök',
          normalizedName: 'lök',
          originalRawText: '2 dl hackad lök',
        );
        expect(processed.toNormalizedString(), 'dl lök');
      });

      test('toNormalizedString should omit unit when empty', () {
        const processed = ProcessedIngredient(
          quantity: 1.0,
          unit: '',
          originalName: 'vitpeppar',
          normalizedName: 'vitpeppar',
          originalRawText: 'vitpeppar',
        );
        expect(processed.toNormalizedString(), 'vitpeppar');
      });
    });

    group('normalizeIngredientsForRecipe', () {
      test('should return null for null input', () {
        expect(IngredientProcessor.normalizeIngredientsForRecipe(null), isNull);
      });

      test('should return empty list for empty input', () {
        expect(IngredientProcessor.normalizeIngredientsForRecipe([]), isEmpty);
      });

      test('should normalize preparation words out', () {
        final result = IngredientProcessor.normalizeIngredientsForRecipe(
          ['2 dl hackad lök', '3 st stora ägg', 'glutenfri pasta'],
        );
        expect(result, isNotNull);
        expect(result!, hasLength(3));
        expect(result[0], 'lök');
        expect(result[1], 'ägg');
        expect(result[2], 'glutenfri pasta');
      });

      test('should skip empty strings', () {
        final result = IngredientProcessor.normalizeIngredientsForRecipe(
          ['2 dl mjölk', '', '  '],
        );
        expect(result, isNotNull);
        expect(result!, hasLength(1));
        expect(result[0], 'mjölk');
      });
    });

    group('preprocessing metadata accessors', () {
      test('processRawIngredient with optional marker sets isOptional', () {
        final result =
            IngredientProcessor.processRawIngredient('ev. 2 dl mjölk');
        expect(result.isOptional, isTrue);
        expect(result.isApproximate, isFalse);
      });

      test('processRawIngredient with approximation sets isApproximate', () {
        final result =
            IngredientProcessor.processRawIngredient('ca 3 dl mjölk');
        expect(result.isApproximate, isTrue);
        expect(result.isOptional, isFalse);
      });

      test('processRawIngredient with range sets rangeMin and rangeMax', () {
        final result = IngredientProcessor.processRawIngredient('3-5 dl mjölk');
        expect(result.rangeMin, 3.0);
        expect(result.rangeMax, 5.0);
      });

      test('processRawIngredient with parentheses sets preparationHint', () {
        final result =
            IngredientProcessor.processRawIngredient('lime (saften)');
        expect(result.preparationHint, 'saften');
      });

      test('substitutes propagate through Pattern A', () {
        final result = IngredientProcessor.processRawIngredient(
            '2 dl grädde (eller kokosmjölk)');
        expect(result.substitutes, ['kokosmjölk']);
        expect(result.preparationHint, isNull);
      });

      test('substitutes empty for Pattern B (no preprocessing)', () {
        final result = IngredientProcessor.parseAndNormalize('2 dl grädde');
        expect(result.substitutes, isEmpty);
      });

      test('parseAndNormalize has all metadata null or false', () {
        final result = IngredientProcessor.parseAndNormalize('2 dl mjölk');
        expect(result.isOptional, isFalse);
        expect(result.isApproximate, isFalse);
        expect(result.preparationHint, isNull);
        expect(result.rangeMin, isNull);
        expect(result.rangeMax, isNull);
        expect(result.preprocessingFlags, isNull);
      });

      test('combined optional + approximation flags', () {
        final result =
            IngredientProcessor.processRawIngredient('ev. ca 2 dl grädde');
        expect(result.isOptional, isTrue);
        expect(result.isApproximate, isTrue);
      });

      test('range without approximation has correct metadata', () {
        final result = IngredientProcessor.processRawIngredient('2-3 st ägg');
        expect(result.rangeMin, 2.0);
        expect(result.rangeMax, 3.0);
        expect(result.isApproximate, isFalse);
      });

      test('no preprocessing metadata when input is clean', () {
        final result = IngredientProcessor.processRawIngredient('2 dl mjölk');
        expect(result.isOptional, isFalse);
        expect(result.isApproximate, isFalse);
        expect(result.preparationHint, isNull);
        expect(result.rangeMin, isNull);
        expect(result.rangeMax, isNull);
      });
    });

    group('toString with preprocessing metadata', () {
      test('toString includes optional flag', () {
        final result =
            IngredientProcessor.processRawIngredient('ev. 2 dl mjölk');
        final str = result.toString();
        expect(str, contains('optional'));
      });

      test('toString includes approximate flag', () {
        final result =
            IngredientProcessor.processRawIngredient('ca 3 dl mjölk');
        final str = result.toString();
        expect(str, contains('approximate'));
      });

      test('toString includes range', () {
        final result = IngredientProcessor.processRawIngredient('3-5 dl mjölk');
        final str = result.toString();
        expect(str, contains('range: 3.0-5.0'));
      });

      test('toString includes preparation hint', () {
        final result =
            IngredientProcessor.processRawIngredient('lime (saften)');
        final str = result.toString();
        expect(str, contains('hint: "saften"'));
      });

      test('toString includes substitutes', () {
        final result = IngredientProcessor.processRawIngredient(
            'grädde (eller kokosmjölk)');
        final str = result.toString();
        expect(str, contains('substitutes'));
        expect(str, contains('kokosmjölk'));
      });

      test('toString omits flags when no preprocessing metadata present', () {
        const processed = ProcessedIngredient(
          quantity: 2.0,
          unit: 'dl',
          originalName: 'mjölk',
          normalizedName: 'mjölk',
          originalRawText: '2 dl mjölk',
        );
        final str = processed.toString();
        expect(str, isNot(contains('optional')));
        expect(str, isNot(contains('approximate')));
        expect(str, isNot(contains('range')));
        expect(str, isNot(contains('hint')));
      });
    });

    group('helper methods', () {
      test('preprocessOnly should clean text', () {
        final result =
            IngredientProcessor.preprocessOnly('ca 3 dl mjölk (kall)');
        expect(result, isNotEmpty);
        expect(result, isNot(contains('ca')));
        expect(result, isNot(contains('(kall)')));
      });

      test('needsPreprocessing should detect preprocessable input', () {
        expect(
          IngredientProcessor.needsPreprocessing('ca 3 dl mjölk'),
          isTrue,
        );
        expect(
          IngredientProcessor.needsPreprocessing('3 dl mjölk'),
          isFalse,
        );
      });

      test('getPreprocessingChanges should report changes', () {
        final changes =
            IngredientProcessor.getPreprocessingChanges('ca 3-5 dl mjölk');
        expect(changes['hadApproximation'], isTrue);
        expect(changes['hadRange'], isTrue);
        expect(changes['before'], 'ca 3-5 dl mjölk');
      });
    });
  });
}
