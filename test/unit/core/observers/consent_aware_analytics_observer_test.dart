// ignore_for_file: subtype_of_sealed_class

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/observers/consent_aware_analytics_observer.dart';

class _MockFirebaseAnalyticsObserver extends Mock
    implements FirebaseAnalyticsObserver {}

class _MockRoute extends Mock implements Route<dynamic> {}

void main() {
  group('ConsentAwareAnalyticsObserver (BUT-570)', () {
    late _MockFirebaseAnalyticsObserver inner;
    late ConsentAwareAnalyticsObserver observer;
    late _MockRoute routeA;
    late _MockRoute routeB;

    setUpAll(() {
      registerFallbackValue(_MockRoute());
    });

    setUp(() {
      inner = _MockFirebaseAnalyticsObserver();
      // Consent service resolver returns null — we drive state via
      // debugSetConsent, proving the callback-time gate works in isolation.
      observer = ConsentAwareAnalyticsObserver(
        inner: inner,
        consentServiceResolver: () => null,
      );
      routeA = _MockRoute();
      routeB = _MockRoute();
    });

    test(
        'didPush no-ops while consent is denied (default state is fail-closed)',
        () {
      observer.didPush(routeA, routeB);
      verifyNever(() => inner.didPush(any(), any()));
    });

    test('didPop no-ops while consent is denied', () {
      observer.didPop(routeA, routeB);
      verifyNever(() => inner.didPop(any(), any()));
    });

    test('didReplace no-ops while consent is denied', () {
      observer.didReplace(newRoute: routeA, oldRoute: routeB);
      verifyNever(() => inner.didReplace(
          newRoute: any(named: 'newRoute'), oldRoute: any(named: 'oldRoute')));
    });

    test('didRemove no-ops while consent is denied', () {
      observer.didRemove(routeA, routeB);
      verifyNever(() => inner.didRemove(any(), any()));
    });

    test('didPush forwards to inner observer once consent is granted', () {
      observer.debugSetConsent(true);
      observer.didPush(routeA, routeB);
      verify(() => inner.didPush(routeA, routeB)).called(1);
    });

    test('didPop forwards to inner observer once consent is granted', () {
      observer.debugSetConsent(true);
      observer.didPop(routeA, routeB);
      verify(() => inner.didPop(routeA, routeB)).called(1);
    });

    test(
        'granting then withdrawing consent toggles forwarding off again (right to withdraw)',
        () {
      observer.debugSetConsent(true);
      observer.didPush(routeA, routeB);
      verify(() => inner.didPush(routeA, routeB)).called(1);

      observer.debugSetConsent(false);
      observer.didPush(routeA, routeB);
      // No additional call after withdrawal.
      verifyNever(() => inner.didPush(routeA, routeB));
    });
  });
}
