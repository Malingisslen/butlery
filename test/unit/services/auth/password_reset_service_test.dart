/// BUT-2170: the reset service turns Firebase's answers into the four things
/// the view can do about them: new link, stronger password, retry, or a
/// generic failure.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth/password_reset_service.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;
  late PasswordResetService service;

  setUp(() {
    repo = _MockAuthRepository();
    service = PasswordResetService(authRepository: repo);
  });

  void confirmThrows(String code) => when(
    () => repo.confirmPasswordReset(
      code: any(named: 'code'),
      newPassword: any(named: 'newPassword'),
    ),
  ).thenThrow(FirebaseAuthException(code: code));

  test('a good link gives the account address', () async {
    when(() => repo.verifyPasswordResetCode('c')).thenAnswer(
      (_) async => 'anna@example.com',
    );
    final result = await service.check('c');
    expect(result.email, 'anna@example.com');
    expect(result.failure, isNull);
  });

  test('a used, expired or dead-account link needs a new link', () async {
    for (final code in [
      'expired-action-code',
      'invalid-action-code',
      'user-disabled',
      'user-not-found',
    ]) {
      when(
        () => repo.verifyPasswordResetCode(any()),
      ).thenThrow(FirebaseAuthException(code: code));
      final result = await service.check('c');
      expect(result.failure, PasswordResetFailure.linkInvalid, reason: code);
      expect(result.email, isNull);
    }
  });

  test('no connection while checking can be retried', () async {
    when(
      () => repo.verifyPasswordResetCode(any()),
    ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    expect((await service.check('c')).failure, PasswordResetFailure.network);
  });

  test('too many attempts is its own answer, checking or saving', () async {
    when(
      () => repo.verifyPasswordResetCode(any()),
    ).thenThrow(FirebaseAuthException(code: 'too-many-requests'));
    expect(
      (await service.check('c')).failure,
      PasswordResetFailure.tooManyAttempts,
    );
    confirmThrows('too-many-requests');
    expect(
      await service.confirm(code: 'c', newPassword: 'p'),
      PasswordResetFailure.tooManyAttempts,
    );
  });

  test('saving returns null and passes code and password through', () async {
    when(
      () => repo.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    expect(await service.confirm(code: 'c', newPassword: 'pw123456'), isNull);
    verify(
      () => repo.confirmPasswordReset(code: 'c', newPassword: 'pw123456'),
    ).called(1);
  });

  test('a refused password is told apart from a dead link', () async {
    confirmThrows('weak-password');
    expect(
      await service.confirm(code: 'c', newPassword: 'x'),
      PasswordResetFailure.weakPassword,
    );
    confirmThrows('password-does-not-meet-requirements');
    expect(
      await service.confirm(code: 'c', newPassword: 'x'),
      PasswordResetFailure.weakPassword,
    );
    confirmThrows('expired-action-code');
    expect(
      await service.confirm(code: 'c', newPassword: 'x'),
      PasswordResetFailure.linkInvalid,
    );
  });

  test('anything unexpected is unknown, not a dead link', () async {
    when(
      () => repo.confirmPasswordReset(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenThrow(StateError('boom'));
    expect(
      await service.confirm(code: 'c', newPassword: 'x'),
      PasswordResetFailure.unknown,
    );
  });
}
