// BUT-802 HIGH-PA4: tracker-level tests for the cooking-mode events.
// Companion to the viewmodel test (`test/unit/viewmodels/
// cooking_mode_viewmodel_test.dart`) which proves the lifecycle wiring; this
// file proves the event names + parameter shapes the tracker emits.
library;

import 'package:clock/clock.dart';
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
  group(
    'RecipeEventsTracker cooking-mode instrumentation (BUT-802 HIGH-PA4)',
    () {
      late _MockAnalyticsRepo repo;
      late _MockConsentService consent;
      late RecipeEventsTracker tracker;

      setUpAll(() async {
        await BaseUnitTest.setupUnit();
        registerFallbackValue(<String, Object>{});
        registerFallbackValue(ConsentPurpose.analytics);
      });

      setUp(() {
        SharedPreferences.setMockInitialValues(<String, Object>{});

        repo = _MockAnalyticsRepo();
        when(
          () => repo.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ),
        ).thenAnswer((_) async {});

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

      test(
        'logCookingSessionStarted emits event with iso8601 started_at',
        () async {
          await withClock(
            Clock.fixed(DateTime.utc(2026, 5, 21, 12, 0, 0)),
            () async {
              await tracker.logCookingSessionStarted(
                recipeId: 'recipe-1',
                sessionId: 'sess-abc',
              );
            },
          );

          final captured =
              verify(
                    () => repo.logEvent(
                      name: 'cooking_session_started',
                      parameters: captureAny(named: 'parameters'),
                    ),
                  ).captured.single
                  as Map<String, Object>;

          expect(captured['recipe_id'], 'recipe-1');
          expect(captured['session_id'], 'sess-abc');
          expect(captured['started_at'], '2026-05-21T12:00:00.000Z');
        },
      );

      test('logCookingStepAdvanced emits with 0-based from/to', () async {
        await tracker.logCookingStepAdvanced(
          recipeId: 'recipe-1',
          sessionId: 'sess-abc',
          fromStep: 2,
          toStep: 3,
        );

        final captured =
            verify(
                  () => repo.logEvent(
                    name: 'cooking_step_advanced',
                    parameters: captureAny(named: 'parameters'),
                  ),
                ).captured.single
                as Map<String, Object>;

        expect(captured['recipe_id'], 'recipe-1');
        expect(captured['session_id'], 'sess-abc');
        expect(captured['from_step'], 2);
        expect(captured['to_step'], 3);
      });

      test(
        'logCookingSessionCompleted emits with int duration + steps_viewed',
        () async {
          await tracker.logCookingSessionCompleted(
            recipeId: 'recipe-1',
            sessionId: 'sess-abc',
            durationSec: 423,
            stepsViewed: 7,
          );

          final captured =
              verify(
                    () => repo.logEvent(
                      name: 'cooking_session_completed',
                      parameters: captureAny(named: 'parameters'),
                    ),
                  ).captured.single
                  as Map<String, Object>;

          expect(captured['recipe_id'], 'recipe-1');
          expect(captured['session_id'], 'sess-abc');
          expect(captured['duration_sec'], 423);
          expect(captured['steps_viewed'], 7);
          // Boolean-as-string check enforced by BaseTracker (BUT-523).
          expect(
            captured.values.whereType<String>(),
            isNot(anyElement(anyOf('true', 'false'))),
          );
        },
      );

      test('logCookingSessionAbandoned emits with last_step', () async {
        await tracker.logCookingSessionAbandoned(
          recipeId: 'recipe-1',
          sessionId: 'sess-abc',
          durationSec: 60,
          lastStep: 1,
        );

        final captured =
            verify(
                  () => repo.logEvent(
                    name: 'cooking_session_abandoned',
                    parameters: captureAny(named: 'parameters'),
                  ),
                ).captured.single
                as Map<String, Object>;

        expect(captured['recipe_id'], 'recipe-1');
        expect(captured['session_id'], 'sess-abc');
        expect(captured['duration_sec'], 60);
        expect(captured['last_step'], 1);
      });

      test('cooking events are gated on analytics consent', () async {
        when(() => consent.hasConsent(any())).thenAnswer((_) async => false);

        await tracker.logCookingSessionStarted(
          recipeId: 'recipe-1',
          sessionId: 'sess-abc',
        );
        await tracker.logCookingStepAdvanced(
          recipeId: 'recipe-1',
          sessionId: 'sess-abc',
          fromStep: 0,
          toStep: 1,
        );
        await tracker.logCookingSessionCompleted(
          recipeId: 'recipe-1',
          sessionId: 'sess-abc',
          durationSec: 60,
          stepsViewed: 2,
        );
        await tracker.logCookingSessionAbandoned(
          recipeId: 'recipe-1',
          sessionId: 'sess-abc',
          durationSec: 30,
          lastStep: 0,
        );

        verifyNever(
          () => repo.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ),
        );
      });
    },
  );
}
