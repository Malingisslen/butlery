/// Unit tests for [ExperimentAssignment] (BUT-657).
///
/// Verifies:
///   - First call sets user property AND logs `experiment_assigned`.
///   - Second call same session same variant: re-sets property,
///     does NOT re-log.
///   - Re-assignment to a different variant in same session re-logs
///     (RC mid-session change is rare but supported).
///   - Empty experimentName / empty variant → no-op (no FA pollution).
///   - Special-character experiment name is sanitized (lowercase,
///     non-alnum collapsed to `_`, truncated to 20 chars).
///   - Routes through [AnalyticsService.setUserProperty] / `logEvent`
///     (the consent-gated path) — proven by the only-mock-the-service
///     setup: when the gate denies (mock's `thenAnswer` never invoked
///     by upstream), nothing leaks.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/experiment_assignment.dart';
import 'package:butlery/services/analytics_service.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('ExperimentAssignment (BUT-657)', () {
    late _MockAnalyticsService analytics;
    late ExperimentAssignment assignment;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      analytics = _MockAnalyticsService();

      when(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      when(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});

      assignment = ExperimentAssignment(analytics);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('first call sets user property and logs experiment_assigned',
        () async {
      await assignment.setExperimentAssignment(
        experimentName: 'winback_copy',
        variant: 'treatment',
      );

      verify(() => analytics.setUserProperty(
            name: 'exp_winback_copy',
            value: 'treatment',
          )).called(1);
      verify(() => analytics.logEvent(
            name: AnalyticsEvents.experimentAssigned,
            parameters: <String, Object>{
              'experiment_name': 'winback_copy',
              'variant': 'treatment',
            },
          )).called(1);
    });

    test(
        'second call same session same variant re-sets property '
        'but does NOT re-log', () async {
      await assignment.setExperimentAssignment(
        experimentName: 'winback_copy',
        variant: 'treatment',
      );
      await assignment.setExperimentAssignment(
        experimentName: 'winback_copy',
        variant: 'treatment',
      );

      verify(() => analytics.setUserProperty(
            name: 'exp_winback_copy',
            value: 'treatment',
          )).called(2);
      verify(() => analytics.logEvent(
            name: AnalyticsEvents.experimentAssigned,
            parameters: any(named: 'parameters'),
          )).called(1);
    });

    test('mid-session variant change re-logs', () async {
      await assignment.setExperimentAssignment(
        experimentName: 'winback_copy',
        variant: 'control',
      );
      await assignment.setExperimentAssignment(
        experimentName: 'winback_copy',
        variant: 'treatment',
      );

      verify(() => analytics.logEvent(
            name: AnalyticsEvents.experimentAssigned,
            parameters: any(named: 'parameters'),
          )).called(2);
    });

    test('empty experimentName is a no-op', () async {
      await assignment.setExperimentAssignment(
        experimentName: '',
        variant: 'treatment',
      );

      verifyNever(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          ));
      verifyNever(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ));
    });

    test('empty variant is a no-op', () async {
      await assignment.setExperimentAssignment(
        experimentName: 'winback_copy',
        variant: '',
      );

      verifyNever(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          ));
      verifyNever(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          ));
    });

    test('special characters in experimentName are sanitized', () async {
      await assignment.setExperimentAssignment(
        experimentName: 'WinBack Copy / 2026-Q2!',
        variant: 'treatment',
      );

      verify(() => analytics.setUserProperty(
            name: 'exp_winback_copy_2026_q2',
            value: 'treatment',
          )).called(1);
      verify(() => analytics.logEvent(
            name: AnalyticsEvents.experimentAssigned,
            parameters: <String, Object>{
              'experiment_name': 'winback_copy_2026_q2',
              'variant': 'treatment',
            },
          )).called(1);
    });

    test('over-long experiment name truncated to 20 char suffix', () async {
      await assignment.setExperimentAssignment(
        experimentName: 'super_long_experiment_name_that_overflows',
        variant: 'a',
      );

      // 'super_long_experiment_name_that_overflows' lowercased = same
      // length 41. After cleanup (already valid chars) → 41 chars,
      // truncate to 20 → 'super_long_experimen'.
      verify(() => analytics.setUserProperty(
            name: 'exp_super_long_experimen',
            value: 'a',
          )).called(1);
    });

    test(
        'pre-consent gate: when AnalyticsService no-ops, helper '
        'completes without throwing and adds nothing to dedup set', () async {
      // Simulate consent gate by having the service throw — the helper
      // logs a warning and proceeds. dedup set should NOT contain the
      // key for the failed event so a later (post-consent) call retries.
      when(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenThrow(StateError('consent denied'));

      await assignment.setExperimentAssignment(
        experimentName: 'winback_copy',
        variant: 'treatment',
      );

      expect(assignment.debugEmittedKeys, isEmpty,
          reason: 'failed log must not flip dedup → next call retries');

      // Reset to success and assert next call DOES emit.
      when(() => analytics.logEvent(
            name: any(named: 'name'),
            parameters: any(named: 'parameters'),
          )).thenAnswer((_) async {});

      await assignment.setExperimentAssignment(
        experimentName: 'winback_copy',
        variant: 'treatment',
      );

      verify(() => analytics.logEvent(
            name: AnalyticsEvents.experimentAssigned,
            parameters: any(named: 'parameters'),
          )).called(2); // once threw, once succeeded
      expect(assignment.debugEmittedKeys, contains('winback_copy=treatment'));
    });
  });
}
