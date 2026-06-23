// ignore_for_file: subtype_of_sealed_class

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/firebase/firebase_analytics_repository.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

/// BUT-412 — the repository must NEVER enable analytics collection on its own.
/// Collection is the caller's responsibility, gated on ConsentPurpose.analytics
/// in `main._enableCollectionIfConsented()`.
///
/// These tests simulate the full consent lifecycle at the caller boundary
/// (repo + setAnalyticsCollectionEnabled(bool)) without pulling in the DI
/// container — that's intentional. We're proving the contract the caller
/// depends on.
void main() {
  group('FirebaseAnalyticsRepository consent lifecycle (BUT-412)', () {
    late FirebaseAnalyticsRepository repository;
    late _MockFirebaseAnalytics mockAnalytics;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      mockAnalytics = _MockFirebaseAnalytics();
      when(
        () => mockAnalytics.setAnalyticsCollectionEnabled(any()),
      ).thenAnswer((_) async {});

      repository = FirebaseAnalyticsRepository(
        analytics: mockAnalytics,
        saltOverride: 'test-salt',
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test(
      '(a) after initialize() with no consent, collection is OFF — fail closed by default',
      () async {
        await repository.initialize();

        // The only collection-enabled call made by initialize() must pass false.
        final calls = verify(
          () => mockAnalytics.setAnalyticsCollectionEnabled(captureAny()),
        ).captured;
        expect(calls, equals(<bool>[false]));
      },
    );

    test('(b) after consent granted, caller flips collection ON', () async {
      await repository.initialize();

      // Simulate main._enableCollectionIfConsented() firing after
      // ConsentService reports analytics=true.
      await repository.setAnalyticsCollectionEnabled(true);

      final calls = verify(
        () => mockAnalytics.setAnalyticsCollectionEnabled(captureAny()),
      ).captured;
      // bootstrap disable then post-consent enable.
      expect(calls, equals(<bool>[false, true]));
    });

    test(
      '(c) after consent withdrawn mid-session, caller flips collection back OFF',
      () async {
        await repository.initialize();
        await repository.setAnalyticsCollectionEnabled(true); // granted
        await repository.setAnalyticsCollectionEnabled(false); // withdrawn

        final calls = verify(
          () => mockAnalytics.setAnalyticsCollectionEnabled(captureAny()),
        ).captured;
        expect(calls, equals(<bool>[false, true, false]));
      },
    );

    test(
      'initialize() NEVER calls setAnalyticsCollectionEnabled(true) regardless of debug mode',
      () async {
        await repository.initialize();
        verifyNever(() => mockAnalytics.setAnalyticsCollectionEnabled(true));
      },
    );
  });
}
