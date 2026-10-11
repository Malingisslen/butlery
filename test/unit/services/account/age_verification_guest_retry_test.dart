// BUT-920: a guest who left the upgrade screen after its last step failed
// gets one quiet retry of finishGuestUpgrade on a later start.

import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuth extends Mock implements AuthService {}

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

class _MockToken extends Mock implements IdTokenResult {}

void main() {
  late _MockAuth auth;
  late _MockFunctions functions;
  late _MockCallable callable;
  late AgeVerificationService service;

  /// A signed-in user; the defaults are the account the retry is for.
  _MockUser user({
    bool anonymous = false,
    String provider = 'password',
    Map<String, dynamic>? claims,
  }) {
    final info = _MockUserInfo();
    when(() => info.providerId).thenReturn(provider);
    final token = _MockToken();
    when(() => token.claims).thenReturn(claims ?? const {});
    final u = _MockUser();
    when(() => u.uid).thenReturn('uid-1');
    when(() => u.isAnonymous).thenReturn(anonymous);
    when(() => u.providerData).thenReturn([info]);
    when(() => u.getIdTokenResult()).thenAnswer((_) async => token);
    return u;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _MockAuth();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable('finishGuestUpgrade')).thenReturn(
      callable,
    );
    when(
      () => callable.call<dynamic>(),
    ).thenAnswer((_) async => _MockResult());
    when(() => auth.refreshSession()).thenAnswer((_) async => true);
    service = AgeVerificationService(authService: auth, functions: functions);
  });

  test('an unfinished upgrade is retried', () async {
    final u = user();
    when(() => auth.currentUser).thenReturn(u);

    expect(await service.retryUnfinishedGuestUpgrade(birthYear: 1990), isTrue);
    verify(() => callable.call<dynamic>()).called(1);
  });

  test('it is retried once per account on the device, also across starts '
      'and when the server refuses it', () async {
    final u = user();
    when(() => auth.currentUser).thenReturn(u);
    when(
      () => callable.call<dynamic>(),
    ).thenThrow(
      FirebaseFunctionsException(code: 'failed-precondition', message: 'no'),
    );

    expect(
      await service.retryUnfinishedGuestUpgrade(birthYear: 1990),
      isFalse,
    );
    final nextStart = AgeVerificationService(
      authService: auth,
      functions: functions,
    );
    expect(
      await nextStart.retryUnfinishedGuestUpgrade(birthYear: 1990),
      isFalse,
    );

    verify(() => callable.call<dynamic>()).called(1);
  });

  for (final code in ['unavailable', 'deadline-exceeded', 'unknown']) {
    test('a retry the server never answered ($code) is tried again on the '
        'next start', () async {
      final u = user();
      when(() => auth.currentUser).thenReturn(u);
      when(
        () => callable.call<dynamic>(),
      ).thenThrow(FirebaseFunctionsException(code: code, message: 'offline'));
      expect(
        await service.retryUnfinishedGuestUpgrade(birthYear: 1990),
        isFalse,
      );

      when(
        () => callable.call<dynamic>(),
      ).thenAnswer((_) async => _MockResult());
      final nextStart = AgeVerificationService(
        authService: auth,
        functions: functions,
      );
      expect(
        await nextStart.retryUnfinishedGuestUpgrade(birthYear: 1990),
        isTrue,
      );
      expect(
        await nextStart.retryUnfinishedGuestUpgrade(birthYear: 1990),
        isFalse,
      );
      verify(() => callable.call<dynamic>()).called(2);
    });
  }

  test('a start that fails before reaching the server keeps the retry for '
      'the next start', () async {
    final offline = user();
    when(
      () => offline.getIdTokenResult(),
    ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    when(() => auth.currentUser).thenReturn(offline);
    expect(
      await service.retryUnfinishedGuestUpgrade(birthYear: 1990),
      isFalse,
    );

    final online = user();
    when(() => auth.currentUser).thenReturn(online);
    final nextStart = AgeVerificationService(
      authService: auth,
      functions: functions,
    );
    expect(
      await nextStart.retryUnfinishedGuestUpgrade(birthYear: 1990),
      isTrue,
    );
  });

  test('the token is refreshed before the call, so the server sees the '
      'linked account rather than the guest', () async {
    final u = user();
    when(() => auth.currentUser).thenReturn(u);

    await service.finishGuestUpgrade();

    verifyInOrder([
      () => auth.refreshSession(),
      () => callable.call<dynamic>(),
      () => auth.refreshSession(),
    ]);
  });

  test('an account that already has the claim is left alone', () async {
    final u = user(claims: {'ageCompliant': true});
    when(() => auth.currentUser).thenReturn(u);

    expect(
      await service.retryUnfinishedGuestUpgrade(birthYear: 1990),
      isFalse,
    );
    verifyNever(() => callable.call<dynamic>());
  });

  test('a guest, a Google account or a profile with no birth year is left '
      'alone', () async {
    final guest = user(anonymous: true);
    when(() => auth.currentUser).thenReturn(guest);
    expect(
      await service.retryUnfinishedGuestUpgrade(birthYear: 1990),
      isFalse,
    );

    final google = user(provider: 'google.com');
    when(() => auth.currentUser).thenReturn(google);
    expect(
      await service.retryUnfinishedGuestUpgrade(birthYear: 1990),
      isFalse,
    );

    final noYear = user();
    when(() => auth.currentUser).thenReturn(noYear);
    expect(
      await service.retryUnfinishedGuestUpgrade(birthYear: null),
      isFalse,
    );

    verifyNever(() => callable.call<dynamic>());
  });
}
