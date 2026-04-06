/// Unit tests for rate limit models — sealed classes, factories, constants.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../../test_support/base_unit_test.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';

void main() {
  group('RateLimitResult', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('RateLimitAllowed has correct type getters', () {
      const result = RateLimitAllowed(
        remainingInWindow: 5,
        limitType: LimitType.perHour,
      );
      expect(result.isAllowed, isTrue);
      expect(result.isDenied, isFalse);
      expect(result.remainingInWindow, 5);
    });

    test('RateLimitDenied has correct type getters', () {
      const result = RateLimitDenied(
        message: 'Too many requests',
        retryAfter: Duration(seconds: 60),
        limitType: LimitType.perDay,
        suggestedAction: FallbackAction.retryLater,
      );
      expect(result.isDenied, isTrue);
      expect(result.isAllowed, isFalse);
      expect(result.retryAfter, const Duration(seconds: 60));
    });
  });

  group('ImportOperation', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('basic factory creates non-LLM operation', () {
      final op = ImportOperation.basic('url');
      expect(op.requiresLlm, isFalse);
      expect(op.llmType, isNull);
      expect(op.sourceType, 'url');
    });

    test('withLlm factory creates LLM operation with cost', () {
      final op = ImportOperation.withLlm('url', LlmOperationType.enhancement);
      expect(op.requiresLlm, isTrue);
      expect(op.llmType, LlmOperationType.enhancement);
      expect(op.estimatedCost, 0.01);
    });
  });

  group('LlmOperationCost', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('enhancement cost is 0.01', () {
      expect(LlmOperationType.enhancement.estimatedCost, 0.01);
    });

    test('fullExtraction cost is 0.03', () {
      expect(LlmOperationType.fullExtraction.estimatedCost, 0.03);
    });

    test('vision cost is 0.04', () {
      expect(LlmOperationType.vision.estimatedCost, 0.04);
    });

    test('ingredientLines cost is 0.005', () {
      expect(LlmOperationType.ingredientLines.estimatedCost, 0.005);
    });
  });

  group('UsageLimits', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('empty factory returns all zeros', () {
      final limits = UsageLimits.empty();
      expect(limits.importsToday, 0);
      expect(limits.llmEnhancementsToday, 0);
      expect(limits.totalLlmToday, 0);
    });

    test('totalLlmToday sums three LLM fields', () {
      const limits = UsageLimits(
        llmEnhancementsToday: 5,
        llmExtractionsToday: 3,
        llmVisionToday: 2,
      );
      expect(limits.totalLlmToday, 10);
    });
  });

  group('ImportRateLimits constants', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('importsPerMinute is 10', () {
      expect(ImportRateLimits.importsPerMinute, 10);
    });

    test('importsPerDay is 100', () {
      expect(ImportRateLimits.importsPerDay, 100);
    });

    test('llmCostPerDay is 0.50', () {
      expect(ImportRateLimits.llmCostPerDay, 0.50);
    });

    test('llmCostPerMonth is 10.00', () {
      expect(ImportRateLimits.llmCostPerMonth, 10.00);
    });
  });
}
