import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/trackers/menu_events_tracker.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  group('MenuEventsTracker.logFirstMealPlanIfMilestone (BUT-576)', () {
    late _MockAnalyticsRepo repo;
    late _MockConsentService consent;
    late MenuEventsTracker tracker;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, Object>{});
      registerFallbackValue(ConsentPurpose.analytics);
    });

    setUp(() {
      // Empty SharedPreferences per test so milestone state doesn't leak.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      repo = _MockAnalyticsRepo();
      when(
        () => repo.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repo.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      consent = _MockConsentService();
      when(() => consent.hasConsent(any())).thenAnswer((_) async => true);

      tracker = MenuEventsTracker(repository: repo);
      tracker.setConsentService(consent);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test(
      'fires first_meal_plan + sets menu_activated user prop on first call',
      () async {
        final joinedAt = DateTime.now().subtract(const Duration(minutes: 45));

        final fired = await tracker.logFirstMealPlanIfMilestone(
          userId: 'user-1',
          recipeCountInPlan: 7,
          joinedAt: joinedAt,
        );

        expect(fired, isTrue);

        final captured =
            verify(
                  () => repo.logEvent(
                    name: 'first_meal_plan',
                    parameters: captureAny(named: 'parameters'),
                  ),
                ).captured.single
                as Map<String, Object>;

        expect(captured['recipe_count_in_plan'], 7);
        expect(captured['minutes_since_signup'], inInclusiveRange(44, 46));

        verify(
          () => repo.setUserProperty(
            name: 'menu_activated',
            value: 'true',
          ),
        ).called(1);
      },
    );

    test('omits minutes_since_signup when joinedAt is null', () async {
      await tracker.logFirstMealPlanIfMilestone(
        userId: 'user-2',
        recipeCountInPlan: 3,
        joinedAt: null,
      );

      final captured =
          verify(
                () => repo.logEvent(
                  name: 'first_meal_plan',
                  parameters: captureAny(named: 'parameters'),
                ),
              ).captured.single
              as Map<String, Object>;

      expect(captured.containsKey('minutes_since_signup'), isFalse);
      expect(captured['recipe_count_in_plan'], 3);
    });

    test('does NOT re-fire on subsequent saves for same user', () async {
      final firstFired = await tracker.logFirstMealPlanIfMilestone(
        userId: 'user-3',
        recipeCountInPlan: 5,
        joinedAt: DateTime.now(),
      );
      expect(firstFired, isTrue);

      clearInteractions(repo);
      final secondFired = await tracker.logFirstMealPlanIfMilestone(
        userId: 'user-3',
        recipeCountInPlan: 9,
        joinedAt: DateTime.now(),
      );
      expect(secondFired, isFalse);

      verifyNever(
        () => repo.logEvent(
          name: 'first_meal_plan',
          parameters: any(named: 'parameters'),
        ),
      );
      verifyNever(
        () => repo.setUserProperty(
          name: 'menu_activated',
          value: any(named: 'value'),
        ),
      );
    });

    test('dedupe is per-user — different uid still fires', () async {
      await tracker.logFirstMealPlanIfMilestone(
        userId: 'user-A',
        recipeCountInPlan: 5,
        joinedAt: DateTime.now(),
      );
      clearInteractions(repo);

      final fired = await tracker.logFirstMealPlanIfMilestone(
        userId: 'user-B',
        recipeCountInPlan: 5,
        joinedAt: DateTime.now(),
      );

      expect(fired, isTrue);
      verify(
        () => repo.logEvent(
          name: 'first_meal_plan',
          parameters: any(named: 'parameters'),
        ),
      ).called(1);
    });

    test('skips when userId is null/empty', () async {
      final firedNull = await tracker.logFirstMealPlanIfMilestone(
        userId: null,
        recipeCountInPlan: 5,
      );
      final firedEmpty = await tracker.logFirstMealPlanIfMilestone(
        userId: '',
        recipeCountInPlan: 5,
      );

      expect(firedNull, isFalse);
      expect(firedEmpty, isFalse);
      verifyNever(
        () => repo.logEvent(
          name: 'first_meal_plan',
          parameters: any(named: 'parameters'),
        ),
      );
    });

    test('skips when consent not granted', () async {
      when(() => consent.hasConsent(any())).thenAnswer((_) async => false);

      final fired = await tracker.logFirstMealPlanIfMilestone(
        userId: 'user-noconsent',
        recipeCountInPlan: 5,
      );

      expect(fired, isFalse);
      verifyNever(
        () => repo.logEvent(
          name: 'first_meal_plan',
          parameters: any(named: 'parameters'),
        ),
      );
    });
  });
}
