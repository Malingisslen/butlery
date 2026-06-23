/// Unit tests for [AcquisitionMilestone] (BUT-612).
///
/// Verifies:
///   - First UTM arrival writes Firebase user properties + Firestore mirror
///   - Second UTM arrival does NOT overwrite either (first-write-wins)
///   - Empty/missing UTM source → no-op (no analytics pollution)
///   - Anonymous user → user properties set, Firestore deferred
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/acquisition_attribution.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';
import 'package:butlery/services/analytics/acquisition_milestone.dart';
import 'package:butlery/services/analytics_service.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockAcquisitionRepository extends Mock
    implements AcquisitionRepository {}

class _FakeAttribution extends Fake implements AcquisitionAttribution {}

void main() {
  group('AcquisitionMilestone (BUT-612)', () {
    late _MockAnalyticsService analytics;
    late _MockAcquisitionRepository repository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(_FakeAttribution());
    });

    setUp(() {
      // Reset prefs between tests so dedupe flags don't leak.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      analytics = _MockAnalyticsService();
      repository = _MockAcquisitionRepository();

      when(
        () => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repository.setAcquisitionIfAbsent(any(), any()),
      ).thenAnswer((_) async => true);
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test(
      'first UTM arrival writes user properties AND Firestore doc',
      () async {
        await AcquisitionMilestone.recordIfFirst(
          analytics: analytics,
          repository: repository,
          userId: 'user-1',
          utmSource: 'instagram',
          utmMedium: 'social',
          utmCampaign: 'spring2026',
        );

        verify(
          () => analytics.setUserProperty(
            name: 'acquisition_source',
            value: 'instagram',
          ),
        ).called(1);
        verify(
          () => analytics.setUserProperty(
            name: 'acquisition_medium',
            value: 'social',
          ),
        ).called(1);
        verify(
          () => analytics.setUserProperty(
            name: 'acquisition_campaign',
            value: 'spring2026',
          ),
        ).called(1);
        verify(
          () => repository.setAcquisitionIfAbsent(
            'user-1',
            any(),
          ),
        ).called(1);
      },
    );

    test(
      'second UTM arrival does NOT overwrite user properties or Firestore',
      () async {
        // First arrival.
        await AcquisitionMilestone.recordIfFirst(
          analytics: analytics,
          repository: repository,
          userId: 'user-1',
          utmSource: 'instagram',
          utmMedium: 'social',
          utmCampaign: 'spring2026',
        );

        clearInteractions(analytics);
        clearInteractions(repository);

        // Second arrival, different campaign — must be deduped.
        await AcquisitionMilestone.recordIfFirst(
          analytics: analytics,
          repository: repository,
          userId: 'user-1',
          utmSource: 'tiktok',
          utmMedium: 'social',
          utmCampaign: 'summer2026',
        );

        verifyNever(
          () => analytics.setUserProperty(
            name: any(named: 'name'),
            value: any(named: 'value'),
          ),
        );
        verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));
      },
    );

    test('empty utmSource → no writes anywhere', () async {
      await AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: repository,
        userId: 'user-1',
        utmSource: '',
        utmMedium: 'social',
        utmCampaign: 'x',
      );

      verifyNever(
        () => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      );
      verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));
    });

    test('null utmSource → no writes anywhere', () async {
      await AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: repository,
        userId: 'user-1',
        utmSource: null,
        utmMedium: 'social',
        utmCampaign: 'x',
      );

      verifyNever(
        () => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      );
      verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));
    });

    test(
      'anonymous user (null uid): user properties set, Firestore deferred',
      () async {
        await AcquisitionMilestone.recordIfFirst(
          analytics: analytics,
          repository: repository,
          userId: null,
          utmSource: 'instagram',
          utmMedium: 'social',
          utmCampaign: 'spring2026',
        );

        verify(
          () => analytics.setUserProperty(
            name: 'acquisition_source',
            value: 'instagram',
          ),
        ).called(1);
        verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));
      },
    );

    test('anonymous-then-authed: anonymous click sets props, '
        'first authed click writes Firestore', () async {
      // Anonymous arrival.
      await AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: repository,
        userId: null,
        utmSource: 'instagram',
        utmMedium: 'social',
        utmCampaign: 'spring2026',
      );

      verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));
      clearInteractions(repository);

      // Same user signs in and clicks again — anon flag already prevents
      // re-setting user properties, but Firestore mirror has not run yet.
      await AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: repository,
        userId: 'user-1',
        utmSource: 'instagram',
        utmMedium: 'social',
        utmCampaign: 'spring2026',
      );

      verify(
        () => repository.setAcquisitionIfAbsent('user-1', any()),
      ).called(1);
    });

    test('dedupe is per-user — different uid still records', () async {
      await AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: repository,
        userId: 'user-A',
        utmSource: 'instagram',
      );
      clearInteractions(repository);

      await AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: repository,
        userId: 'user-B',
        utmSource: 'tiktok',
      );

      verify(
        () => repository.setAcquisitionIfAbsent('user-B', any()),
      ).called(1);
    });

    test('null repository → only user properties are set', () async {
      await AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: null,
        userId: 'user-1',
        utmSource: 'instagram',
      );

      verify(
        () => analytics.setUserProperty(
          name: 'acquisition_source',
          value: 'instagram',
        ),
      ).called(1);
    });
  });
}
