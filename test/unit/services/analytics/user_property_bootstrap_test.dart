/// Tests for [UserPropertyBootstrap] orchestration (BUT-636/637/639/623).
///
/// The repo-level setters are covered in `user_property_setters_test.dart`.
/// This file covers the orchestrator: that `emitAtSessionStart` fires the
/// right property names with the right values for a typical session, and
/// that `subscription_tier` defaults to `'free'` (BUT-623) so the post-beta
/// paid-cohort slice has data from day 1.
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
      when(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      bootstrap = UserPropertyBootstrap(analytics);
    });

    test('emits subscription_tier=free by default (BUT-623)', () async {
      await bootstrap.emitAtSessionStart(locale: const Locale('sv'));

      verify(() => analytics.setUserProperty(
            name: AnalyticsUserProperties.subscriptionTier,
            value: 'free',
          )).called(1);
    });

    test('emits subscription_tier=pro when caller passes pro', () async {
      await bootstrap.emitAtSessionStart(
        locale: const Locale('sv'),
        subscriptionTier: 'pro',
      );

      verify(() => analytics.setUserProperty(
            name: AnalyticsUserProperties.subscriptionTier,
            value: 'pro',
          )).called(1);
    });

    test('all session-scoped properties fire even if one throws', () async {
      // platform setter throws — verify language + lifecycle + subscription
      // still get attempted (best-effort contract).
      when(() => analytics.setUserProperty(
            name: AnalyticsUserProperties.platform,
            value: any(named: 'value'),
          )).thenThrow(Exception('analytics down'));

      await bootstrap.emitAtSessionStart(locale: const Locale('sv'));

      verify(() => analytics.setUserProperty(
            name: AnalyticsUserProperties.language,
            value: 'sv',
          )).called(1);
      verify(() => analytics.setUserProperty(
            name: AnalyticsUserProperties.subscriptionTier,
            value: 'free',
          )).called(1);
    });
  });

  group('UserPropertyBootstrap.emitSubscriptionTier', () {
    late _MockAnalyticsService analytics;
    late UserPropertyBootstrap bootstrap;

    setUp(() {
      analytics = _MockAnalyticsService();
      when(() => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      bootstrap = UserPropertyBootstrap(analytics);
    });

    test('re-emits on tier transition (purchase → downgrade → trial)',
        () async {
      await bootstrap.emitSubscriptionTier('pro');
      await bootstrap.emitSubscriptionTier('free');
      await bootstrap.emitSubscriptionTier('trial');

      verifyInOrder([
        () => analytics.setUserProperty(
            name: AnalyticsUserProperties.subscriptionTier, value: 'pro'),
        () => analytics.setUserProperty(
            name: AnalyticsUserProperties.subscriptionTier, value: 'free'),
        () => analytics.setUserProperty(
            name: AnalyticsUserProperties.subscriptionTier, value: 'trial'),
      ]);
    });

    test('swallows analytics failure (best-effort)', () async {
      when(() => analytics.setUserProperty(
            name: AnalyticsUserProperties.subscriptionTier,
            value: any(named: 'value'),
          )).thenThrow(Exception('FA SDK error'));

      // Must not throw.
      await bootstrap.emitSubscriptionTier('pro');

      verify(() => analytics.setUserProperty(
            name: AnalyticsUserProperties.subscriptionTier,
            value: 'pro',
          )).called(1);
    });
  });
}
