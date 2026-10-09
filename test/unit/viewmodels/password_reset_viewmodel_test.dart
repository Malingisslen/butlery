/// BUT-2170: "Välj nytt lösenord". The view model checks the link, keeps
/// sign-up's password rule, and hands over to sign-in with the address
/// (decision B1, Malin 2026-10-08).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/password_reset_viewmodel.dart';

class _MockResetService extends Mock implements PasswordResetService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockUser extends Mock implements User {}

void main() {
  late _MockResetService service;
  late _MockAuthService auth;
  late PasswordResetViewModel vm;

  setUp(() {
    PasswordResetHandoff.clear();
    service = _MockResetService();
    auth = _MockAuthService();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.forceSignOut()).thenAnswer((_) async {});
    vm = PasswordResetViewModel(resetService: service, authService: auth);
  });

  tearDown(PasswordResetHandoff.clear);

  void linkIsGood() => when(
    () => service.check('code'),
  ).thenAnswer((_) async => (email: 'anna@example.com', failure: null));

  void saveAnswers(PasswordResetFailure? failure) => when(
    () => service.confirm(
      code: any(named: 'code'),
      newPassword: any(named: 'newPassword'),
    ),
  ).thenAnswer((_) async => failure);

  User signedInAs(String? email) {
    final user = _MockUser();
    when(() => user.email).thenReturn(email);
    when(() => auth.currentUser).thenReturn(user);
    return user;
  }

  test('a good link opens the form with the account address', () async {
    linkIsGood();
    await vm.start('code');
    expect(vm.stage, PasswordResetStage.ready);
    expect(vm.email, 'anna@example.com');
  });

  test('a dead link offers a new one, not a retry', () async {
    when(() => service.check('code')).thenAnswer(
      (_) async => (email: null, failure: PasswordResetFailure.linkInvalid),
    );
    await vm.start('code');
    expect(vm.stage, PasswordResetStage.linkInvalid);
  });

  test('an offline check can be retried with the same link', () async {
    when(() => service.check('code')).thenAnswer(
      (_) async => (email: null, failure: PasswordResetFailure.network),
    );
    await vm.start('code');
    expect(vm.stage, PasswordResetStage.checkFailed);
    expect(vm.checkFailure, PasswordResetFailure.network);

    linkIsGood();
    await vm.retryCheck();
    expect(vm.stage, PasswordResetStage.ready);
  });

  group('save', () {
    setUp(() async {
      linkIsGood();
      await vm.start('code');
    });

    test(
      'refuses an empty, short or mismatched password before sending',
      () async {
        expect(await vm.save(newPassword: '', repeated: ''), isFalse);
        expect(vm.error, AppLocale.current.errorPasswordCannotBeEmpty);
        final short = 'x' * (FormValidators.minPasswordLength - 1);
        expect(await vm.save(newPassword: short, repeated: short), isFalse);
        expect(vm.error, AppLocale.current.validationPasswordMinEight);
        expect(
          await vm.save(newPassword: 'langt-nog-1', repeated: 'langt-nog-2'),
          isFalse,
        );
        expect(vm.error, AppLocale.current.accountSecurityPasswordMismatch);
        verifyNever(
          () => service.confirm(
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );

    test('a password exactly the minimum length is sent', () async {
      saveAnswers(null);
      final exact = 'x' * FormValidators.minPasswordLength;
      expect(await vm.save(newPassword: exact, repeated: exact), isTrue);
    });

    test('a saved password hands over to sign-in with the address', () async {
      saveAnswers(null);
      expect(
        await vm.save(newPassword: 'langt-nog-1', repeated: 'langt-nog-1'),
        isTrue,
      );
      expect(vm.stage, PasswordResetStage.done);
      final handoff = PasswordResetHandoff.pending;
      expect(handoff, isA<PasswordResetDone>());
      expect((handoff! as PasswordResetDone).email, 'anna@example.com');
      verifyNever(() => auth.forceSignOut());
    });

    test('the same account signed in here is signed out', () async {
      signedInAs('Anna@Example.com');
      saveAnswers(null);
      // Sign-out rebuilds sign-in, which reads the hand-over then.
      PasswordResetHandoff? atSignOut;
      when(() => auth.forceSignOut()).thenAnswer((_) async {
        atSignOut = PasswordResetHandoff.pending;
      });
      await vm.save(newPassword: 'langt-nog-1', repeated: 'langt-nog-1');
      verify(() => auth.forceSignOut()).called(1);
      expect(atSignOut, isA<PasswordResetDone>());
    });

    test('an account without an address counts as another account', () async {
      signedInAs(null);
      saveAnswers(null);
      await vm.save(newPassword: 'langt-nog-1', repeated: 'langt-nog-1');
      expect(vm.signedInElsewhere, isTrue);
      verifyNever(() => auth.forceSignOut());
      expect(PasswordResetHandoff.pending, isNull);
    });

    test('another account signed in here is left alone', () async {
      signedInAs('bertil@example.com');
      saveAnswers(null);
      await vm.save(newPassword: 'langt-nog-1', repeated: 'langt-nog-1');
      expect(vm.signedInElsewhere, isTrue);
      verifyNever(() => auth.forceSignOut());
      expect(PasswordResetHandoff.pending, isNull);
    });

    test('each failed save says its own reason and keeps the form', () async {
      final l = AppLocale.current;
      final expected = {
        PasswordResetFailure.network: l.setNewPasswordSaveFailedBecause(
          l.errorNetwork,
        ),
        PasswordResetFailure.tooManyAttempts: l.setNewPasswordSaveFailedBecause(
          l.errorTooManyAttempts,
        ),
        PasswordResetFailure.unknown: l.setNewPasswordSaveFailed,
      };
      expect(expected.values.toSet(), hasLength(3));
      for (final entry in expected.entries) {
        saveAnswers(entry.key);
        expect(
          await vm.save(newPassword: 'langt-nog-1', repeated: 'langt-nog-1'),
          isFalse,
        );
        expect(vm.stage, PasswordResetStage.ready, reason: '${entry.key}');
        expect(vm.error, entry.value, reason: '${entry.key}');
      }
      expect(PasswordResetHandoff.pending, isNull);
    });

    test('a refused password stays on the form with the reason', () async {
      saveAnswers(PasswordResetFailure.weakPassword);
      expect(
        await vm.save(newPassword: 'langt-nog-1', repeated: 'langt-nog-1'),
        isFalse,
      );
      expect(vm.stage, PasswordResetStage.ready);
      expect(vm.error, AppLocale.current.setNewPasswordWeak);
      expect(PasswordResetHandoff.pending, isNull);
    });

    test('a link that died meanwhile turns into the new-link state', () async {
      saveAnswers(PasswordResetFailure.linkInvalid);
      await vm.save(newPassword: 'langt-nog-1', repeated: 'langt-nog-1');
      expect(vm.stage, PasswordResetStage.linkInvalid);
    });
  });

  test('asking for a new link hands over to the sign-in dialog', () {
    vm.requestNewLink();
    expect(PasswordResetHandoff.pending, isA<PasswordResetRequestNewLink>());
  });
}
