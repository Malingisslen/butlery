import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/platform_bucket.dart';
import 'package:butlery/services/analytics/trackers/parse_events_tracker.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  group('ParseEventsTracker (BUT-552)', () {
    late _MockAnalyticsRepo repo;
    late _MockConsentService consent;
    late ParseEventsTracker tracker;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, Object>{});
      registerFallbackValue(ConsentPurpose.analytics);
    });

    setUp(() {
      repo = _MockAnalyticsRepo();
      when(() => repo.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});

      consent = _MockConsentService();
      when(() => consent.hasConsent(any())).thenAnswer((_) async => true);

      tracker = ParseEventsTracker(repository: repo);
      tracker.setConsentService(consent);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('logTierSucceeded', () {
      test('emits import_tier_succeeded with site_config tier params',
          () async {
        await tracker.logTierSucceeded(
          tier: ParseEventsTracker.tierSiteConfig,
          durationMs: 142,
          platformBucket: 'ica',
        );

        final captured = verify(() => repo.logEvent(
              name: 'import_tier_succeeded',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['tier'], 'site_config');
        expect(captured['duration_ms'], 142);
        expect(captured['platform_bucket'], 'ica');
        expect(captured.containsKey('session_id'), isFalse);
      });

      test('emits import_tier_succeeded with regex tier label', () async {
        await tracker.logTierSucceeded(
          tier: ParseEventsTracker.tierRegex,
          durationMs: 50,
          platformBucket: 'other',
        );

        final captured = verify(() => repo.logEvent(
              name: 'import_tier_succeeded',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['tier'], 'regex');
      });

      test('emits import_tier_succeeded with llm tier label', () async {
        await tracker.logTierSucceeded(
          tier: ParseEventsTracker.tierLlm,
          durationMs: 1820,
          platformBucket: 'other',
        );

        final captured = verify(() => repo.logEvent(
              name: 'import_tier_succeeded',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['tier'], 'llm');
        expect(captured['duration_ms'], 1820);
      });

      test('includes session_id when provided', () async {
        await tracker.logTierSucceeded(
          tier: ParseEventsTracker.tierSiteConfig,
          durationMs: 100,
          platformBucket: 'koket',
          sessionId: 'sess-abc-123',
        );

        final captured = verify(() => repo.logEvent(
              name: 'import_tier_succeeded',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['session_id'], 'sess-abc-123');
      });

      test('clamps negative duration to 0', () async {
        await tracker.logTierSucceeded(
          tier: ParseEventsTracker.tierLlm,
          durationMs: -5,
          platformBucket: 'other',
        );

        final captured = verify(() => repo.logEvent(
              name: 'import_tier_succeeded',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['duration_ms'], 0);
      });
    });

    group('logTierFailed', () {
      test('emits import_tier_failed with tier + duration + bucket', () async {
        await tracker.logTierFailed(
          tier: ParseEventsTracker.tierSiteConfig,
          durationMs: 75,
          platformBucket: 'allrecipes',
        );

        final captured = verify(() => repo.logEvent(
              name: 'import_tier_failed',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['tier'], 'site_config');
        expect(captured['duration_ms'], 75);
        expect(captured['platform_bucket'], 'allrecipes');
      });

      test('emits import_tier_failed for regex tier', () async {
        await tracker.logTierFailed(
          tier: ParseEventsTracker.tierRegex,
          durationMs: 30,
          platformBucket: 'other',
        );

        final captured = verify(() => repo.logEvent(
              name: 'import_tier_failed',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['tier'], 'regex');
      });

      test('emits import_tier_failed for llm tier', () async {
        await tracker.logTierFailed(
          tier: ParseEventsTracker.tierLlm,
          durationMs: 2500,
          platformBucket: 'other',
        );

        final captured = verify(() => repo.logEvent(
              name: 'import_tier_failed',
              parameters: captureAny(named: 'parameters'),
            )).captured.single as Map<String, Object>;

        expect(captured['tier'], 'llm');
      });
    });

    group('consent gating', () {
      test('does not log when consent is not granted', () async {
        when(() => consent.hasConsent(any())).thenAnswer((_) async => false);

        await tracker.logTierSucceeded(
          tier: ParseEventsTracker.tierSiteConfig,
          durationMs: 100,
          platformBucket: 'ica',
        );
        await tracker.logTierFailed(
          tier: ParseEventsTracker.tierLlm,
          durationMs: 100,
          platformBucket: 'other',
        );

        verifyNever(() => repo.logEvent(
              name: any(named: 'name'),
              parameters: any(named: 'parameters'),
            ));
      });
    });
  });

  group('PlatformBucket (BUT-552)', () {
    test('returns "none" for null/empty input', () {
      expect(PlatformBucket.bucketFor(null), 'none');
      expect(PlatformBucket.bucketFor(''), 'none');
    });

    test('buckets known Swedish recipe sites', () {
      expect(PlatformBucket.bucketFor('ica.se'), 'ica');
      expect(PlatformBucket.bucketFor('koket.se'), 'koket');
      expect(PlatformBucket.bucketFor('tasteline.com'), 'tasteline');
      expect(PlatformBucket.bucketFor('arla.se'), 'arla');
    });

    test('buckets known international recipe sites', () {
      expect(PlatformBucket.bucketFor('tasty.co'), 'tasty');
      expect(PlatformBucket.bucketFor('allrecipes.com'), 'allrecipes');
      expect(PlatformBucket.bucketFor('bbcgoodfood.com'), 'bbc_good_food');
    });

    test('strips www. prefix', () {
      expect(PlatformBucket.bucketFor('www.ica.se'), 'ica');
      expect(PlatformBucket.bucketFor('www.allrecipes.com'), 'allrecipes');
    });

    test('handles subdomains via suffix match', () {
      expect(PlatformBucket.bucketFor('recept.ica.se'), 'ica');
      expect(PlatformBucket.bucketFor('m.tasty.co'), 'tasty');
      expect(PlatformBucket.bucketFor('cooking.nytimes.com'), 'nyt_cooking');
    });

    test('is case-insensitive', () {
      expect(PlatformBucket.bucketFor('ICA.SE'), 'ica');
      expect(PlatformBucket.bucketFor('Ica.Se'), 'ica');
    });

    test('returns "other" for unknown hostnames', () {
      expect(PlatformBucket.bucketFor('some-blog.example'), 'other');
      expect(PlatformBucket.bucketFor('myrandomrecipes.org'), 'other');
    });

    test('exposes stable label constants', () {
      // These are stable contracts — analytics dashboards depend on them.
      expect(PlatformBucket.unknown, 'other');
      expect(PlatformBucket.none, 'none');
    });
  });
}
