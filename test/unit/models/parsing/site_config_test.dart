import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/site_config.dart';

void main() {
  group('computedQualityScore', () {
    test('returns manual qualityScore when total attempts < 5', () {
      const config = SiteConfig(
        domain: 'test.se',
        qualityScore: 0.8,
        successCount: 2,
        failureCount: 1,
      );

      expect(config.computedQualityScore, 0.8);
    });

    test('returns success rate when total attempts >= 5', () {
      const config = SiteConfig(
        domain: 'test.se',
        qualityScore: 0.8,
        successCount: 8,
        failureCount: 2,
      );

      // successRate = 8/10 = 0.8
      expect(config.computedQualityScore, 0.8);
    });

    test('returns success rate even when lower than manual score', () {
      const config = SiteConfig(
        domain: 'test.se',
        qualityScore: 0.9,
        successCount: 3,
        failureCount: 7,
      );

      // total = 10 >= 5, so use successRate = 3/10 = 0.3
      expect(config.computedQualityScore, 0.3);
    });

    test('returns manual score at exactly 4 total', () {
      const config = SiteConfig(
        domain: 'test.se',
        qualityScore: 0.6,
        successCount: 3,
        failureCount: 1,
      );

      expect(config.computedQualityScore, 0.6);
    });

    test('returns success rate at exactly 5 total', () {
      const config = SiteConfig(
        domain: 'test.se',
        qualityScore: 0.6,
        successCount: 4,
        failureCount: 1,
      );

      // successRate = 4/5 = 0.8
      expect(config.computedQualityScore, 0.8);
    });
  });

  group('isReliable', () {
    test('uses computed score for reliability check', () {
      // Manual score is high (0.9) but computed (success rate) is low
      const config = SiteConfig(
        domain: 'bad.se',
        titleSelector: 'h1',
        ingredientsSelector: '.ing',
        qualityScore: 0.9,
        isSupported: true,
        successCount: 2,
        failureCount: 8,
      );

      // total = 10 >= 5, computedQualityScore = 2/10 = 0.2
      expect(config.isReliable, isFalse);
    });

    test('reliable when computed score >= 0.7 with selectors and supported',
        () {
      const config = SiteConfig(
        domain: 'good.se',
        titleSelector: 'h1',
        ingredientsSelector: '.ing',
        instructionsSelector: '.steps',
        qualityScore: 0.5,
        isSupported: true,
        successCount: 8,
        failureCount: 2,
      );

      // total = 10 >= 5, computedQualityScore = 0.8
      expect(config.isReliable, isTrue);
    });

    test('not reliable without selectors even with high score', () {
      const config = SiteConfig(
        domain: 'no-selectors.se',
        qualityScore: 0.9,
        isSupported: true,
        successCount: 10,
        failureCount: 0,
      );

      expect(config.isReliable, isFalse);
    });
  });

  group('fallback selectors', () {
    test('fromFirestore/toFirestore round-trip with fallback selectors', () {
      const original = SiteConfig(
        domain: 'test.se',
        titleSelector: 'h1.recipe-title',
        titleSelectorFallback: 'h1',
        ingredientsSelector: '.recipe-ingredients li',
        ingredientsSelectorFallback: '.ingredients li',
        instructionsSelector: '.recipe-steps li',
        instructionsSelectorFallback: '.steps li',
        isSupported: true,
        qualityScore: 0.85,
        successCount: 20,
        failureCount: 3,
      );

      final firestoreData = original.toFirestore();

      // Simulate reading back (replace FieldValue.serverTimestamp with actual timestamp)
      firestoreData['lastUpdated'] = Timestamp.now();

      final restored = SiteConfig.fromFirestore(firestoreData);

      expect(restored.domain, original.domain);
      expect(restored.titleSelector, original.titleSelector);
      expect(restored.titleSelectorFallback, original.titleSelectorFallback);
      expect(restored.ingredientsSelector, original.ingredientsSelector);
      expect(
        restored.ingredientsSelectorFallback,
        original.ingredientsSelectorFallback,
      );
      expect(restored.instructionsSelector, original.instructionsSelector);
      expect(
        restored.instructionsSelectorFallback,
        original.instructionsSelectorFallback,
      );
      expect(restored.isSupported, original.isSupported);
      expect(restored.qualityScore, original.qualityScore);
      expect(restored.successCount, original.successCount);
      expect(restored.failureCount, original.failureCount);
    });

    test('fromFirestore handles missing fallback fields gracefully', () {
      final data = {
        'domain': 'test.se',
        'titleSelector': 'h1',
        'isSupported': true,
        'qualityScore': 0.7,
        'successCount': 5,
        'failureCount': 1,
      };

      final config = SiteConfig.fromFirestore(data);
      expect(config.titleSelectorFallback, isNull);
      expect(config.ingredientsSelectorFallback, isNull);
      expect(config.instructionsSelectorFallback, isNull);
    });

    test('copyWith preserves fallback selectors', () {
      const original = SiteConfig(
        domain: 'test.se',
        titleSelectorFallback: 'h2',
        ingredientsSelectorFallback: '.alt-ingredients li',
        instructionsSelectorFallback: '.alt-steps li',
      );

      final copy = original.copyWith(qualityScore: 0.9);

      expect(copy.titleSelectorFallback, 'h2');
      expect(copy.ingredientsSelectorFallback, '.alt-ingredients li');
      expect(copy.instructionsSelectorFallback, '.alt-steps li');
      expect(copy.qualityScore, 0.9);
    });

    test('toFirestore omits null fallback selectors', () {
      const config = SiteConfig(
        domain: 'test.se',
        titleSelector: 'h1',
      );

      final data = config.toFirestore();
      expect(data.containsKey('titleSelectorFallback'), isFalse);
      expect(data.containsKey('ingredientsSelectorFallback'), isFalse);
      expect(data.containsKey('instructionsSelectorFallback'), isFalse);
    });
  });
}
