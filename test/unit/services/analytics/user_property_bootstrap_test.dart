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

class _MockAnalyticsService extends Mock implements AnalyticsService {}

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
  });
}
