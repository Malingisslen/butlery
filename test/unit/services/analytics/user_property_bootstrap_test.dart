/// Tests for [UserPropertyBootstrap] orchestration (BUT-636/637/639).
///
/// The repo-level setters are covered in `user_property_setters_test.dart`.
/// This file covers the orchestrator: that `emitAtSessionStart` fires the
/// right property names for a typical session, and that a failing setter
/// doesn't block the others (best-effort contract).
///
/// BUT-1410: the `subscription_tier` property was retired (dead monetization
/// plumbing — Butlery has no consumer subscription), so the tests that pinned
/// its `'free'` default and `emitSubscriptionTier` transitions were removed
/// with it.
library;

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/user_property_bootstrap.dart';
import 'package:butlery/models/user_profile.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

UserProfile _profile({required bool isMinor}) => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 'test@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  isMinor: isMinor,
);

void main() {
  group('UserPropertyBootstrap.emitAtSessionStart', () {
    late _MockAnalyticsService analytics;
    late UserPropertyBootstrap bootstrap;

    setUp(() {
      analytics = _MockAnalyticsService();
      when(
        () => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      bootstrap = UserPropertyBootstrap(analytics);
    });

    test('emits language + platform for a typical session', () async {
      await bootstrap.emitAtSessionStart(locale: const Locale('sv'));

      verify(
        () => analytics.setUserProperty(
          name: AnalyticsUserProperties.language,
          value: 'sv',
        ),
      ).called(1);
      verify(
        () => analytics.setUserProperty(
          name: AnalyticsUserProperties.platform,
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    test('remaining properties fire even if one setter throws', () async {
      // platform setter throws — language must still be attempted
      // (best-effort contract; failures are logged, never propagated).
      when(
        () => analytics.setUserProperty(
          name: AnalyticsUserProperties.platform,
          value: any(named: 'value'),
        ),
      ).thenThrow(Exception('analytics down'));

      await bootstrap.emitAtSessionStart(locale: const Locale('sv'));

      verify(
        () => analytics.setUserProperty(
          name: AnalyticsUserProperties.language,
          value: 'sv',
        ),
      ).called(1);
    });

    // BUT-674: analytics minimization for minors. The lifecycle_stage
    // user-property is a behavioral profiling signal (how active the account
    // is); it must NOT be emitted for a minor, while the coarse, non-identifying
    // language/platform properties are still allowed.
    test(
      'minor session suppresses lifecycle_stage but keeps language',
      () async {
        await bootstrap.emitAtSessionStart(
          locale: const Locale('sv'),
          profile: _profile(isMinor: true),
          cooksLast14Days: 5,
        );

        // Load-bearing: no lifecycle_stage for a minor, regardless of value.
        verifyNever(
          () => analytics.setUserProperty(
            name: AnalyticsUserProperties.lifecycleStage,
            value: any(named: 'value'),
          ),
        );
        // Minimization is selective — coarse language still emits.
        verify(
          () => analytics.setUserProperty(
            name: AnalyticsUserProperties.language,
            value: 'sv',
          ),
        ).called(1);
      },
    );

    test('adult session still emits lifecycle_stage (suppression is '
        'minor-specific, not a blanket removal)', () async {
      await bootstrap.emitAtSessionStart(
        locale: const Locale('sv'),
        profile: _profile(isMinor: false),
        cooksLast14Days: 5,
      );

      verify(
        () => analytics.setUserProperty(
          name: AnalyticsUserProperties.lifecycleStage,
          value: any(named: 'value'),
        ),
      ).called(1);
    });
  });

  // BUT-674: the cook-event re-emit path routes through emitLifecycle directly,
  // so the minor gate must also hold when it's called on its own — otherwise a
  // minor's activity level would leak on every cook completion.
  group('UserPropertyBootstrap.emitLifecycle', () {
    late _MockAnalyticsService analytics;
    late UserPropertyBootstrap bootstrap;

    setUp(() {
      analytics = _MockAnalyticsService();
      when(
        () => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      bootstrap = UserPropertyBootstrap(analytics);
    });

    test('minor cook-event re-emit does not emit lifecycle_stage', () async {
      await bootstrap.emitLifecycle(
        profile: _profile(isMinor: true),
        lastCookAt: DateTime(2024, 6, 1),
        cooksLast14Days: 3,
      );

      verifyNever(
        () => analytics.setUserProperty(
          name: AnalyticsUserProperties.lifecycleStage,
          value: any(named: 'value'),
        ),
      );
    });
  });
}
