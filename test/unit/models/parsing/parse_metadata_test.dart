/// Direct unit tests for [ParseMetadata] + [ImportSource] (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Metadata about how a recipe was parsed. Covers the ImportSource extension
/// (network / social / LLM / cache-TTL classification), the cacheHit factory,
/// the derived getters (successfulTier, usedLlm, finalQuality, tierSummary),
/// copyWith, JSON (de)serialization with the safe-enum source fallback, and
/// source+cacheKey+parserVersion equality.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/tier_result.dart';

void main() {
  TierResult successTier(String name, double q, {int? tokens}) => TierResult(
    tierName: name,
    success: true,
    quality: q,
    duration: Duration.zero,
    tokensUsed: tokens,
  );

  group('ImportSource extension', () {
    test('requiresNetwork for remote sources only', () {
      expect(ImportSource.url.requiresNetwork, isTrue);
      expect(ImportSource.youtube.requiresNetwork, isTrue);
      expect(ImportSource.text.requiresNetwork, isFalse);
      expect(ImportSource.photo.requiresNetwork, isFalse);
    });

    test('isSocialMedia for instagram/tiktok only', () {
      expect(ImportSource.instagram.isSocialMedia, isTrue);
      expect(ImportSource.tiktok.isSocialMedia, isTrue);
      expect(ImportSource.youtube.isSocialMedia, isFalse);
    });

    test('mayNeedLlm for text/social/photo, not structured url/file', () {
      expect(ImportSource.text.mayNeedLlm, isTrue);
      expect(ImportSource.photo.mayNeedLlm, isTrue);
      expect(ImportSource.url.mayNeedLlm, isFalse);
      expect(ImportSource.file.mayNeedLlm, isFalse);
    });

    test('defaultCacheTtlDays per source with a 90-day default', () {
      expect(ImportSource.youtube.defaultCacheTtlDays, 180);
      expect(ImportSource.url.defaultCacheTtlDays, 90);
      expect(ImportSource.instagram.defaultCacheTtlDays, 60);
      expect(ImportSource.photo.defaultCacheTtlDays, 30);
      expect(ImportSource.file.defaultCacheTtlDays, 90); // default branch
    });
  });

  group('cacheHit factory', () {
    test('has no tiers, zero time, and a clock-pinned timestamp', () {
      final t = DateTime.utc(2026, 1, 1);
      withClock(Clock.fixed(t), () {
        final m = ParseMetadata.cacheHit(
          source: ImportSource.url,
          parserVersion: '2.0',
          domain: 'ica.se',
          cacheKey: 'k',
        );
        expect(m.tierResults, isEmpty);
        expect(m.totalParseTime, Duration.zero);
        expect(m.timestamp, t);
        expect(m.domain, 'ica.se');
      });
    });
  });

  group('derived getters', () {
    final meta = ParseMetadata(
      source: ImportSource.url,
      parserVersion: '1.0',
      timestamp: DateTime.utc(2026),
      totalParseTime: const Duration(milliseconds: 500),
      tierResults: [
        successTier('SchemaOrg', 0.8),
        TierResult.failure(
          tierName: 'RuleBased',
          reason: TierFailureReason.noData,
          duration: Duration.zero,
        ),
        successTier('LLM', 0.95, tokens: 100),
      ],
    );

    test('successfulTier is the first successful tier name', () {
      expect(meta.successfulTier, 'SchemaOrg');
    });

    test('finalQuality is the last successful tier quality', () {
      expect(meta.finalQuality, 0.95);
    });

    test('usedLlm requires a successful LLM tier with tokens', () {
      expect(meta.usedLlm, isTrue);
      // An LLM tier without tokens does not count.
      final noTokens = meta.copyWith(
        tierResults: [successTier('LLM', 0.9)],
      );
      expect(noTokens.usedLlm, isFalse);
    });

    test('tierSummary maps each tier to success or its failure reason', () {
      expect(meta.tierSummary, {
        'SchemaOrg': 'success',
        'RuleBased': 'noData',
        'LLM': 'success',
      });
    });

    test('finalQuality is 0 and successfulTier null with no success', () {
      final allFailed = meta.copyWith(
        tierResults: [
          TierResult.failure(
            tierName: 'x',
            reason: TierFailureReason.timeout,
            duration: Duration.zero,
          ),
        ],
      );
      expect(allFailed.successfulTier, isNull);
      expect(allFailed.finalQuality, 0.0);
    });
  });

  group('JSON', () {
    final meta = ParseMetadata(
      source: ImportSource.instagram,
      domain: 'instagram.com',
      parserVersion: '3.1',
      timestamp: DateTime.utc(2026, 1, 5),
      totalParseTime: const Duration(milliseconds: 750),
      tierResults: [successTier('LLM', 0.9, tokens: 50)],
      totalTokensUsed: 50,
    );

    test('toJson carries the core + successfulTier, omits nulls', () {
      final json = meta.toJson();
      expect(json['source'], 'instagram');
      expect(json['parserVersion'], '3.1');
      expect(json['totalParseTimeMs'], 750);
      expect(json['successfulTier'], 'LLM');
      expect(json.containsKey('sourceUrl'), isFalse);
    });

    test('fromJson restores fields (tierResults always empty)', () {
      final restored = ParseMetadata.fromJson(meta.toJson());
      expect(restored.source, ImportSource.instagram);
      expect(restored.parserVersion, '3.1');
      expect(restored.totalParseTime.inMilliseconds, 750);
      expect(restored.tierResults, isEmpty);
      expect(
        restored.timestamp.isAtSameMomentAs(DateTime.utc(2026, 1, 5)),
        isTrue,
      );
    });

    test('fromJson falls back to url source + 1.0 version on bad input', () {
      final restored = ParseMetadata.fromJson({
        'source': 'bogus',
        'timestamp': '2026-01-01T00:00:00.000Z',
      });
      expect(restored.source, ImportSource.url);
      expect(restored.parserVersion, '1.0');
    });
  });

  group('equality', () {
    test('is by source + cacheKey + parserVersion', () {
      final a = ParseMetadata.cacheHit(
        source: ImportSource.url,
        parserVersion: '1.0',
        cacheKey: 'k1',
      );
      final sameKeys = a.copyWith(domain: 'different.com');
      expect(a, equals(sameKeys));
      final diff = ParseMetadata.cacheHit(
        source: ImportSource.url,
        parserVersion: '1.0',
        cacheKey: 'k2',
      );
      expect(a == diff, isFalse);
    });
  });
}
