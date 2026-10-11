// BUT-1400 / BUT-920: the terms record is written with the current version
// and never stops the account being made.

import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/account/terms_acceptance.dart';
import 'package:butlery/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  late _MockUserRepository repository;

  setUp(() => repository = _MockUserRepository());

  test('records the current terms version for the account', () async {
    when(
      () => repository.recordTermsAcceptance(any(), any()),
    ).thenAnswer((_) async {});

    await recordTermsAcceptance(repository, 'uid-1');

    verify(
      () => repository.recordTermsAcceptance(
        'uid-1',
        UserService.currentTermsVersion,
      ),
    ).called(1);
  });

  test('a failed write is swallowed', () async {
    when(
      () => repository.recordTermsAcceptance(any(), any()),
    ).thenThrow(Exception('offline'));

    await expectLater(recordTermsAcceptance(repository, 'uid-1'), completes);
  });
}
