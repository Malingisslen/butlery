/// Unit tests for ImportResultV2 — sealed import result hierarchy.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../../test_support/base_unit_test.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/models/recipe_unified.dart';

void main() {
  late Recipe testRecipe;

  group('ImportResultV2', () {
    setUp(() async {
      await BaseUnitTest.setupUnit();
      testRecipe = Recipe.personal(
        title: 'Test Recipe',
        description: 'A test recipe',
        ingredients: ['flour', 'water', 'salt'],
        instructions: ['Mix', 'Bake'],
        mealType: 'dinner',
      );
    });
    tearDown(() => BaseUnitTest.resetMocks());

    group('ImportSuccess', () {
      test('isSuccess returns true', () {
        final result = ImportSuccess(
          recipe: testRecipe,
          confidence: 0.95,
          pipeline: 'test',
          tier: 1,
          method: 'direct',
        );
        expect(result.isSuccess, isTrue);
        expect(result.needsAssistance, isFalse);
        expect(result.isFailure, isFalse);
      });

      test('recipe getter returns the recipe', () {
        final result = ImportSuccess(
          recipe: testRecipe,
          confidence: 0.95,
          pipeline: 'test',
          tier: 1,
          method: 'direct',
        );
        expect(result.recipe, testRecipe);
      });
    });

    group('ImportPartial', () {
      test('isSuccess returns false', () {
        const result = ImportPartial(
          partialData: {'title': 'Test'},
          confidence: 0.5,
          pipeline: 'test',
          tier: 2,
        );
        expect(result.isSuccess, isFalse);
        expect(result.needsAssistance, isFalse);
      });

      test('canEnhance true when data + text + confidence >= 0.3', () {
        const result = ImportPartial(
          partialData: {'title': 'Test'},
          extractedText: 'Some text',
          confidence: 0.5,
          pipeline: 'test',
          tier: 2,
        );
        expect(result.canEnhance, isTrue);
      });

      test('canEnhance false when confidence < 0.3', () {
        const result = ImportPartial(
          partialData: {'title': 'Test'},
          extractedText: 'Some text',
          confidence: 0.2,
          pipeline: 'test',
          tier: 2,
        );
        expect(result.canEnhance, isFalse);
      });

      test('canEnhance false when no text or html', () {
        const result = ImportPartial(
          partialData: {'title': 'Test'},
          confidence: 0.5,
          pipeline: 'test',
          tier: 2,
        );
        expect(result.canEnhance, isFalse);
      });

      test('canEnhance false when partialData empty', () {
        const result = ImportPartial(
          partialData: {},
          extractedText: 'text',
          confidence: 0.5,
          pipeline: 'test',
          tier: 2,
        );
        expect(result.canEnhance, isFalse);
      });

      test('title getter reads from partialData', () {
        const result = ImportPartial(
          partialData: {'title': 'My Recipe'},
          confidence: 0.5,
          pipeline: 'test',
          tier: 2,
        );
        expect(result.title, 'My Recipe');
      });
    });

    group('ImportNeedsAssistance', () {
      test('needsAssistance returns true', () {
        const result = ImportNeedsAssistance(
          extractedText: 'line1\nline2\nline3',
          message: 'Need help',
        );
        expect(result.needsAssistance, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isFalse);
      });

      test('textLines splits and filters empty', () {
        const result = ImportNeedsAssistance(
          extractedText: 'line1\nline2\n\nline3\n',
          message: 'Need help',
        );
        expect(result.textLines, ['line1', 'line2', 'line3']);
      });
    });

    group('ImportNeedsScreenshot', () {
      test('needsAssistance returns true', () {
        const result = ImportNeedsScreenshot(
          platform: 'tiktok',
          url: 'https://tiktok.com/video/123',
          message: 'Need screenshot',
        );
        expect(result.needsAssistance, isTrue);
      });
    });

    group('ImportFailure', () {
      test('isFailure returns true', () {
        const result = ImportFailure(
          message: 'Network error',
          errorCode: ImportErrorCode.network,
        );
        expect(result.isFailure, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.needsAssistance, isFalse);
        expect(result.recipe, isNull);
      });

      test('rateLimited factory sets correct fields', () {
        final result = ImportFailure.rateLimited(
          message: 'Rate limited',
          retryAfter: const Duration(seconds: 30),
        );
        expect(result.errorCode, ImportErrorCode.rateLimited);
        expect(result.retryAfter, const Duration(seconds: 30));
      });
    });
  });
}
