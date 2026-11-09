import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth/session_revocation_service.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

void main() {
  late _MockAuthRepository repo;
  late _MockFunctions functions;
  late _MockCallable callable;
  late int signOuts;
  late SessionRevocationService service;

  _MockResult resultWith(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    return result;
  }

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    repo = _MockAuthRepository();
    functions = _MockFunctions();
    callable = _MockCallable();
    signOuts = 0;
    when(
      () => functions.httpsCallable(
        'revokeOtherSessions',
        options: any(named: 'options'),
      ),
    ).thenReturn(callable);
    when(() => repo.signInWithCustomToken(any())).thenAnswer((_) async {});
    service = SessionRevocationService(
      authRepository: repo,
      functions: functions,
      signOutAfterFailure: () async => signOuts++,
    );
  });

  FirebaseFunctionsException refusal(String code, [Object? details]) =>
      FirebaseFunctionsException(message: 'x', code: code, details: details);

  test('asks for a limited-use App Check token', () async {
    when(
      () => callable.call<dynamic>(),
    ).thenAnswer((_) async => resultWith({'customToken': 't'}));

    await service.revokeOtherSessions();

    final options =
        verify(
              () => functions.httpsCallable(
                'revokeOtherSessions',
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as HttpsCallableOptions;
    expect(options.limitedUseAppCheckToken, isTrue);
  });

  test('success: this device signs in with the token and stays in', () async {
    when(
      () => callable.call<dynamic>(),
    ).thenAnswer((_) async => resultWith({'customToken': 'the-token'}));

    expect(
      await service.revokeOtherSessions(),
      SessionRevocationOutcome.revoked,
    );
    verify(() => repo.signInWithCustomToken('the-token')).called(1);
    expect(signOuts, 0);
  });

  test('a failed swap is retried once and then succeeds', () async {
    when(
      () => callable.call<dynamic>(),
    ).thenAnswer((_) async => resultWith({'customToken': 't'}));
    var calls = 0;
    when(() => repo.signInWithCustomToken(any())).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('network');
    });

    expect(
      await service.revokeOtherSessions(),
      SessionRevocationOutcome.revoked,
    );
    expect(calls, 2);
    expect(signOuts, 0);
  });

  test(
    'two failed swaps end in the ordinary sign-out, not half signed in',
    () async {
      when(
        () => callable.call<dynamic>(),
      ).thenAnswer((_) async => resultWith({'customToken': 't'}));
      when(() => repo.signInWithCustomToken(any())).thenThrow(Exception('x'));

      expect(
        await service.revokeOtherSessions(),
        SessionRevocationOutcome.signedOutAfterFailure,
      );
      verify(() => repo.signInWithCustomToken('t')).called(2);
      expect(signOuts, 1);
    },
  );

  test(
    'a reply without a token after the revoke also signs this device out',
    () async {
      when(
        () => callable.call<dynamic>(),
      ).thenAnswer((_) async => resultWith({}));

      expect(
        await service.revokeOtherSessions(),
        SessionRevocationOutcome.signedOutAfterFailure,
      );
      verifyNever(() => repo.signInWithCustomToken(any()));
      expect(signOuts, 1);
    },
  );

  group('server refusals change nothing on this device', () {
    for (final entry in {
      'requires-recent-login (failed-precondition)': (
        refusal('failed-precondition', {'code': 'requires-recent-login'}),
        SessionRevocationOutcome.reauthRequired,
      ),
      'provider refusal (permission-denied with the same prompt)': (
        refusal('permission-denied', {'code': 'requires-recent-login'}),
        SessionRevocationOutcome.reauthRequired,
      ),
      'rate limit': (
        refusal('resource-exhausted'),
        SessionRevocationOutcome.rateLimited,
      ),
      'unavailable': (
        refusal('unavailable'),
        SessionRevocationOutcome.failed,
      ),
    }.entries) {
      test(entry.key, () async {
        when(() => callable.call<dynamic>()).thenThrow(entry.value.$1);

        expect(await service.revokeOtherSessions(), entry.value.$2);
        verifyNever(() => repo.signInWithCustomToken(any()));
        expect(signOuts, 0);
      });
    }
  });

  test('a second press while the first is running is ignored', () async {
    final gate = Completer<HttpsCallableResult<dynamic>>();
    when(() => callable.call<dynamic>()).thenAnswer((_) => gate.future);

    final first = service.revokeOtherSessions();
    expect(
      await service.revokeOtherSessions(),
      SessionRevocationOutcome.busy,
    );
    gate.complete(resultWith({'customToken': 't'}));
    expect(await first, SessionRevocationOutcome.revoked);
    verify(() => callable.call<dynamic>()).called(1);
  });

  test('the lock is released after every finished outcome', () async {
    when(() => callable.call<dynamic>()).thenThrow(
      refusal('failed-precondition', {'code': 'requires-recent-login'}),
    );
    expect(
      await service.revokeOtherSessions(),
      SessionRevocationOutcome.reauthRequired,
    );

    when(() => callable.call<dynamic>()).thenThrow(Exception('offline'));
    expect(
      await service.revokeOtherSessions(),
      SessionRevocationOutcome.failed,
    );

    when(
      () => callable.call<dynamic>(),
    ).thenAnswer((_) async => resultWith({'customToken': 't'}));
    expect(
      await service.revokeOtherSessions(),
      SessionRevocationOutcome.revoked,
    );
    verify(() => callable.call<dynamic>()).called(3);
  });

  test(
    'no log call in the service or the handler can carry the custom token',
    () {
      // The token is a credential for the account. Logging goes through
      // AppLogger, so no AppLogger line may mention the variable.
      for (final path in [
        'lib/services/auth/session_revocation_service.dart',
        'lib/widgets/common/profile/handlers/session_revocation_handler.dart',
      ]) {
        final lines = File(path).readAsLinesSync();
        final leaks = [
          for (final line in lines)
            if (line.contains('AppLogger') &&
                RegExp(r'\$\{?(token|customToken)\b').hasMatch(line))
              line,
        ];
        expect(leaks, isEmpty, reason: path);
      }
    },
  );

  test('without functions nothing is attempted', () async {
    final offline = SessionRevocationService(
      authRepository: repo,
      signOutAfterFailure: () async => signOuts++,
    );
    expect(
      await offline.revokeOtherSessions(),
      SessionRevocationOutcome.failed,
    );
    expect(signOuts, 0);
  });
}
