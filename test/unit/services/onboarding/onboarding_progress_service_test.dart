/// Unit tests for OnboardingProgressService (BUT-675).
///
/// Verifies persistence shape, resume-routing, and the 24h-stale nudge
/// trigger. Uses FakeFirebaseFirestore so we exercise the real wire format
/// (timestamps + merged fields), not a hand-rolled mock that could drift.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/onboarding/onboarding_progress_service.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('OnboardingProgressService (BUT-675)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockAnalyticsService analytics;
    late OnboardingProgressService service;

    const uid = 'user-onboarding-1';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      service = OnboardingProgressService(
        firestore: fakeFirestore,
        analytics: analytics,
      );
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test(
      'readProgress returns empty snapshot when doc does not exist',
      () async {
        final progress = await service.readProgress(uid);

        expect(progress.hasProgress, isFalse);
        expect(progress.lastCompletedStep, isNull);
        expect(progress.completed, isFalse);
      },
    );

    test(
      'markStepComplete writes the step and completed=false on intermediate',
      () async {
        await service.markStepComplete(
          userId: uid,
          step: OnboardingStep.allergens,
          isFinalStep: false,
        );

        final snap = await fakeFirestore
            .collection('users')
            .doc(uid)
            .collection('onboarding')
            .doc('progress')
            .get();

        expect(snap.exists, isTrue);
        final data = snap.data()!;
        expect(data['step'], equals('allergens'));
        expect(data['completed'], isFalse);
        // FakeFirebaseFirestore resolves serverTimestamp() to a real Timestamp.
        expect(data['completedAt'], isA<Timestamp>());
      },
    );

    test(
      'markStepComplete with isFinalStep=true sets completed=true',
      () async {
        await service.markStepComplete(
          userId: uid,
          step: OnboardingStep.firstRecipe,
          isFinalStep: true,
        );

        final progress = await service.readProgress(uid);
        expect(progress.completed, isTrue);
        expect(progress.lastCompletedStep, OnboardingStep.firstRecipe);
      },
    );

    test('readProgress round-trips a previously-written step', () async {
      await service.markStepComplete(
        userId: uid,
        step: OnboardingStep.dietary,
        isFinalStep: false,
      );

      final progress = await service.readProgress(uid);
      expect(progress.lastCompletedStep, OnboardingStep.dietary);
      expect(progress.completed, isFalse);
      expect(progress.completedAt, isNotNull);
    });

    group('resolveResumePageIndex', () {
      test('null lastStep -> page 0 (start at age gate)', () {
        const progress = OnboardingProgress();
        expect(service.resolveResumePageIndex(progress), 0);
      });

      test('completed=true -> null (route home)', () {
        final progress = OnboardingProgress(
          lastCompletedStep: OnboardingStep.firstRecipe,
          completedAt: DateTime(2026),
          completed: true,
        );
        expect(service.resolveResumePageIndex(progress), isNull);
      });

      test('age-gate finished -> page 1 (welcome)', () {
        final progress = OnboardingProgress(
          lastCompletedStep: OnboardingStep.ageGate,
          completedAt: DateTime(2026),
        );
        expect(service.resolveResumePageIndex(progress), 1);
      });

      test('allergens finished -> page 3 (dietary)', () {
        final progress = OnboardingProgress(
          lastCompletedStep: OnboardingStep.allergens,
          completedAt: DateTime(2026),
        );
        expect(service.resolveResumePageIndex(progress), 3);
      });

      test('dietary finished -> page 4 (first recipe)', () {
        final progress = OnboardingProgress(
          lastCompletedStep: OnboardingStep.dietary,
          completedAt: DateTime(2026),
        );
        expect(service.resolveResumePageIndex(progress), 4);
      });
    });

    group('24h abandon nudge', () {
      test('does NOT trigger when no progress recorded', () {
        const progress = OnboardingProgress();
        expect(
          service.shouldShowAbandonedNudge(progress, DateTime(2026, 4, 30)),
          isFalse,
        );
      });

      test('does NOT trigger when onboarding is completed', () {
        final progress = OnboardingProgress(
          lastCompletedStep: OnboardingStep.firstRecipe,
          completedAt: DateTime(2026, 4, 28),
          completed: true,
        );
        expect(
          service.shouldShowAbandonedNudge(progress, DateTime(2026, 4, 30)),
          isFalse,
        );
      });

      test('triggers exactly at the 24h threshold', () {
        // Pure-time arithmetic: fakeAsync's elapse doesn't advance
        // `DateTime.now()` (it only ticks Timer/Future.delayed), so we shift
        // `now` by computing it relative to a fixed `completedAt`. Same
        // semantic as a fakeAsync time-skip, with no wall-clock surprises.
        final completedAt = DateTime(2026, 4, 30, 10, 0);
        final progress = OnboardingProgress(
          lastCompletedStep: OnboardingStep.allergens,
          completedAt: completedAt,
        );

        // Just before 24h — must not nudge.
        expect(
          service.shouldShowAbandonedNudge(
            progress,
            completedAt.add(const Duration(hours: 23, minutes: 59)),
          ),
          isFalse,
        );

        // At 24h+1m — must nudge.
        expect(
          service.shouldShowAbandonedNudge(
            progress,
            completedAt.add(const Duration(hours: 24, minutes: 1)),
          ),
          isTrue,
        );

        // Exactly at 24h — boundary inclusive (>= threshold).
        expect(
          service.shouldShowAbandonedNudge(
            progress,
            completedAt.add(const Duration(hours: 24)),
          ),
          isTrue,
        );
      });
    });

    group('analytics events', () {
      test(
        'logResumed emits onboarding_resumed with last_step parameter',
        () async {
          await service.logResumed(lastStep: OnboardingStep.allergens);

          verify(
            () => analytics.logEvent(
              name: AnalyticsEvents.onboardingResumed,
              parameters: {'last_step': 'allergens'},
            ),
          ).called(1);
        },
      );

      test(
        'logAbandoned emits onboarding_abandoned with last_step parameter',
        () async {
          await service.logAbandoned(lastStep: OnboardingStep.dietary);

          verify(
            () => analytics.logEvent(
              name: AnalyticsEvents.onboardingAbandoned,
              parameters: {'last_step': 'dietary'},
            ),
          ).called(1);
        },
      );

      test('logResumed with null step emits last_step=none', () async {
        await service.logResumed(lastStep: null);

        verify(
          () => analytics.logEvent(
            name: AnalyticsEvents.onboardingResumed,
            parameters: {'last_step': 'none'},
          ),
        ).called(1);
      });
    });

    test('OnboardingStep.fromWireName is reversible for all values', () {
      for (final step in OnboardingStep.values) {
        expect(
          OnboardingStep.fromWireName(step.wireName),
          equals(step),
          reason: 'wire-name round-trip failed for ${step.name}',
        );
      }
      expect(OnboardingStep.fromWireName(null), isNull);
      expect(OnboardingStep.fromWireName('not_a_step'), isNull);
    });
  });
}
