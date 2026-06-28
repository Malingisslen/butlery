/// Direct unit tests for [TierResult] + [TierFailureReason] (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Result of a single parsing tier. Covers the failure-family factories
/// (success/quality/reason wiring), the wasSkipped/timedOut getters, copyWith,
/// the tierName+success+quality equality, and the exhaustive Swedish userMessage
/// for every failure reason. The success factory (which forwards
/// recipe.overallQuality) needs a full ParsedRecipe+ParseMetadata fixture and is
/// left to the parser-service tests.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/tier_result.dart';

void main() {
  const dur = Duration(milliseconds: 120);

  group('failure-family factories', () {
    test('failure sets success=false, quality 0, and the reason', () {
      final r = TierResult.failure(
        tierName: 'LLM',
        reason: TierFailureReason.networkError,
        duration: dur,
      );
      expect(r.success, isFalse);
      expect(r.quality, 0.0);
      expect(r.recipe, isNull);
      expect(r.failureReason, TierFailureReason.networkError);
    });

    test('skipped/noData/timeout/parseError carry their reason', () {
      expect(
        TierResult.skipped(tierName: 't').failureReason,
        TierFailureReason.skipped,
      );
      expect(
        TierResult.noData(tierName: 't', duration: dur).failureReason,
        TierFailureReason.noData,
      );
      expect(
        TierResult.timeout(tierName: 't', duration: dur).failureReason,
        TierFailureReason.timeout,
      );
      expect(
        TierResult.parseError(tierName: 't', duration: dur).failureReason,
        TierFailureReason.parseError,
      );
    });

    test('skipped defaults to zero duration', () {
      expect(TierResult.skipped(tierName: 't').duration, Duration.zero);
    });
  });

  group('getters', () {
    test('wasSkipped / timedOut reflect the failure reason', () {
      final skipped = TierResult.skipped(tierName: 't');
      final timeout = TierResult.timeout(tierName: 't', duration: dur);
      expect(skipped.wasSkipped, isTrue);
      expect(skipped.timedOut, isFalse);
      expect(timeout.timedOut, isTrue);
      expect(timeout.wasSkipped, isFalse);
    });
  });

  group('copyWith', () {
    test('updates a field while preserving the rest', () {
      final base = TierResult.failure(
        tierName: 'RuleBased',
        reason: TierFailureReason.noData,
        duration: dur,
      );
      final bumped = base.copyWith(quality: 0.5, success: true);
      expect(bumped.quality, 0.5);
      expect(bumped.success, isTrue);
      expect(bumped.tierName, 'RuleBased');
    });
  });

  group('equality', () {
    test('is by tierName + success + quality', () {
      final a = TierResult.failure(
        tierName: 't',
        reason: TierFailureReason.noData,
        duration: dur,
      );
      // Same triple, different failure reason → still equal.
      final b = TierResult.failure(
        tierName: 't',
        reason: TierFailureReason.timeout,
        duration: const Duration(seconds: 1),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      // Different tier → not equal.
      final c = TierResult.failure(
        tierName: 'other',
        reason: TierFailureReason.noData,
        duration: dur,
      );
      expect(a == c, isFalse);
    });
  });

  group('TierFailureReason.userMessage', () {
    test('every reason has a non-empty Swedish message', () {
      for (final reason in TierFailureReason.values) {
        expect(reason.userMessage.trim(), isNotEmpty, reason: reason.name);
      }
    });

    test('rate-limited message mentions the daily limit', () {
      expect(
        TierFailureReason.rateLimited.userMessage,
        contains('Daglig gräns'),
      );
    });
  });
}
