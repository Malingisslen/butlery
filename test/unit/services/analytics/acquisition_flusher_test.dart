/// BUT-2406: the pending campaign channel is written only for a registered,
/// consenting, non-guest user, and the Play referrer is read only after that.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/acquisition_attribution.dart';
import 'package:butlery/repositories/interfaces/acquisition_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/acquisition_flusher.dart';
import 'package:butlery/services/analytics/pending_acquisition.dart';

import '../../../test_support/base_unit_test.dart';

class _Auth extends Mock implements AuthRepository {}

class _User extends Mock implements User {}

class _Repo extends Mock implements AcquisitionRepository {}

class _Consent extends Mock implements ConsentService {}

class _Fake extends Fake implements AcquisitionAttribution {}

void main() {
  late _Auth auth;
  late _User user;
  late _Repo repo;
  late _Consent consent;
  var referrerReads = 0;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_Fake());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PendingAcquisition.clear();
    referrerReads = 0;
    auth = _Auth();
    user = _User();
    repo = _Repo();
    consent = _Consent();
    when(() => user.uid).thenReturn('u1');
    when(() => user.isAnonymous).thenReturn(false);
    when(() => auth.currentUser).thenReturn(user);
    when(
      () => consent.hasConsent(ConsentPurpose.analytics),
    ).thenAnswer((_) async => true);
    when(
      () => repo.setAcquisitionIfAbsent(any(), any()),
    ).thenAnswer((_) async => true);
  });

  AcquisitionFlusher flusher({String? referrer}) => AcquisitionFlusher(
    auth: auth,
    consent: consent,
    repository: repo,
    analytics: null,
    readReferrer: referrer == null
        ? null
        : () async {
            referrerReads++;
            return referrer;
          },
  );

  test(
    'writes the pending channel with an empty campaign, then clears it',
    () async {
      PendingAcquisition.rememberIfAbsent(
        AcquisitionChannel.from('Instagram', 'social'),
      );
      await flusher().flush();
      final written =
          verify(
                () => repo.setAcquisitionIfAbsent('u1', captureAny()),
              ).captured.single
              as AcquisitionAttribution;
      expect(written.source, 'instagram');
      expect(written.medium, 'social');
      expect(written.campaign, '');
      expect(PendingAcquisition.current, isNull);
    },
  );

  test('without consent nothing is written and the channel is kept', () async {
    when(
      () => consent.hasConsent(ConsentPurpose.analytics),
    ).thenAnswer((_) async => false);
    PendingAcquisition.rememberIfAbsent(AcquisitionChannel.from('tiktok', ''));
    await flusher(referrer: 'utm_source=instagram').flush();
    verifyNever(() => repo.setAcquisitionIfAbsent(any(), any()));
    expect(referrerReads, 0);
    expect(PendingAcquisition.current?.source, 'tiktok');
  });

  test('a guest writes nothing and reads no referrer', () async {
    when(() => user.isAnonymous).thenReturn(true);
    PendingAcquisition.rememberIfAbsent(AcquisitionChannel.from('tiktok', ''));
    await flusher(referrer: 'utm_source=instagram').flush();
    verifyNever(() => repo.setAcquisitionIfAbsent(any(), any()));
    expect(referrerReads, 0);
  });

  test('the Play referrer is read once and mapped to the allowlist', () async {
    final f = flusher(
      referrer: 'utm_source=newsletter&utm_medium=email&gclid=SECRET',
    );
    await f.flush();
    await f.flush();
    expect(referrerReads, 1);
    final written =
        verify(
              () => repo.setAcquisitionIfAbsent('u1', captureAny()),
            ).captured.single
            as AcquisitionAttribution;
    expect(written.source, 'newsletter');
    expect(written.medium, 'email');
  });

  test('an organic Play install does not replace a link channel', () async {
    PendingAcquisition.rememberIfAbsent(
      AcquisitionChannel.from('tiktok', 'social'),
    );
    await flusher(
      referrer: 'utm_source=google-play&utm_medium=organic',
    ).flush();
    final written =
        verify(
              () => repo.setAcquisitionIfAbsent('u1', captureAny()),
            ).captured.single
            as AcquisitionAttribution;
    expect(written.source, 'tiktok');
  });

  test('unknown and malformed values become other or nothing', () {
    expect(AcquisitionChannel.from('a@b.se', 'zz')?.source, 'other');
    expect(AcquisitionChannel.from('a@b.se', 'zz')?.medium, 'other');
    expect(AcquisitionChannel.from('', 'social'), isNull);
    expect(AcquisitionChannel.fromInstallReferrer('%zz'), isNull);
    expect(AcquisitionChannel.fromInstallReferrer(null), isNull);
  });

  test('an install referrer replaces an earlier link channel', () async {
    PendingAcquisition.rememberIfAbsent(
      AcquisitionChannel.from('tiktok', 'social'),
    );
    PendingAcquisition.rememberInstallReferrer(
      AcquisitionChannel.from('instagram', 'social'),
    );
    expect(PendingAcquisition.current?.source, 'instagram');
  });

  test('the first link seen wins over a later one', () {
    PendingAcquisition.rememberIfAbsent(
      AcquisitionChannel.from('tiktok', 'social'),
    );
    PendingAcquisition.rememberIfAbsent(
      AcquisitionChannel.from('instagram', 'social'),
    );
    expect(PendingAcquisition.current?.source, 'tiktok');
  });
}
