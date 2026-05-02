import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/trackers/recipe_events_tracker.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  group('RecipeEventsTracker first_search milestone (BUT-588)', () {
    late _MockAnalyticsRepo repo;
    late _MockConsentService consent;
    late RecipeEventsTracker tracker;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, Object>{});
      registerFallbackValue(ConsentPurpose.analytics);
    });

    setUp(() {
      // Empty SharedPreferences per test so first_search dedupe state
      // doesn't leak across cases.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      repo = _MockAnalyticsRepo();
      when(() => repo.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});
      when(() => repo.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      consent = _MockConsentService();
      when(() => consent.hasConsent(any())).thenAnswer((_) async => true);

      tracker = RecipeEventsTracker(repository: repo);
      tracker.setConsentService(consent);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('fires first_search + sets search_activated user prop on first call',
        () async {
      final joinedAt = DateTime.now().subtract(const Duration(minutes: 45));

      final fired = await tracker.logFirstSearchIfMilestone(
        userId: 'user-1',
        recipeCountAtTime: 12,
        joinedAt: joinedAt,
      );

      expect(fired, isTrue);

      final captured = verify(() => repo.logEvent(
            name: 'first_search',
            parameters: captureAny(named: 'parameters'),
          )).captured.single as Map<String, Object>;

      expect(captured['recipe_count_at_time'], 12);
      // Allow 1-min slack for clock drift between setUp and the call.
      expect(captured['minutes_since_signup'], inInclusiveRange(44, 46));
      // BUT-421: raw query MUST NOT appear in milestone params.
      expect(captured.containsKey('query'), isFalse);
      expect(captured.containsKey('search_query'), isFalse);

      verify(() => repo.setUserProperty(
            name: 'search_activated',
            value: 'true',
          )).called(1);
    });

    test('omits minutes_since_signup when joinedAt is null', () async {
      await tracker.logFirstSearchIfMilestone(
        userId: 'user-2',
        recipeCountAtTime: 0,
        joinedAt: null,
      );

      final captured = verify(() => repo.logEvent(
            name: 'first_search',
            parameters: captureAny(named: 'parameters'),
          )).captured.single as Map<String, Object>;

      expect(captured.containsKey('minutes_since_signup'), isFalse);
      expect(captured['recipe_count_at_time'], 0);
    });

    test('does NOT re-fire on subsequent searches for same user', () async {
      // First search — fires.
      final firstFired = await tracker.logFirstSearchIfMilestone(
        userId: 'user-3',
        recipeCountAtTime: 5,
        joinedAt: DateTime.now(),
      );
      expect(firstFired, isTrue);

      // Second search — should be a no-op.
      clearInteractions(repo);
      final secondFired = await tracker.logFirstSearchIfMilestone(
        userId: 'user-3',
        recipeCountAtTime: 6,
        joinedAt: DateTime.now(),
      );
      expect(secondFired, isFalse);

      verifyNever(() => repo.logEvent(
            name: 'first_search',
            parameters: any(named: 'parameters'),
          ));
      verifyNever(() => repo.setUserProperty(
            name: 'search_activated',
            value: any(named: 'value'),
          ));
    });

    test('dedupe is per-user — different uid still fires', () async {
      await tracker.logFirstSearchIfMilestone(
        userId: 'user-A',
        recipeCountAtTime: 3,
        joinedAt: DateTime.now(),
      );
      clearInteractions(repo);

      final fired = await tracker.logFirstSearchIfMilestone(
        userId: 'user-B',
        recipeCountAtTime: 7,
        joinedAt: DateTime.now(),
      );

      expect(fired, isTrue);
      verify(() => repo.logEvent(
            name: 'first_search',
            parameters: any(named: 'parameters'),
          )).called(1);
    });

    test('skips when userId is null/empty', () async {
      final firedNull = await tracker.logFirstSearchIfMilestone(
        userId: null,
        recipeCountAtTime: 5,
      );
      final firedEmpty = await tracker.logFirstSearchIfMilestone(
        userId: '',
        recipeCountAtTime: 5,
      );

      expect(firedNull, isFalse);
      expect(firedEmpty, isFalse);
      verifyNever(() => repo.logEvent(
            name: 'first_search',
            parameters: any(named: 'parameters'),
          ));
    });

    test('skips when consent not granted', () async {
      when(() => consent.hasConsent(any())).thenAnswer((_) async => false);

      final fired = await tracker.logFirstSearchIfMilestone(
        userId: 'user-noconsent',
        recipeCountAtTime: 5,
      );

      expect(fired, isFalse);
      verifyNever(() => repo.logEvent(
            name: 'first_search',
            parameters: any(named: 'parameters'),
          ));
    });
  });
}
