/// Tests for the three new user-property setters on
/// [FirebaseAnalyticsRepository] (BUT-636 / BUT-637 / BUT-639).
///
/// Setters are thin — they shape the value, then delegate to
/// `setUserProperty(name, value)`. We mock [FirebaseAnalytics] and verify
/// the wire payload directly: that's the contract.
library;

// ignore_for_file: subtype_of_sealed_class

import 'dart:ui' show Locale;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/firebase/firebase_analytics_repository.dart';
import 'package:butlery/services/analytics/lifecycle_stage_classifier.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  group('FirebaseAnalyticsRepository — user-property setters', () {
    late FirebaseAnalyticsRepository repository;
    late _MockFirebaseAnalytics mockAnalytics;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      mockAnalytics = _MockFirebaseAnalytics();
      when(
        () => mockAnalytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      repository = FirebaseAnalyticsRepository(
        analytics: mockAnalytics,
        saltOverride: 'test-salt',
      );
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('setLanguageUserProperty (BUT-636)', () {
      test('emits language=sv for Swedish locale', () async {
        await repository.setLanguageUserProperty(const Locale('sv'));

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'language',
            value: 'sv',
          ),
        ).called(1);
      });

      test('emits language=en for English locale', () async {
        await repository.setLanguageUserProperty(const Locale('en'));

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'language',
            value: 'en',
          ),
        ).called(1);
      });

      test('strips region from sv_FI (cardinality control)', () async {
        await repository.setLanguageUserProperty(const Locale('sv', 'FI'));

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'language',
            value: 'sv',
          ),
        ).called(1);
        verifyNever(
          () => mockAnalytics.setUserProperty(
            name: 'language',
            value: 'sv_FI',
          ),
        );
      });
    });

    group('setPlatformUserProperty (BUT-637)', () {
      test('emits platform=android on Android', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await repository.setPlatformUserProperty();

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'platform',
            value: 'android',
          ),
        ).called(1);
      });

      test('emits platform=ios on iOS', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await repository.setPlatformUserProperty();

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'platform',
            value: 'ios',
          ),
        ).called(1);
      });

      test('emits platform=macos on macOS', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        await repository.setPlatformUserProperty();

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'platform',
            value: 'macos',
          ),
        ).called(1);
      });

      test('emits platform=windows on Windows', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await repository.setPlatformUserProperty();

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'platform',
            value: 'windows',
          ),
        ).called(1);
      });

      test('emits platform=linux on Linux', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        await repository.setPlatformUserProperty();

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'platform',
            value: 'linux',
          ),
        ).called(1);
      });
    });

    group('setLifecycleStage (BUT-639)', () {
      test(
        'new_ stage emits as "new" (trailing underscore stripped)',
        () async {
          await repository.setLifecycleStage(LifecycleStage.new_);

          verify(
            () => mockAnalytics.setUserProperty(
              name: 'lifecycle_stage',
              value: 'new',
            ),
          ).called(1);
        },
      );

      test('all other stages emit their bare enum name', () async {
        await repository.setLifecycleStage(LifecycleStage.activated);
        await repository.setLifecycleStage(LifecycleStage.habitual);
        await repository.setLifecycleStage(LifecycleStage.dormant);
        await repository.setLifecycleStage(LifecycleStage.churned);

        verify(
          () => mockAnalytics.setUserProperty(
            name: 'lifecycle_stage',
            value: 'activated',
          ),
        ).called(1);
        verify(
          () => mockAnalytics.setUserProperty(
            name: 'lifecycle_stage',
            value: 'habitual',
          ),
        ).called(1);
        verify(
          () => mockAnalytics.setUserProperty(
            name: 'lifecycle_stage',
            value: 'dormant',
          ),
        ).called(1);
        verify(
          () => mockAnalytics.setUserProperty(
            name: 'lifecycle_stage',
            value: 'churned',
          ),
        ).called(1);
      });
    });
  });
}
