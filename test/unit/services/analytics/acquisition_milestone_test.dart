/// Unit tests for [AcquisitionMilestone] (BUT-612).
///
/// Verifies:
///   - First UTM arrival writes Firebase user properties + Firestore mirror
///   - Second UTM arrival does NOT overwrite either (first-write-wins)
///   - Empty/missing UTM source → no-op (no analytics pollution)
///   - Anonymous user → user properties set, Firestore deferred
///   - BUT-1997: no positive analytics consent → no Firestore write, and the
///     dedupe flag stays unset so a later consented arrival still writes
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/acquisition_attribution.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/acquisition_milestone.dart';
import 'package:butlery/services/analytics_service.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockAcquisitionRepository extends Mock
    implements AcquisitionRepository {}

class _MockConsentService extends Mock implements ConsentService {}

class _FakeAttribution extends Fake implements AcquisitionAttribution {}

void main() {
  group('AcquisitionMilestone (BUT-612)', () {
    late _MockAnalyticsService analytics;
    late _MockAcquisitionRepository repository;
    late _MockConsentService consent;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(_FakeAttribution());
    });

    setUp(() {
      // Reset prefs between tests so dedupe flags don't leak.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      analytics = _MockAnalyticsService();
      repository = _MockAcquisitionRepository();
      consent = _MockConsentService();

      when(
        () => analytics.setUserProperty(
          name: any(named: 'name'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repository.setAcquisitionIfAbsent(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => consent.hasConsent(ConsentPurpose.analytics),
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
          consentService: consent,
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
          consentService: consent,
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
          consentService: consent,
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
        consentService: consent,
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
        consentService: consent,
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
          consentService: consent,
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
        consentService: consent,
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
        consentService: consent,
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
        consentService: consent,
        userId: 'user-A',
        utmSource: 'instagram',
      );
      clearInteractions(repository);

      await AcquisitionMilestone.recordIfFirst(
        analytics: analytics,
        repository: repository,
        consentService: consent,
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
        consentService: consent,
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

    group('BUT-1997 analytics consent gate', () {
      const fsFlag = 'acquisition_firestore_v1_user-1';

      Future<void> arrive({ConsentService? consentService}) =>
          AcquisitionMilestone.recordIfFirst(
            analytics: analytics,
            repository: repository,
            consentService: consentService,
            userId: 'user-1',
            utmSource: 'instagram',
            utmMedium: 'social',
          );

      test('consent refused: no Firestore write, flag left unset', () async {
        when(
          () => consent.hasConsent(ConsentPurpose.analytics),
        ).thenAnswer((_) async => false);

        await arrive(consentService: consent);

        verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(fsFlag), isNull);
      });

      test(
        'consent lookup throws: no Firestore write, flag left unset',
        () async {
          when(
            () => consent.hasConsent(ConsentPurpose.analytics),
          ).thenThrow(StateError('lookup failed'));

          await arrive(consentService: consent);

          verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool(fsFlag), isNull);
        },
      );

      test('no consent service: no Firestore write', () async {
        await arrive();

        verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));
      });

      test('a skipped arrival does not block a later consented one', () async {
        when(
          () => consent.hasConsent(ConsentPurpose.analytics),
        ).thenAnswer((_) async => false);
        await arrive(consentService: consent);
        verifyNever(() => repository.setAcquisitionIfAbsent(any(), any()));

        when(
          () => consent.hasConsent(ConsentPurpose.analytics),
        ).thenAnswer((_) async => true);
        await arrive(consentService: consent);

        verify(
          () => repository.setAcquisitionIfAbsent('user-1', any()),
        ).called(1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(fsFlag), isTrue);
      });

      test('consent refused still sets user properties', () async {
        when(
          () => consent.hasConsent(ConsentPurpose.analytics),
        ).thenAnswer((_) async => false);

        await arrive(consentService: consent);

        verify(
          () => analytics.setUserProperty(
            name: 'acquisition_source',
            value: 'instagram',
          ),
        ).called(1);
      });
    });
  });
}
