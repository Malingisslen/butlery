import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/in_app_review_service.dart';

import '../../test_support/base_unit_test.dart';

class _MockInAppReview extends Mock implements InAppReview {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('InAppReviewService (BUT-678)', () {
    late _MockInAppReview review;
    late _MockAnalyticsService analytics;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Per-test SharedPreferences isolation.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      review = _MockInAppReview();
      analytics = _MockAnalyticsService();

      when(() => review.isAvailable()).thenAnswer((_) async => true);
      when(() => review.requestReview()).thenAnswer((_) async {});
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    /// Builds a service whose `now()` returns [now] and whose first-seen
    /// timestamp has already been seeded [daysAgo] days back. Records
    /// [priorHappyCount] qualifying cooks pre-state.
    InAppReviewService buildService({
      required DateTime now,
      required int daysAgo,
      int priorHappyCount = 0,
      int? lastPromptDaysAgo,
    }) {
      final firstSeen = now.subtract(Duration(days: daysAgo));
      final values = <String, Object>{
        'in_app_review_first_seen_at_v1': firstSeen.millisecondsSinceEpoch,
        'in_app_review_happy_cook_count_v1': priorHappyCount,
      };
      if (lastPromptDaysAgo != null) {
        values['last_in_app_review_prompt_at'] = now
            .subtract(Duration(days: lastPromptDaysAgo))
            .millisecondsSinceEpoch;
      }
      SharedPreferences.setMockInitialValues(values);

      return InAppReviewService(
        inAppReview: review,
        analytics: analytics,
        now: () => now,
      );
    }

    test('fires when 3rd happy cook + >7 days + no prior prompt', () async {
      final now = DateTime(2026, 1, 30);
      final svc = buildService(
        now: now,
        daysAgo: 10,
        priorHappyCount: 2,
      );

      final fired = await svc.maybeRequest(rating: 5.0);

      expect(fired, isTrue);
      verify(() => review.requestReview()).called(1);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('last_in_app_review_prompt_at'),
        now.millisecondsSinceEpoch,
        reason: 'last-prompt-at must persist on success',
      );
    });

    test('does NOT fire when rating is below 4 stars', () async {
      final now = DateTime(2026, 1, 30);
      final svc = buildService(
        now: now,
        daysAgo: 30,
        priorHappyCount: 10,
      );

      final fired = await svc.maybeRequest(rating: 3.5);

      expect(fired, isFalse);
      verifyNever(() => review.requestReview());

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('in_app_review_happy_cook_count_v1'),
        10,
        reason: 'Sub-threshold rating must not increment the happy counter',
      );
    });

    test('does NOT fire when <7 days since install', () async {
      final now = DateTime(2026, 1, 30);
      final svc = buildService(
        now: now,
        daysAgo: 3, // Below 7-day threshold.
        priorHappyCount: 10,
      );

      final fired = await svc.maybeRequest(rating: 5.0);

      expect(fired, isFalse);
      verifyNever(() => review.requestReview());
    });

    test('does NOT fire when previous prompt within 90 days', () async {
      final now = DateTime(2026, 1, 30);
      final svc = buildService(
        now: now,
        daysAgo: 120,
        priorHappyCount: 10,
        lastPromptDaysAgo: 30, // Asked 30 days ago — too soon.
      );

      final fired = await svc.maybeRequest(rating: 5.0);

      expect(fired, isFalse);
      verifyNever(() => review.requestReview());
    });

    test('DOES fire when previous prompt was >90 days ago', () async {
      final now = DateTime(2026, 1, 30);
      final svc = buildService(
        now: now,
        daysAgo: 200,
        priorHappyCount: 10,
        lastPromptDaysAgo: 91,
      );

      final fired = await svc.maybeRequest(rating: 4.0);

      expect(fired, isTrue);
      verify(() => review.requestReview()).called(1);
    });

    test('does NOT fire when happy cook count would still be <3', () async {
      final now = DateTime(2026, 1, 30);
      final svc = buildService(
        now: now,
        daysAgo: 30,
        priorHappyCount: 1, // This call → 2, still <3.
      );

      final fired = await svc.maybeRequest(rating: 5.0);

      expect(fired, isFalse);
      verifyNever(() => review.requestReview());

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('in_app_review_happy_cook_count_v1'),
        2,
        reason: 'Counter must still increment for qualifying ratings',
      );
    });

    test(
      'last_in_app_review_prompt_at NOT written when prompt fails',
      () async {
        // OS reports unavailable (e.g. simulator) — service should bail
        // without recording the prompt timestamp.
        when(() => review.isAvailable()).thenAnswer((_) async => false);

        final now = DateTime(2026, 1, 30);
        final svc = buildService(
          now: now,
          daysAgo: 30,
          priorHappyCount: 10,
        );

        final fired = await svc.maybeRequest(rating: 5.0);

        expect(fired, isFalse);
        verifyNever(() => review.requestReview());

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt('last_in_app_review_prompt_at'),
          isNull,
          reason: 'Failed prompt must not start the 90-day cooldown',
        );
      },
    );

    test(
      'logs in_app_review_requested + _dismissed analytics on success',
      () async {
        final now = DateTime(2026, 1, 30);
        final svc = buildService(
          now: now,
          daysAgo: 30,
          priorHappyCount: 10,
        );

        await svc.maybeRequest(rating: 5.0);

        verify(
          () => analytics.logEvent(
            name: 'in_app_review_requested',
            parameters: any(named: 'parameters'),
          ),
        ).called(1);
        verify(
          () => analytics.logEvent(
            name: 'in_app_review_dismissed',
            parameters: any(named: 'parameters'),
          ),
        ).called(1);
      },
    );
  });
}
