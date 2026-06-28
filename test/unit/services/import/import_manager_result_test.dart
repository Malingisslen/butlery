/// Direct unit tests for [ImportManagerResult] + [BatchImportResult]
/// (BUT-1149 coverage burndown — previously zero direct coverage).
///
/// Result objects from the import pipeline. Covers the four named constructors
/// (success/failure/assistance/rateLimit) and their flag combinations, the
/// hasWarnings/hasMetadata/importedRecipes/error getters, and BatchImportResult's
/// successRate / hasErrors / allSuccessful.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('ImportManagerResult', () {
    test('success carries the recipe and clears failure fields', () {
      final recipe = RecipeFactory.build(title: 'Pasta');
      final r = ImportManagerResult.success(
        recipe,
        strategy: 'url',
        warnings: const ['minor'],
        metadata: const {'k': 'v'},
      );
      expect(r.isSuccess, isTrue);
      expect(r.recipe, same(recipe));
      expect(r.needsAssistance, isFalse);
      expect(r.rateLimitDenied, isNull);
      expect(r.hasWarnings, isTrue);
      expect(r.hasMetadata, isTrue);
      expect(r.importedRecipes, [recipe]);
    });

    test('failure sets the error and exposes it via error getter', () {
      final r = ImportManagerResult.failure(
        'boom',
        availableStrategies: const ['url', 'photo'],
      );
      expect(r.isSuccess, isFalse);
      expect(r.errorMessage, 'boom');
      expect(r.error, 'boom');
      expect(r.availableStrategies, ['url', 'photo']);
      expect(r.importedRecipes, isEmpty);
    });

    test('assistance flags needsAssistance with extracted text', () {
      final r = ImportManagerResult.assistance(
        extractedText: 'raw text',
        suggestedTitle: 'Title',
      );
      expect(r.needsAssistance, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.extractedText, 'raw text');
      expect(r.suggestedTitle, 'Title');
    });

    test('rateLimit preserves the structured denial', () {
      const details = RateLimitDenied(
        message: 'Daily limit reached',
        retryAfter: Duration(hours: 5),
        limitType: LimitType.perDay,
        suggestedAction: FallbackAction.retryLater,
      );
      final r = ImportManagerResult.rateLimit(details);
      expect(r.isSuccess, isFalse);
      expect(r.strategy, 'rate_limited');
      expect(r.rateLimitDenied, same(details));
      expect(r.errorMessage, 'Daily limit reached');
    });

    test('hasWarnings / hasMetadata are false when null or empty', () {
      final r = ImportManagerResult.success(RecipeFactory.build());
      expect(r.hasWarnings, isFalse);
      expect(r.hasMetadata, isFalse);
    });
  });

  group('BatchImportResult', () {
    BatchImportResult batch({
      required int total,
      required int success,
      List<String> errors = const [],
    }) => BatchImportResult(
      results: const [],
      successfulRecipes: const [],
      errors: errors,
      totalProcessed: total,
      successCount: success,
      failureCount: total - success,
    );

    test('successRate is success/total, 0 when nothing processed', () {
      expect(batch(total: 4, success: 3).successRate, 0.75);
      expect(batch(total: 0, success: 0).successRate, 0.0);
    });

    test('hasErrors reflects the error list', () {
      expect(batch(total: 1, success: 1).hasErrors, isFalse);
      expect(
        batch(total: 2, success: 1, errors: ['x']).hasErrors,
        isTrue,
      );
    });

    test('allSuccessful when every item succeeded', () {
      expect(batch(total: 3, success: 3).allSuccessful, isTrue);
      expect(batch(total: 3, success: 2).allSuccessful, isFalse);
    });
  });
}
